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
#import "AEAudioBufferListUtilities.h"
@import AVFoundation;
#import <mach/mach_time.h>

NSString * const AEIOAudioUnitDidUpdateStreamFormatNotification = @"AEIOAudioUnitDidUpdateStreamFormatNotification";

@interface AEIOAudioUnit ()
@property (nonatomic, readwrite) double currentSampleRate;
@property (nonatomic, readwrite) int outputChannels;
@property (nonatomic, readwrite) int inputChannels;
@property (nonatomic) AudioTimeStamp inputTimestamp;
#if TARGET_OS_IPHONE
@property (nonatomic, strong) id sessionInterruptionObserverToken;
@property (nonatomic, strong) id mediaResetObserverToken;
@property (nonatomic, strong) id routeChangeObserverToken;
@property (nonatomic) NSTimeInterval outputLatency;
@property (nonatomic) NSTimeInterval inputLatency;
#endif
@end


////////////////////////////////////////////////////////////////////////////////
// sets nr of seconds between reports, 0 = no reporting
#define AE_REPORT_TIME 2

#if AE_REPORT_TIME

static OSStatus notifyCallback(
	void *							inRefCon,
	AudioUnitRenderActionFlags *	ioActionFlags,
	const AudioTimeStamp *			inTimeStamp,
	UInt32							inBusNumber,
	UInt32							inNumberFrames,
	AudioBufferList * __nullable	ioData)
{
	static UInt64 startTime = 0;
	static UInt64 finishTime = 0;
	
	if (*ioActionFlags & kAudioUnitRenderAction_PreRender)
	{
		startTime = mach_absolute_time();
	}
	else
	if (*ioActionFlags & kAudioUnitRenderAction_PostRender)
	{
		finishTime = mach_absolute_time();
		
		double renderTime = AESecondsFromHostTicks(finishTime - startTime);
		
		// Compute short term average time
		static double avgTime = 0;
		avgTime += 0.1 * (renderTime - avgTime);
		
		// Compute maximum time since last report
		static double maxTime = 0;
		if (maxTime < renderTime)
		{ maxTime = renderTime; }
		
		// Check report frequency
		static double lastTime = 0;
		double time = AECurrentTimeInSeconds();
		if (lastTime + AE_REPORT_TIME <= time)
		{
			lastTime = time;
			double reportTime1 = avgTime;
			double reportTime2 = maxTime;
			dispatch_async(dispatch_get_main_queue(), \
			^{
				NSLog(@"Render time avg = %lfs)", reportTime1);
				NSLog(@"Render time max = %lfs)", reportTime2);
			});
			
			maxTime = 0;
		}
	}
	
	return noErr;
}

#endif // AE_REPORT_TIME
////////////////////////////////////////////////////////////////////////////////


@implementation AEIOAudioUnit
@dynamic running;

- (instancetype)initWithInput:(BOOL)inputEnabled output:(BOOL)outputEnabled {
    if ( !(self = [super init]) ) return nil;
    
#if TARGET_OS_IPHONE
    self.latencyCompensation = YES;
#endif
    
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
    
    if ( self.outputEnabled ) {
        // Set the render callback
        AURenderCallbackStruct rcbs = { .inputProc = AEIOAudioUnitRenderCallback, .inputProcRefCon = (__bridge void *)(self) };
        result = AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, 0,
                                      &rcbs, sizeof(rcbs));
        if ( !AECheckOSStatus(result, "AudioUnitSetProperty(kAudioUnitProperty_SetRenderCallback)") ) {
            if ( error ) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:result
                                                  userInfo:@{ NSLocalizedDescriptionKey: @"Unable to configure output render" }];
            return NO;
        }
    }
    
    if ( self.inputEnabled ) {
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
    }


#if AE_REPORT_TIME
	AudioUnitAddRenderNotify(_audioUnit, notifyCallback, nil);
