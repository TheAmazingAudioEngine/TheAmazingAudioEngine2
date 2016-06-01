//
//  AEIOAudioUnit.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 4/04/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgment in the product documentation would be
//     appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//     misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import "AEIOAudioUnit.h"
#import "AETypes.h"
#import "AEUtilities.h"
#import "AEBufferStack.h"
#import "AETime.h"
#import "AEManagedValue.h"
#import "AEAudioBufferListUtilities.h"
#import <AVFoundation/AVFoundation.h>

NSString * const AEIOAudioUnitDidUpdateStreamFormatNotification = @"AEIOAudioUnitDidUpdateStreamFormatNotification";
NSString * const AEIOAudioUnitDidSetupNotification = @"AEIOAudioUnitDidSetupNotification";


@interface AEIOAudioUnit ()
@property (nonatomic, strong) AEManagedValue * renderBlockValue;
@property (nonatomic, readwrite) double currentSampleRate;
@property (nonatomic, readwrite) int numberOfOutputChannels;
@property (nonatomic, readwrite) int numberOfInputChannels;
@property (nonatomic) AudioTimeStamp inputTimestamp;
#if TARGET_OS_IPHONE
@property (nonatomic, strong) id sessionInterruptionObserverToken;
@property (nonatomic, strong) id mediaResetObserverToken;
@property (nonatomic, strong) id routeChangeObserverToken;
@property (nonatomic) NSTimeInterval outputLatency;
@property (nonatomic) NSTimeInterval inputLatency;
#endif
@end

@implementation AEIOAudioUnit
@dynamic running, renderBlock, IOBufferDuration;

- (instancetype)init {
    if ( !(self = [super init]) ) return nil;
    
#if TARGET_OS_IPHONE
    self.latencyCompensation = YES;
#endif
    
    _outputEnabled = YES;
    self.renderBlockValue = [AEManagedValue new];
    
    return self;
}

- (void)dealloc {
    [self teardown];
}

- (BOOL)running {
    if ( !_audioUnit ) return NO;
    UInt32 unitRunning;
    UInt32 size = sizeof(unitRunning);
    if ( !AECheckOSStatus(AudioUnitGetProperty(_audioUnit, kAudioOutputUnitProperty_IsRunning, kAudioUnitScope_Global, 0,
                                               &unitRunning, &size),
                          "AudioUnitGetProperty(kAudioOutputUnitProperty_IsRunning)") ) {
        return NO;
    }
    
    return unitRunning;
}

- (BOOL)setup:(NSError * _Nullable __autoreleasing *)error {
    NSAssert(!_audioUnit, @"Already setup");
    
    NSAssert(self.outputEnabled || self.inputEnabled, @"Must have output or input enabled");
    
#if !TARGET_OS_IPHONE
    NSAssert(!(self.outputEnabled && self.inputEnabled), @"Can only have both input and output enabled on iOS");
#endif
    
    // Get an instance of the output audio unit
    AudioComponentDescription acd = {};
#if TARGET_OS_IPHONE
    acd = AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_Output, kAudioUnitSubType_RemoteIO);
#else
    acd = AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_Output,
                                          self.outputEnabled ? kAudioUnitSubType_DefaultOutput : kAudioUnitSubType_HALOutput);
