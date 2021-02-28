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
#import "AEDSPUtilities.h"
#import <AVFoundation/AVFoundation.h>

NSString * const AEIOAudioUnitDidUpdateStreamFormatNotification = @"AEIOAudioUnitDidUpdateStreamFormatNotification";
NSString * const AEIOAudioUnitDidSetupNotification = @"AEIOAudioUnitDidSetupNotification";
NSString * const AEIOAudioUnitSessionInterruptionBeganNotification = @"AEIOAudioUnitSessionInterruptionBeganNotification";
NSString * const AEIOAudioUnitSessionInterruptionEndedNotification = @"AEIOAudioUnitSessionInterruptionEndedNotification";

static const double kAVAudioSession0dBGain = 0.75;

@interface AEIOAudioUnit ()
@property (nonatomic, strong) AEManagedValue * renderBlockValue;
@property (nonatomic, readwrite) double currentSampleRate;
@property (nonatomic, readwrite) BOOL running;
@property (nonatomic) BOOL hasSetInitialStreamFormat;
@property (nonatomic, readwrite) int numberOfOutputChannels;
@property (nonatomic, readwrite) int numberOfInputChannels;
@property (nonatomic) AudioTimeStamp inputTimestamp;
@property (nonatomic) BOOL needsInputGainScaling;
@property (nonatomic) float currentInputGain;
#if TARGET_OS_IPHONE
@property (nonatomic, strong) id sessionInterruptionObserverToken;
@property (nonatomic, strong) id mediaResetObserverToken;
@property (nonatomic, strong) id routeChangeObserverToken;
@property (nonatomic) NSTimeInterval outputLatency;
@property (nonatomic) NSTimeInterval inputLatency;
#endif
@end

@implementation AEIOAudioUnit
@dynamic renderBlock, IOBufferDuration;

- (instancetype)init {
    if ( !(self = [super init]) ) return nil;
    
#if TARGET_OS_IPHONE
    self.latencyCompensation = YES;
#endif
    
    _outputEnabled = YES;
    self.renderBlockValue = [AEManagedValue new];
    
    _currentInputGain = _inputGain = 1.0;
    
    AETimeInit();
    
    return self;
}

- (void)dealloc {
    [self teardown];
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
    acd = AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_Output, kAudioUnitSubType_HALOutput);
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
    __weak typeof(self) weakSelf = self;
    
    // Watch for session interruptions
    __block BOOL wasRunning;
    self.sessionInterruptionObserverToken =
    [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionInterruptionNotification object:nil queue:nil
                                                  usingBlock:^(NSNotification *notification) {
        NSInteger type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] integerValue];
        if ( type == AVAudioSessionInterruptionTypeBegan ) {
            wasRunning = weakSelf.running;
            
            UInt32 interAppAudioConnected;
            UInt32 size = sizeof(interAppAudioConnected);
            AECheckOSStatus(AudioUnitGetProperty(weakSelf.audioUnit, kAudioUnitProperty_IsInterAppConnected, kAudioUnitScope_Global, 0, &interAppAudioConnected, &size), "AudioUnitGetProperty");
            if ( interAppAudioConnected ) {
                // Restart immediately, this is a spurious interruption
                if ( !wasRunning ) {
                    [weakSelf start:NULL];
                }
            } else {
                if ( wasRunning ) {
                    [weakSelf stop];
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:AEIOAudioUnitSessionInterruptionBeganNotification object:weakSelf];
            }
        } else {
            NSUInteger optionFlags =
                [notification.userInfo[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
            if (optionFlags & AVAudioSessionInterruptionOptionShouldResume) {
                if ( wasRunning ) {
                    [weakSelf start:NULL];
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:AEIOAudioUnitSessionInterruptionEndedNotification object:weakSelf];
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
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.outputLatency = AVAudioSession.sharedInstance.outputLatency;
            weakSelf.inputLatency = AVAudioSession.sharedInstance.inputLatency;
            weakSelf.inputGain = weakSelf.inputGain;
        });
    }];
    
    // Register callback to watch for Inter-App Audio connections
    AECheckOSStatus(AudioUnitAddPropertyListener(_audioUnit, kAudioUnitProperty_IsInterAppConnected,
                                                 AEIOAudioUnitIAAConnectionChanged, (__bridge void*)self),
                    "AudioUnitAddPropertyListener(kAudioUnitProperty_IsInterAppConnected)");
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
    if ( ![AVAudioSession.sharedInstance setActive:YES error:&e] ) {
        NSLog(@"Couldn't activate audio session: %@", e);
        if ( error ) *error = e;
        return NO;
    }
    
    self.outputLatency = AVAudioSession.sharedInstance.outputLatency;
    self.inputLatency = AVAudioSession.sharedInstance.inputLatency;
    self.inputGain = self.inputGain;