#endif

	
    // Initialize
    result = AudioUnitInitialize(_audioUnit);
    if ( !AECheckOSStatus(result, "AudioUnitInitialize")) {
        if ( error ) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:result
                                              userInfo:@{ NSLocalizedDescriptionKey: @"Unable to initialize IO unit" }];
        return NO;
    }
    
    if ( self.outputEnabled ) {
        // Get the current sample rate and number of output channels
        AudioStreamBasicDescription asbd;
        UInt32 size = sizeof(asbd);
        AECheckOSStatus(AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0,
                                             &asbd, &size),
                        "AudioUnitGetProperty(kAudioUnitProperty_StreamFormat)");
        self.currentSampleRate = self.sampleRate == 0 ? asbd.mSampleRate : self.sampleRate;
        self.outputChannels = asbd.mChannelsPerFrame;
        
        // Set the stream format
        asbd = AEAudioDescription;
        asbd.mSampleRate = self.currentSampleRate;
        asbd.mChannelsPerFrame = self.outputChannels;
        AECheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
                                             &asbd, sizeof(asbd)),
                        "AudioUnitSetProperty(kAudioUnitProperty_StreamFormat)");
    }
    
    if ( self.inputEnabled ) {
        // Get the current number of input channels and sample rate
        AudioStreamBasicDescription asbd;
        UInt32 size = sizeof(asbd);
        AECheckOSStatus(AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1,
                                             &asbd, &size),
                        "AudioUnitGetProperty(kAudioUnitProperty_StreamFormat)");
        self.inputChannels = MIN(asbd.mChannelsPerFrame, self.maxInputChannels);
        
        if ( !self.outputEnabled ) {
            self.currentSampleRate = self.sampleRate;
        }
        
        if ( self.inputChannels > 0 ) {
            // Set the stream format
            asbd = AEAudioDescription;
            asbd.mSampleRate = self.currentSampleRate;
            asbd.mChannelsPerFrame = self.inputChannels;
            AECheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1,
                                                 &asbd, sizeof(asbd)),
                            "AudioUnitSetProperty(kAudioUnitProperty_StreamFormat)");
        } else {
            memset(&_inputTimestamp, 0, sizeof(_inputTimestamp));
        }
    }
    
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
    // Stop unit
    AECheckOSStatus(AudioOutputUnitStop(_audioUnit), "AudioOutputUnitStop");
}

AudioUnit _Nonnull AEIOAudioUnitGetAudioUnit(__unsafe_unretained AEIOAudioUnit * _Nonnull self) {
    return self->_audioUnit;
}

OSStatus AEIOAudioUnitRenderInput(__unsafe_unretained AEIOAudioUnit * _Nonnull self,
                                  const AudioBufferList * _Nonnull buffer, UInt32 frames) {
    assert(self->_inputEnabled);
    
    if ( self->_inputChannels == 0 ) {
        AEAudioBufferListSilence(buffer, AEAudioDescription, 0, frames);
        return kAudio_ParamError;
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

- (void)setOutputEnabled:(BOOL)outputEnabled {
    if ( _outputEnabled == outputEnabled ) return;
    _outputEnabled = outputEnabled;
    if ( _renderBlock && _audioUnit ) {
        [self reload];
    }
}

- (void)setRenderBlock:(AEIOAudioUnitRenderBlock)renderBlock {
    BOOL wasSetup = _audioUnit != NULL;
    BOOL wasRunning = wasSetup && self.running;
    if ( _audioUnit && _outputEnabled ) [self teardown];
    
    _renderBlock = renderBlock;
    
    if ( wasSetup && _outputEnabled ) {
        [self setup:NULL];
        if ( wasRunning ) {
            [self start:NULL];
        }
    }
}

- (void)setInputEnabled:(BOOL)inputEnabled {
    if ( _inputEnabled == inputEnabled ) return;
    _inputEnabled = inputEnabled;
    if ( _audioUnit ) {
        [self reload];
    }
}

- (void)setMaxInputChannels:(int)maxInputChannels {
    if ( _maxInputChannels == maxInputChannels ) return;
    _maxInputChannels = maxInputChannels;
    if ( _audioUnit && _inputEnabled && _inputChannels > _maxInputChannels ) {
        [self updateStreamFormat];
    }
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
    
    THIS->_renderBlock(ioData, inNumberFrames, &timestamp);
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
        
        if ( self.outputChannels != (int)asbd.mChannelsPerFrame ) {
            hasChanges = YES;
            self.outputChannels = asbd.mChannelsPerFrame;
        }
        
        // Update the stream format
        asbd = AEAudioDescription;
        asbd.mChannelsPerFrame = self.outputChannels;
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
        
        int channels = MIN(asbd.mChannelsPerFrame, self.maxInputChannels);
        if ( self.inputChannels != (int)channels ) {
            hasChanges = YES;
            self.inputChannels = channels;
        }
        
        if ( !self.outputEnabled ) {
            self.currentSampleRate = self.sampleRate;
        }
        
        if ( self.inputChannels > 0 ) {
            // Set the stream format
            asbd = AEAudioDescription;
            asbd.mChannelsPerFrame = self.inputChannels;
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

@end