#endif
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &acd);
    OSStatus result = AudioComponentInstanceNew(inputComponent, &_audioUnit);
    if ( !AECheckOSStatus(result, "AudioComponentInstanceNew") ) {
        if ( error ) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:result
                                              userInfo:@{ NSLocalizedDescriptionKey: @"Unable to instantiate IO unit" }];
        return NO;
    }
    
    // Set the maximum frames per slice to render
    result = AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global,
                                  0, &AEBufferStackMaxFramesPerSlice, sizeof(AEBufferStackMaxFramesPerSlice));
    AECheckOSStatus(result, "AudioUnitSetProperty(kAudioUnitProperty_MaximumFramesPerSlice)");
    
    // Enable/disable input
    UInt32 flag = self.inputEnabled ? 1 : 0;
    result = AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flag, sizeof(flag));
    if ( !AECheckOSStatus(result, "AudioUnitSetProperty(kAudioOutputUnitProperty_EnableIO)") ) {
        if ( error ) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:result
                                              userInfo:@{ NSLocalizedDescriptionKey: @"Unable to enable/disable input" }];
        return NO;
    }
    
    // Enable/disable output
    flag = self.outputEnabled ? 1 : 0;
    result = AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &flag, sizeof(flag));
    if ( !AECheckOSStatus(result, "AudioUnitSetProperty(kAudioOutputUnitProperty_EnableIO)") ) {
        if ( error ) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:result
                                              userInfo:@{ NSLocalizedDescriptionKey: @"Unable to enable/disable output" }];
        return NO;
    }
    
    // Set the render callback
    AURenderCallbackStruct rcbs = { .inputProc = AEIOAudioUnitRenderCallback, .inputProcRefCon = (__bridge void *)(self) };
    result = AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, 0,
                                  &rcbs, sizeof(rcbs));
    if ( !AECheckOSStatus(result, "AudioUnitSetProperty(kAudioUnitProperty_SetRenderCallback)") ) {
        if ( error ) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:result
                                              userInfo:@{ NSLocalizedDescriptionKey: @"Unable to configure output render" }];
        return NO;
    }

    // Set the input callback
    AURenderCallbackStruct inRenderProc;
    inRenderProc.inputProc = &AEIOAudioUnitInputCallback;
    inRenderProc.inputProcRefCon = (__bridge void *)self;
    result = AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global,
                                  0, &inRenderProc, sizeof(inRenderProc));
    if ( !AECheckOSStatus(result, "AudioUnitSetProperty(kAudioOutputUnitProperty_SetInputCallback)") ) {
        if ( error ) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:result
                                              userInfo:@{ NSLocalizedDescriptionKey: @"Unable to configure input process" }];
        return NO;
    }
    
    // Initialize
    result = AudioUnitInitialize(_audioUnit);
    if ( !AECheckOSStatus(result, "AudioUnitInitialize")) {
        if ( error ) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:result
                                              userInfo:@{ NSLocalizedDescriptionKey: @"Unable to initialize IO unit" }];
        return NO;
    }
    
    // Update stream formats
    [self updateStreamFormat];
    
    // Register a callback to watch for stream format changes
    AECheckOSStatus(AudioUnitAddPropertyListener(_audioUnit, kAudioUnitProperty_StreamFormat, AEIOAudioUnitStreamFormatChanged,
                                                 (__bridge void*)self),
                    "AudioUnitAddPropertyListener(kAudioUnitProperty_StreamFormat)");
    
#if TARGET_OS_IPHONE
    __weak AEIOAudioUnit * weakSelf = self;
    
    // Watch for session interruptions
    __block BOOL wasRunning;
    self.sessionInterruptionObserverToken =
    [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionInterruptionNotification object:nil queue:nil
                                                  usingBlock:^(NSNotification *notification) {
        NSInteger type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] integerValue];
        if ( type == AVAudioSessionInterruptionTypeBegan ) {
            wasRunning = weakSelf.running;
            if ( wasRunning ) {
                [weakSelf stop];
            }
        } else {
            if ( wasRunning ) {
                [weakSelf start:NULL];
            }
        }
    }];
    
    // Watch for media reset notifications
    self.mediaResetObserverToken =
    [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionMediaServicesWereResetNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *notification) {
        [weakSelf reload];
    }];
    
    // Watch for audio route changes
    self.routeChangeObserverToken =
    [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionRouteChangeNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *notification)
    {
        weakSelf.outputLatency = [AVAudioSession sharedInstance].outputLatency;
        weakSelf.inputLatency = [AVAudioSession sharedInstance].inputLatency;
    }];
#endif
    
    // Notify
    [[NSNotificationCenter defaultCenter] postNotificationName:AEIOAudioUnitDidSetupNotification object:self];
    
    return YES;
}

- (void)teardown {
#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] removeObserver:self.sessionInterruptionObserverToken];
    self.sessionInterruptionObserverToken = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self.mediaResetObserverToken];
    self.mediaResetObserverToken = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self.routeChangeObserverToken];
    self.routeChangeObserverToken = nil;