#endif
    
    [self updateStreamFormat];
    
    // Start unit
    OSStatus result = AudioOutputUnitStart(_audioUnit);
    
    if ( !AECheckOSStatus(result, "AudioOutputUnitStart") ) {
        if ( error ) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:result
                                              userInfo:@{ NSLocalizedDescriptionKey: @"Unable to start IO unit" }];
        return NO;
    }
    
    self.running = YES;
    
    return YES;
}

- (void)stop {
    NSAssert(_audioUnit, @"You must call setup: on this instance before starting or stopping it");
    
    self.running = NO;
    
    // Stop unit
    AECheckOSStatus(AudioOutputUnitStop(_audioUnit), "AudioOutputUnitStop");
}

AudioUnit _Nonnull AEIOAudioUnitGetAudioUnit(__unsafe_unretained AEIOAudioUnit * _Nonnull THIS) {
    return THIS->_audioUnit;
}

OSStatus AEIOAudioUnitRenderInput(__unsafe_unretained AEIOAudioUnit * _Nonnull THIS,
                                  const AudioBufferList * _Nonnull buffer, UInt32 frames) {
    
    if ( !THIS->_inputEnabled || THIS->_numberOfInputChannels == 0 ) {
        AEAudioBufferListSilence(buffer, 0, frames);
        return 0;
    }
    
    AudioUnitRenderActionFlags flags = 0;
    AudioTimeStamp timestamp = THIS->_inputTimestamp;
    AEAudioBufferListCopyOnStack(mutableAbl, buffer, 0);
    OSStatus status = AudioUnitRender(THIS->_audioUnit, &flags, &timestamp, 1, frames, mutableAbl);
    AECheckOSStatus(status, "AudioUnitRender");
    if ( status == noErr && THIS->_needsInputGainScaling &&
            (fabs(THIS->_inputGain - 1.0) > 1.0e-5 || fabs(THIS->_inputGain - THIS->_currentInputGain) > 1.0e-5) ) {
        AEDSPApplyGainSmoothed(mutableAbl, THIS->_inputGain, &THIS->_currentInputGain, frames);
    }
    return status;
}

BOOL AEIOAudioUnitGetInputEnabled(__unsafe_unretained AEIOAudioUnit * _Nonnull THIS) {
    return THIS->_inputEnabled && THIS->_numberOfInputChannels > 0;
}

AudioTimeStamp AEIOAudioUnitGetInputTimestamp(__unsafe_unretained AEIOAudioUnit * _Nonnull THIS) {
    return THIS->_inputTimestamp;
}

double AEIOAudioUnitGetSampleRate(__unsafe_unretained AEIOAudioUnit * _Nonnull THIS) {
    return THIS->_currentSampleRate;
}

#if TARGET_OS_IPHONE

AESeconds AEIOAudioUnitGetInputLatency(__unsafe_unretained AEIOAudioUnit * _Nonnull THIS) {
    return THIS->_inputLatency;
}

