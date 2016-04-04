//
//  AEAudioUnitOutput.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 23/03/2016.
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

#import "AEAudioUnitOutput.h"
#import "AERenderer.h"
#import "AETypes.h"
#import "AEUtilities.h"
#import "AEBufferStack.h"
#import "AETime.h"
@import AVFoundation;

NSString * const AEAudioUnitOutputError = @"AEAudioUnitOutputError";

@interface AEAudioUnitOutput ()
@property (nonatomic, strong, readwrite) AERenderer * renderer;
@property (nonatomic, readwrite) double currentSampleRate;
@property (nonatomic, readwrite) int outputChannels;
#if TARGET_OS_IPHONE
@property (nonatomic, strong) id sessionInterruptionObserverToken;
@property (nonatomic, strong) id mediaResetObserverToken;
@property (nonatomic, strong) id routeChangeObserverToken;
@property (nonatomic) NSTimeInterval outputLatency;
#endif
@end

@implementation AEAudioUnitOutput
@dynamic running;

- (instancetype)initWithRenderer:(AERenderer *)renderer {
    if ( !(self = [super init]) ) return nil;
    
    if ( ![self setup] ) return nil;
    
    self.latencyCompensation = YES;
    self.renderer = renderer;
    
    return self;
}

- (void)dealloc {
    [self teardown];
}

- (BOOL)running {
    UInt32 unitRunning;
    UInt32 size = sizeof(unitRunning);
    if ( !AECheckOSStatus(AudioUnitGetProperty(_audioUnit, kAudioOutputUnitProperty_IsRunning, kAudioUnitScope_Global, 0,
                                               &unitRunning, &size),
                          "AudioUnitGetProperty(kAudioOutputUnitProperty_IsRunning)") ) {
        return NO;
    }
    
    return unitRunning;
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
#endif
    
    [self updateStreamFormat];
    
    // Start unit
    OSStatus result = AudioOutputUnitStart(_audioUnit);
    if ( !AECheckOSStatus(result, "AudioOutputUnitStart") ) {
        if ( error ) *error = [NSError errorWithDomain:AEAudioUnitOutputError code:result
                                              userInfo:@{ NSLocalizedDescriptionKey: @"Unable to start output unit" }];
        return NO;
    }
    
    return YES;
}

- (void)stop {
    // Stop unit
    AECheckOSStatus(AudioOutputUnitStop(_audioUnit), "AudioOutputUnitStop");
}

- (void)setSampleRate:(double)sampleRate {
    if ( fabs(_sampleRate - sampleRate) <= DBL_EPSILON ) return;
    
    _sampleRate = sampleRate;
    
    if ( self.running ) {
        [self updateStreamFormat];
    }
}

- (void)updateStreamFormat {
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
    }
    
    self.renderer.sampleRate = self.currentSampleRate;
    
    self.outputChannels = asbd.mChannelsPerFrame;
    self.renderer.outputChannels = self.outputChannels;
    
    // Update the stream format
    asbd = AEAudioDescription;
    asbd.mChannelsPerFrame = self.outputChannels;
    asbd.mSampleRate = self.sampleRate;
    AECheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
                                         &asbd, sizeof(asbd)),
                    "AudioUnitSetProperty(kAudioUnitProperty_StreamFormat)");
    
    if ( rateChanged && running ) {
        AECheckOSStatus(AudioOutputUnitStart(_audioUnit), "AudioOutputUnitStart");
    }
}

static void audioUnitStreamFormatChanged(void *inRefCon, AudioUnit inUnit, AudioUnitPropertyID inID,
                                         AudioUnitScope inScope, AudioUnitElement inElement) {
    AEAudioUnitOutput * self = (__bridge AEAudioUnitOutput *)inRefCon;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( self.running ) {
            [self updateStreamFormat];
        }
    });
}