#endif
    AECheckOSStatus(AudioUnitUninitialize(_audioUnit), "AudioUnitUninitialize");
    AECheckOSStatus(AudioComponentInstanceDispose(_audioUnit), "AudioComponentInstanceDispose");
    _audioUnit = NULL;
}

- (BOOL)start:(NSError *__autoreleasing *)error {
    NSAssert(_audioUnit, @"You must call setup: on this instance before starting it");
    
#if TARGET_OS_IPHONE
    // Activate audio session
    NSError * e;
    if ( ![[AVAudioSession sharedInstance] setActive:YES error:&e] ) {
        NSLog(@"Couldn't activate audio session: %@", e);
        if ( error ) *error = e;
        return NO;
    }
    
    self.outputLatency = [AVAudioSession sharedInstance].outputLatency;
    self.inputLatency = [AVAudioSession sharedInstance].inputLatency;
#endif
    
    [self updateStreamFormat];
    
    // Start unit
    OSStatus result = AudioOutputUnitStart(_audioUnit);
    if ( !AECheckOSStatus(result, "AudioOutputUnitStart") ) {
        if ( error ) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:result
                                              userInfo:@{ NSLocalizedDescriptionKey: @"Unable to start IO unit" }];
        return NO;
    }
    
    return YES;
}

- (void)stop {
    NSAssert(_audioUnit, @"You must call setup: on this instance before starting or stopping it");
    
    // Stop unit
    AECheckOSStatus(AudioOutputUnitStop(_audioUnit), "AudioOutputUnitStop");
}

AudioUnit _Nonnull AEIOAudioUnitGetAudioUnit(__unsafe_unretained AEIOAudioUnit * _Nonnull self) {
    return self->_audioUnit;
}

OSStatus AEIOAudioUnitRenderInput(__unsafe_unretained AEIOAudioUnit * _Nonnull self,
                                  const AudioBufferList * _Nonnull buffer, UInt32 frames) {
    
    if ( !self->_inputEnabled || self->_numberOfInputChannels == 0 ) {
        AEAudioBufferListSilence(buffer, 0, frames);
        return 0;
    }
    
    AudioUnitRenderActionFlags flags = 0;
    AudioTimeStamp timestamp = self->_inputTimestamp;
    AEAudioBufferListCopyOnStack(mutableAbl, buffer, 0);
    return AudioUnitRender(self->_audioUnit, &flags, &timestamp, 1, frames, mutableAbl);
}

AudioTimeStamp AEIOAudioUnitGetInputTimestamp(__unsafe_unretained AEIOAudioUnit * _Nonnull self) {
    return self->_inputTimestamp;
}

double AEIOAudioUnitGetSampleRate(__unsafe_unretained AEIOAudioUnit * _Nonnull self) {
    return self->_currentSampleRate;
}

#if TARGET_OS_IPHONE

AESeconds AEIOAudioUnitGetInputLatency(__unsafe_unretained AEIOAudioUnit * _Nonnull self) {
    return self->_inputLatency;
}

AESeconds AEIOAudioUnitGetOutputLatency(__unsafe_unretained AEIOAudioUnit * _Nonnull self) {
    return self->_outputLatency;
}

#endif

- (void)setSampleRate:(double)sampleRate {
    if ( fabs(_sampleRate - sampleRate) <= DBL_EPSILON ) return;
    
    _sampleRate = sampleRate;
    
    if ( self.running ) {
        [self updateStreamFormat];
    } else {
        self.currentSampleRate = sampleRate;
        [[NSNotificationCenter defaultCenter] postNotificationName:AEIOAudioUnitDidUpdateStreamFormatNotification object:self];
    }
}

- (double)currentSampleRate {
    if ( _audioUnit ) return _currentSampleRate;
    
    if ( self.sampleRate != 0 ) return self.sampleRate;
    
    // If not setup yet, take the sample rate from the audio session
#if TARGET_OS_IPHONE
    return [[AVAudioSession sharedInstance] sampleRate];
#else
    return [self streamFormatForDefaultDeviceScope:
            self.outputEnabled ? kAudioDevicePropertyScopeOutput : kAudioDevicePropertyScopeInput].mSampleRate;
#endif
}