AESeconds AEIOAudioUnitGetOutputLatency(__unsafe_unretained AEIOAudioUnit * _Nonnull THIS) {
    return THIS->_outputLatency;
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
    return [AVAudioSession.sharedInstance sampleRate];
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
    return (int)[AVAudioSession.sharedInstance outputNumberOfChannels];
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

- (void)setInputGain:(double)inputGain {
    _inputGain = inputGain;
    
#if TARGET_OS_IPHONE
    AVAudioSession * audioSession = AVAudioSession.sharedInstance;
    
    // Try to set the hardware gain; zero seems to still be audible, though, so we'll bypass for that
    if ( audioSession.inputGainSettable && inputGain > 0 ) {
        // AVAudioSession's gain seems to be logarithmic, so we'll do a little rough scaling on the input values (power ratio).
        // The default gain is not 1.0, so we'll consider the default value kAVAudioSession0dBGain as the 0dB point
        double gain = (inputGain > 1.0-1.0e-5 ? 1.0 : 1.0 - (AEDSPRatioToDecibels(inputGain) / -30.0)) * kAVAudioSession0dBGain;
        NSError * error = nil;
        if ( ![audioSession setInputGain:MIN(1.0, gain) error:&error] ) {
            NSLog(@"Couldn't set input gain: %@", error);
            _needsInputGainScaling = YES;
        } else {
            _needsInputGainScaling = NO;
        }
    } else {
        _needsInputGainScaling = YES;
    }
#else
    _needsInputGainScaling = YES;
#endif
}

- (int)numberOfInputChannels {
    if ( _audioUnit && _numberOfInputChannels ) return _numberOfInputChannels;
    
    // If not setup, take the channel count from the session
#if TARGET_OS_IPHONE
    return (int)[AVAudioSession.sharedInstance inputNumberOfChannels];
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
    return [AVAudioSession.sharedInstance IOBufferDuration];
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
    if ( ![AVAudioSession.sharedInstance setPreferredIOBufferDuration:IOBufferDuration error:&error] ) {
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
    } else {
        *ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
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

#if TARGET_OS_IPHONE
static void AEIOAudioUnitIAAConnectionChanged(void *inRefCon, AudioUnit inUnit, AudioUnitPropertyID inID,
                                              AudioUnitScope inScope, AudioUnitElement inElement) {
    AEIOAudioUnit * self = (__bridge AEIOAudioUnit *)inRefCon;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateStreamFormat];
        
        UInt32 iaaConnected = NO;
        UInt32 size = sizeof(iaaConnected);
        if ( AECheckOSStatus(AudioUnitGetProperty(self.audioUnit, kAudioUnitProperty_IsInterAppConnected,
                                                  kAudioUnitScope_Global, 0, &iaaConnected, &size),
                             "AudioUnitGetProperty(kAudioUnitProperty_IsInterAppConnected)") && iaaConnected && !self.running ) {
            // Start, if connected to IAA and not running
            [self start:NULL];
        }
    });
}
#endif

- (void)updateStreamFormat {
    BOOL running = self.running;
    BOOL stoppedUnit = NO;
    BOOL hasChanges = NO;
    BOOL iaaInput = NO;
    BOOL iaaOutput = NO;
    
#if TARGET_OS_IPHONE
    UInt32 iaaConnected = NO;
    UInt32 size = sizeof(iaaConnected);
    if ( AECheckOSStatus(AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_IsInterAppConnected,
                                              kAudioUnitScope_Global, 0, &iaaConnected, &size),
                         "AudioUnitGetProperty(kAudioUnitProperty_IsInterAppConnected)") && iaaConnected ) {
        AudioComponentDescription componentDescription;
        size = sizeof(componentDescription);
        if ( AECheckOSStatus(AudioUnitGetProperty(_audioUnit, kAudioOutputUnitProperty_NodeComponentDescription,
                                                  kAudioUnitScope_Global, 0, &componentDescription, &size),
                             "AudioUnitGetProperty(kAudioOutputUnitProperty_NodeComponentDescription)") ) {
            iaaOutput = YES;
            iaaInput = componentDescription.componentType == kAudioUnitType_RemoteEffect
                || componentDescription.componentType == kAudioUnitType_RemoteMusicEffect;
        }
    }
