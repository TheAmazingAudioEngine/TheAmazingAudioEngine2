//
//  AEAudioUnitInputModule.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 25/03/2016.
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

#import "AEAudioUnitInputModule.h"
#import "AETypes.h"
#import "AEUtilities.h"
#import "AEBufferStack.h"
#import "AEAudioBufferListUtilities.h"
@import AVFoundation;

NSString * const AEAudioUnitInputModuleError = @"AEAudioUnitInputModuleError";

static void * kAudioSessionLatencyChanged = &kAudioSessionLatencyChanged;

@interface AEAudioUnitInputModule ()
@property (nonatomic, readwrite) int inputChannels;
@property (nonatomic) int usableInputChannels;
#if TARGET_OS_IPHONE
@property (nonatomic, strong) id sessionInterruptionObserverToken;
@property (nonatomic, strong) id mediaResetObserverToken;
@property (nonatomic) NSTimeInterval inputLatency;
#endif
@end

@implementation AEAudioUnitInputModule

- (instancetype)initWithRenderer:(AERenderer *)renderer {
    if ( !(self = [super initWithRenderer:renderer]) ) return nil;
    if ( ![self setup] ) return nil;
    self.processFunction = AEAudioUnitInputModuleProcess;
    
#if TARGET_OS_IPHONE
    [[AVAudioSession sharedInstance] addObserver:self forKeyPath:@"inputLatency" options:0 context:kAudioSessionLatencyChanged];
#endif
    
    return self;
}

- (void)dealloc {
#if TARGET_OS_IPHONE
    [[AVAudioSession sharedInstance] removeObserver:self forKeyPath:@"outputLatency"];
#endif
    
    self.renderer = nil;
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
    
    self.inputLatency = [AVAudioSession sharedInstance].inputLatency;
#endif
    
    // Start unit
    OSStatus result = AudioOutputUnitStart(_audioUnit);
    if ( !AECheckOSStatus(result, "AudioOutputUnitStart") ) {
        if ( error ) *error = [NSError errorWithDomain:AEAudioUnitInputModuleError code:result
                                              userInfo:@{ NSLocalizedDescriptionKey: @"Unable to start output unit" }];
        return NO;
    }
    
    return YES;
}

- (void)stop {
    // Stop unit
    AECheckOSStatus(AudioOutputUnitStop(_audioUnit), "AudioOutputUnitStop");
}

static void AEAudioUnitInputModuleProcess(__unsafe_unretained AEAudioUnitInputModule * self,
                                          const AERenderContext * _Nonnull context) {
    if ( !self->_usableInputChannels ) {
        const AudioBufferList * abl = AEBufferStackPush(context->stack, 1);
        AEAudioBufferListSilence(abl, AEAudioDescription, 0, context->frames);
        return;
    }
    
    const AudioBufferList * abl = AEBufferStackPushWithChannels(context->stack, 1, self->_usableInputChannels);
    if ( !abl) return;
    
    AudioUnitRenderActionFlags flags = 0;
    AEAudioBufferListCopyOnStack(mutableAbl, abl, 0);
    OSStatus status = AudioUnitRender(self->_audioUnit, &flags, context->timestamp, 1, context->frames, mutableAbl);
    if ( status != noErr ) {
        if ( status == -1 || status == kAudioToolboxErr_CannotDoInCurrentContext ) {
            // Ignore these errors silently
        } else {
            AECheckOSStatus(status, "AudioUnitRender");
        }
        AEAudioBufferListSilence(abl, AEAudioDescription, 0, context->frames);
    }
}

- (BOOL)setup {
    // Get an instance of the output audio unit
    AudioComponentDescription acd =
#if TARGET_OS_IPHONE
        AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_Output, kAudioUnitSubType_RemoteIO);
#else
        AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_Output, kAudioUnitSubType_DefaultInput);
#endif
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &acd);
    if ( !AECheckOSStatus(AudioComponentInstanceNew(inputComponent, &_audioUnit), "AudioComponentInstanceNew") ) {
        return NO;
    }
    
    // Set the maximum frames per slice to render
    AECheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global,
                                         0, &AEBufferStackMaxFramesPerSlice, sizeof(AEBufferStackMaxFramesPerSlice)),
                    "AudioUnitSetProperty(kAudioUnitProperty_MaximumFramesPerSlice)");
    
    // Enable input
    UInt32 flag = 1;
    AECheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1,
                                         &flag, sizeof(flag)),
                    "AudioUnitSetProperty(kAudioOutputUnitProperty_EnableIO)");
    
    // Disable output
    flag = 0;
    AECheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0,
                                         &flag, sizeof(flag)),
                    "AudioUnitSetProperty(kAudioOutputUnitProperty_EnableIO)");
    
    // Initialize
    AECheckOSStatus(AudioUnitInitialize(_audioUnit), "AudioUnitInitialize");
    
    // Get the current number of input channels and sample rate
    AudioStreamBasicDescription asbd;
    UInt32 size = sizeof(asbd);
    AECheckOSStatus(AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, &asbd, &size),
                    "AudioUnitGetProperty(kAudioUnitProperty_StreamFormat)");
    self.inputChannels = asbd.mChannelsPerFrame;
    self.usableInputChannels = MIN(self.inputChannels, AEBufferStackGetMaximumChannelsPerBuffer(self.renderer.stack));
    
    // Set the stream format
    asbd = AEAudioDescription;
    asbd.mSampleRate = self.renderer.sampleRate;
    asbd.mChannelsPerFrame = self.usableInputChannels;
    AECheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1,
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
    [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionMediaServicesWereResetNotification object:nil queue:nil
                                                  usingBlock:^(NSNotification *notification) {
        BOOL wasRunning = self.running;
        [self teardown];
        [self setup];
        if ( wasRunning ) {
            [self start:NULL];
        }
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
#endif
    AECheckOSStatus(AudioUnitUninitialize(_audioUnit), "AudioUnitUninitialize");
    AECheckOSStatus(AudioComponentInstanceDispose(_audioUnit), "AudioComponentInstanceDispose");
}

- (void)rendererDidChangeSampleRate {
    [self updateStreamFormat];
}

- (void)updateStreamFormat {
    // Get the current number of input channels
    AudioStreamBasicDescription asbd;
    UInt32 size = sizeof(asbd);
    AECheckOSStatus(AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,
                                         1, &asbd, &size),
                    "AudioUnitGetProperty(kAudioUnitProperty_StreamFormat)");
    self.inputChannels = asbd.mChannelsPerFrame;
    self.usableInputChannels = MIN(self.inputChannels, AEBufferStackGetMaximumChannelsPerBuffer(self.renderer.stack));
    
    // Set the stream format
    asbd = AEAudioDescription;
    asbd.mChannelsPerFrame = self.usableInputChannels;
    asbd.mSampleRate = self.renderer.sampleRate;
    AECheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1,
                                         &asbd, sizeof(asbd)),
                    "AudioUnitSetProperty(kAudioUnitProperty_StreamFormat)");
}

static void audioUnitStreamFormatChanged(void *inRefCon, AudioUnit inUnit, AudioUnitPropertyID inID,
                                         AudioUnitScope inScope, AudioUnitElement inElement) {
    AEAudioUnitInputModule * self = (__bridge AEAudioUnitInputModule *)inRefCon;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateStreamFormat];
    });
}

#if TARGET_OS_IPHONE
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void *)context {
    if ( context == kAudioSessionLatencyChanged ) {
        self.inputLatency = [AVAudioSession sharedInstance].inputLatency;
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}
#endif

@end