- (void)setOutputEnabled:(BOOL)outputEnabled {
    if ( _outputEnabled == outputEnabled ) return;
    _outputEnabled = outputEnabled;
    if ( self.renderBlock && _audioUnit ) {
        BOOL wasRunning = self.running;
        AECheckOSStatus(AudioUnitUninitialize(_audioUnit), "AudioUnitUninitialize");
        UInt32 flag = _outputEnabled ? 1 : 0;
        OSStatus result =
            AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &flag, sizeof(flag));
        if ( AECheckOSStatus(result, "AudioUnitSetProperty(kAudioOutputUnitProperty_EnableIO)") ) {
            [self updateStreamFormat];
            if ( AECheckOSStatus(AudioUnitInitialize(_audioUnit), "AudioUnitInitialize") && wasRunning ) {
                [self start:NULL];
            }
        }
    }
}

- (int)numberOfOutputChannels {
    if ( _audioUnit && _numberOfOutputChannels ) return _numberOfOutputChannels;
    
    // If not setup, take the channel count from the session
#if TARGET_OS_IPHONE
    return (int)[[AVAudioSession sharedInstance] outputNumberOfChannels];
#else
    return [self streamFormatForDefaultDeviceScope:kAudioDevicePropertyScopeOutput].mChannelsPerFrame;
#endif
}

- (AEIOAudioUnitRenderBlock)renderBlock {
    return self.renderBlockValue.objectValue;
}

- (void)setRenderBlock:(AEIOAudioUnitRenderBlock)renderBlock {
    self.renderBlockValue.objectValue = [renderBlock copy];
}

- (void)setInputEnabled:(BOOL)inputEnabled {
    if ( _inputEnabled == inputEnabled ) return;
    _inputEnabled = inputEnabled;
    if ( _audioUnit ) {
        BOOL wasRunning = self.running;
        AECheckOSStatus(AudioUnitUninitialize(_audioUnit), "AudioUnitUninitialize");
        UInt32 flag = _inputEnabled ? 1 : 0;
        OSStatus result =
            AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flag, sizeof(flag));
        if ( AECheckOSStatus(result, "AudioUnitSetProperty(kAudioOutputUnitProperty_EnableIO)") ) {
            [self updateStreamFormat];
            if ( AECheckOSStatus(AudioUnitInitialize(_audioUnit), "AudioUnitInitialize") && wasRunning ) {
                [self start:NULL];
            }
        }
    }
}

- (int)numberOfInputChannels {
    if ( _audioUnit && _numberOfInputChannels ) return _numberOfInputChannels;
    
    // If not setup, take the channel count from the session
#if TARGET_OS_IPHONE
    return (int)[[AVAudioSession sharedInstance] inputNumberOfChannels];
#else
    return [self streamFormatForDefaultDeviceScope:kAudioDevicePropertyScopeInput].mChannelsPerFrame;
#endif
}

- (void)setMaximumInputChannels:(int)maximumInputChannels {
    if ( _maximumInputChannels == maximumInputChannels ) return;
    _maximumInputChannels = maximumInputChannels;
    if ( _audioUnit && _inputEnabled && _numberOfInputChannels > _maximumInputChannels ) {
        [self updateStreamFormat];
    }
}

- (AESeconds)IOBufferDuration {
#if TARGET_OS_IPHONE
    return [[AVAudioSession sharedInstance] IOBufferDuration];
#else
    // Get the default device
    AudioDeviceID deviceId =
        [self defaultDeviceForScope:self.outputEnabled ? kAudioDevicePropertyScopeOutput : kAudioDevicePropertyScopeInput];
    if ( deviceId == kAudioDeviceUnknown ) return 0.0;
    
    // Get the buffer duration
    UInt32 duration;
    UInt32 size = sizeof(duration);
    AudioObjectPropertyAddress addr = {
        kAudioDevicePropertyBufferFrameSize,
        self.outputEnabled ? kAudioDevicePropertyScopeOutput : kAudioDevicePropertyScopeInput, 0 };
    if ( !AECheckOSStatus(AudioObjectGetPropertyData(deviceId, &addr, 0, NULL, &size, &duration),
                          "AudioObjectSetPropertyData") ) return 0.0;
    
    return (double)duration / self.currentSampleRate;
#endif
}