static OSStatus audioUnitRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                                        const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber,
                                        UInt32 inNumberFrames, AudioBufferList *ioData) {
    // Render
    __unsafe_unretained AEAudioUnitOutput * THIS = (__bridge AEAudioUnitOutput *)inRefCon;
    
    AudioTimeStamp timestamp = *inTimeStamp;
    if ( THIS->_latencyCompensation ) {
        timestamp.mHostTime += AEHostTicksFromSeconds(THIS->_outputLatency);
    }
    
    AERendererRun(THIS->_renderer, ioData, inNumberFrames, &timestamp);
    return noErr;
}

- (BOOL)setup {
    // Get an instance of the output audio unit
    AudioComponentDescription acd =
#if TARGET_OS_IPHONE
        AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_Output, kAudioUnitSubType_RemoteIO);
#else
        AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_Output, kAudioUnitSubType_DefaultOutput);
#endif
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &acd);
    if ( !AECheckOSStatus(AudioComponentInstanceNew(inputComponent, &_audioUnit), "AudioComponentInstanceNew") ) {
        return NO;
    }
    
    // Set the maximum frames per slice to render
    AECheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global,
                                         0, &AEBufferStackMaxFramesPerSlice, sizeof(AEBufferStackMaxFramesPerSlice)),
                    "AudioUnitSetProperty(kAudioUnitProperty_MaximumFramesPerSlice)");
    
    // Set the render callback
    AURenderCallbackStruct rcbs = { .inputProc = audioUnitRenderCallback, .inputProcRefCon = (__bridge void *)(self) };
    AECheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, 0,
                                         &rcbs, sizeof(rcbs)),
                    "AudioUnitSetProperty(kAudioUnitProperty_SetRenderCallback)");
    
    // Initialize
    AECheckOSStatus(AudioUnitInitialize(_audioUnit), "AudioUnitInitialize");
    
    // Get the current sample rate and number of output channels
    AudioStreamBasicDescription asbd;
    UInt32 size = sizeof(asbd);
    AECheckOSStatus(AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &asbd, &size),
                    "AudioUnitGetProperty(kAudioUnitProperty_StreamFormat)");
    self.renderer.sampleRate = self.currentSampleRate = asbd.mSampleRate;
    self.renderer.outputChannels = self.outputChannels = asbd.mChannelsPerFrame;
    
    // Set the stream format
    asbd = AEAudioDescription;
    asbd.mChannelsPerFrame = self.outputChannels;
    AECheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
                                         &asbd, sizeof(asbd)),
                    "AudioUnitSetProperty(kAudioUnitProperty_StreamFormat)");
    
    // Register a callback to watch for stream format changes
    AECheckOSStatus(AudioUnitAddPropertyListener(_audioUnit, kAudioUnitProperty_StreamFormat, audioUnitStreamFormatChanged,
                                                 (__bridge void*)self),
                    "AudioUnitAddPropertyListener(kAudioUnitProperty_StreamFormat)");
    
#if TARGET_OS_IPHONE
    // Watch for session interruptions
    __block BOOL wasRunning;
    self.sessionInterruptionObserverToken =
    [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionInterruptionNotification object:nil queue:nil
                                                  usingBlock:^(NSNotification *notification) {
        NSInteger type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] integerValue];
        if ( type == AVAudioSessionInterruptionTypeBegan ) {
            wasRunning = self.running;
            if ( wasRunning ) {
                [self stop];
            }
        } else {
            if ( wasRunning ) {
                [self start:NULL];
            }
        }
    }];
    
    // Watch for media reset notifications
    self.mediaResetObserverToken =
    [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionMediaServicesWereResetNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *notification) {
        BOOL wasRunning = self.running;
        [self teardown];
        [self setup];
        if ( wasRunning ) {
            [self start:NULL];
        }
    }];
    
    // Watch for audio route changes
    self.routeChangeObserverToken =
    [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionRouteChangeNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *notification) {
        self.outputLatency = [AVAudioSession sharedInstance].outputLatency;
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
}

@end