#endif
    
    if ( self.outputEnabled ) {
        // Get the current output sample rate and number of output channels
        AudioStreamBasicDescription asbd;
        UInt32 size = sizeof(asbd);
        AECheckOSStatus(AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0,
                                             &asbd, &size),
                        "AudioUnitGetProperty(kAudioUnitProperty_StreamFormat)");
        
        if ( iaaOutput ) {
            asbd.mChannelsPerFrame = 2;
        }
        
        BOOL hasOutputChanges = NO;
        
        double newSampleRate = self.sampleRate == 0 ? asbd.mSampleRate : self.sampleRate;
        if ( fabs(_currentSampleRate - newSampleRate) > DBL_EPSILON ) {
            hasChanges = hasOutputChanges = YES;
            self.currentSampleRate = newSampleRate;
        }
        
        if ( _numberOfOutputChannels != (int)asbd.mChannelsPerFrame ) {
            hasChanges = hasOutputChanges = YES;
            self.numberOfOutputChannels = asbd.mChannelsPerFrame;
        }
        
        if ( hasOutputChanges || !self.hasSetInitialStreamFormat ) {
            if ( running ) {
                AECheckOSStatus(AudioOutputUnitStop(_audioUnit), "AudioOutputUnitStop");
                stoppedUnit = YES;
            }

            // Update the stream format
            asbd = AEAudioDescription;
            asbd.mChannelsPerFrame = self.numberOfOutputChannels;
            asbd.mSampleRate = self.currentSampleRate;
            AECheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
                                                 &asbd, sizeof(asbd)),
                            "AudioUnitSetProperty(kAudioUnitProperty_StreamFormat)");
        }
    }
    
    if ( self.inputEnabled ) {
        // Get the current input number of input channels
        AudioStreamBasicDescription asbd;
        UInt32 size = sizeof(asbd);
        AECheckOSStatus(AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,
                                             1, &asbd, &size),
                        "AudioUnitGetProperty(kAudioUnitProperty_StreamFormat)");
        
        if ( iaaInput ) {
            asbd.mChannelsPerFrame = 2;
        }
        
        BOOL hasInputChanges = NO;
        
        int channels = self.maximumInputChannels ? MIN(asbd.mChannelsPerFrame, self.maximumInputChannels) : asbd.mChannelsPerFrame;
        if ( _numberOfInputChannels != (int)channels ) {
            hasChanges = hasInputChanges = YES;
            self.numberOfInputChannels = channels;
        }
        
        if ( !self.outputEnabled ) {
            double newSampleRate = self.sampleRate == 0 ? asbd.mSampleRate : self.sampleRate;
            if ( fabs(_currentSampleRate - newSampleRate) > DBL_EPSILON ) {
                hasChanges = hasInputChanges = YES;
                self.currentSampleRate = newSampleRate;
            }
        }
        
        if ( self.numberOfInputChannels > 0 && (hasInputChanges || self.hasSetInitialStreamFormat) ) {
            if ( running && !stoppedUnit ) {
                AECheckOSStatus(AudioOutputUnitStop(_audioUnit), "AudioOutputUnitStop");
                stoppedUnit = YES;
            }
            
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
    
    self.hasSetInitialStreamFormat = YES;
    
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
    if ( !AECheckOSStatus(AudioObjectGetPropertyData(deviceId, &addr, 0, NULL, &size, &asbd),
                          "AudioObjectGetPropertyData") ) {
        return (AudioStreamBasicDescription){};
    }
    
    return asbd;
}
#endif

@end