- (void)setIOBufferDuration:(AESeconds)IOBufferDuration {
#if TARGET_OS_IPHONE
    NSError * error = nil;
    if ( ![[AVAudioSession sharedInstance] setPreferredIOBufferDuration:IOBufferDuration error:&error] ) {
        NSLog(@"Unable to set IO Buffer duration: %@", error.localizedDescription);
    }
#else
    // Get the default device
    AudioDeviceID deviceId =
    [self defaultDeviceForScope:self.outputEnabled ? kAudioDevicePropertyScopeOutput : kAudioDevicePropertyScopeInput];
    if ( deviceId == kAudioDeviceUnknown ) return;
    
    // Set the buffer duration
    UInt32 duration = (double)IOBufferDuration * self.currentSampleRate;
    UInt32 size = sizeof(duration);
    AudioObjectPropertyAddress addr = {
        kAudioDevicePropertyBufferFrameSize,
        self.outputEnabled ? kAudioDevicePropertyScopeOutput : kAudioDevicePropertyScopeInput, 0 };
    AECheckOSStatus(AudioObjectSetPropertyData(deviceId, &addr, 0, NULL, size, &duration),
                    "AudioObjectSetPropertyData");
#endif
}

#pragma mark -

static OSStatus AEIOAudioUnitRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                                            const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber,
                                            UInt32 inNumberFrames, AudioBufferList *ioData) {
    // Render
    __unsafe_unretained AEIOAudioUnit * THIS = (__bridge AEIOAudioUnit *)inRefCon;
    
    AudioTimeStamp timestamp = *inTimeStamp;
    
#if TARGET_OS_IPHONE
    if ( THIS->_latencyCompensation ) {
        timestamp.mHostTime += AEHostTicksFromSeconds(THIS->_outputLatency);
    }
#endif
    
    __unsafe_unretained AEIOAudioUnitRenderBlock renderBlock
        = (__bridge AEIOAudioUnitRenderBlock)AEManagedValueGetValue(THIS->_renderBlockValue);
    if ( renderBlock ) {
        renderBlock(ioData, inNumberFrames, &timestamp);
    }
    
    return noErr;
}

static OSStatus AEIOAudioUnitInputCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                                           const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber,
                                           UInt32 inNumberFrames, AudioBufferList *ioData) {
    // Grab timestamp
    __unsafe_unretained AEIOAudioUnit * THIS = (__bridge AEIOAudioUnit *)inRefCon;
    
    AudioTimeStamp timestamp = *inTimeStamp;
    
#if TARGET_OS_IPHONE
    if ( THIS->_latencyCompensation ) {
        timestamp.mHostTime -= AEHostTicksFromSeconds(THIS->_inputLatency);
    }
#endif
    
    THIS->_inputTimestamp = timestamp;
    return noErr;
}

static void AEIOAudioUnitStreamFormatChanged(void *inRefCon, AudioUnit inUnit, AudioUnitPropertyID inID,
                                             AudioUnitScope inScope, AudioUnitElement inElement) {
    AEIOAudioUnit * self = (__bridge AEIOAudioUnit *)inRefCon;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( self.running ) {
            [self updateStreamFormat];
        }
    });
}

- (void)updateStreamFormat {
    BOOL stoppedUnit = NO;
    BOOL hasChanges = NO;
    
    if ( self.outputEnabled ) {
        // Get the current output sample rate and number of output channels
        AudioStreamBasicDescription asbd;
        UInt32 size = sizeof(asbd);
        AECheckOSStatus(AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0,
                                             &asbd, &size),
                        "AudioUnitGetProperty(kAudioUnitProperty_StreamFormat)");
        
        double priorSampleRate = self.currentSampleRate;
        self.currentSampleRate = self.sampleRate == 0 ? asbd.mSampleRate : self.sampleRate;
        
        BOOL rateChanged = fabs(priorSampleRate - _currentSampleRate) > DBL_EPSILON;
        BOOL running = self.running;
        if ( rateChanged && running ) {
            AECheckOSStatus(AudioOutputUnitStop(_audioUnit), "AudioOutputUnitStop");
            stoppedUnit = YES;
            hasChanges = YES;
        }
        
        if ( self.numberOfOutputChannels != (int)asbd.mChannelsPerFrame ) {
            hasChanges = YES;
            self.numberOfOutputChannels = asbd.mChannelsPerFrame;
        } else {
            _numberOfOutputChannels = (int)asbd.mChannelsPerFrame; // (Report change quietly)
        }
        
        // Update the stream format
        asbd = AEAudioDescription;
        asbd.mChannelsPerFrame = self.numberOfOutputChannels;
        asbd.mSampleRate = self.currentSampleRate;
        AECheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
                                             &asbd, sizeof(asbd)),
                        "AudioUnitSetProperty(kAudioUnitProperty_StreamFormat)");
    }
    
    if ( self.inputEnabled ) {
        // Get the current input number of input channels
        AudioStreamBasicDescription asbd;
        UInt32 size = sizeof(asbd);
        AECheckOSStatus(AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,
                                             1, &asbd, &size),
                        "AudioUnitGetProperty(kAudioUnitProperty_StreamFormat)");
        
        int channels = MIN(asbd.mChannelsPerFrame, self.maximumInputChannels);
        if ( self.numberOfInputChannels != (int)channels ) {
            hasChanges = YES;
            self.numberOfInputChannels = channels;
        } else {
            _numberOfInputChannels = channels; // (Report change quietly)
        }
        
        if ( !self.outputEnabled ) {
            self.currentSampleRate = self.sampleRate == 0 ? asbd.mSampleRate : self.sampleRate;
        }
        
        if ( self.numberOfInputChannels > 0 ) {
            // Set the stream format
            asbd = AEAudioDescription;
            asbd.mChannelsPerFrame = self.numberOfInputChannels;
            asbd.mSampleRate = self.currentSampleRate;
            AECheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1,
                                                 &asbd, sizeof(asbd)),
                            "AudioUnitSetProperty(kAudioUnitProperty_StreamFormat)");
        } else {
            memset(&_inputTimestamp, 0, sizeof(_inputTimestamp));
        }
    }
    
    if ( hasChanges ) {
        [[NSNotificationCenter defaultCenter] postNotificationName:AEIOAudioUnitDidUpdateStreamFormatNotification object:self];
    }
    
    if ( stoppedUnit ) {
        AECheckOSStatus(AudioOutputUnitStart(_audioUnit), "AudioOutputUnitStart");
    }
}

- (void)reload {
    BOOL wasRunning = self.running;
    [self teardown];
    if ( ![self setup:NULL] ) return;
    if ( wasRunning ) {
        [self start:NULL];
    }
}

#if !TARGET_OS_IPHONE
- (AudioDeviceID)defaultDeviceForScope:(AudioObjectPropertyScope)scope {
    AudioDeviceID deviceId;
    UInt32 size = sizeof(deviceId);
    AudioObjectPropertyAddress addr = {
        scope == kAudioDevicePropertyScopeInput ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice,
        .mScope = kAudioObjectPropertyScopeGlobal,
        .mElement = 0
    };
    if ( !AECheckOSStatus(AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, &deviceId),
                          "AudioObjectGetPropertyData") ) {
        return kAudioDeviceUnknown;
    }
    
    return deviceId;
}

- (AudioStreamBasicDescription)streamFormatForDefaultDeviceScope:(AudioObjectPropertyScope)scope {
    // Get the default device
    AudioDeviceID deviceId = [self defaultDeviceForScope:scope];
    if ( deviceId == kAudioDeviceUnknown ) return (AudioStreamBasicDescription){};
    
    // Get stream format
    AudioStreamBasicDescription asbd;
    UInt32 size = sizeof(asbd);
    AudioObjectPropertyAddress addr = { kAudioDevicePropertyStreamFormat, scope, 0 };
    if ( !AECheckOSStatus(AudioObjectGetPropertyData(deviceId, &addr, 0, NULL, &size, &deviceId),
                          "AudioObjectGetPropertyData") ) {
        return (AudioStreamBasicDescription){};
    }
    
    return asbd;
}
#endif

@end
