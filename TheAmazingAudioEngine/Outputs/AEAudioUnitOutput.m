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
#import "AEIOAudioUnit.h"
#import "AERenderer.h"
#import "AETypes.h"
#import "AEUtilities.h"
#import "AEBufferStack.h"
#import "AETime.h"
#import "AEManagedValue.h"
#import "AEAudioBufferListUtilities.h"
#import "AEAudioUnitInputModule.h"
#import <AVFoundation/AVFoundation.h>

NSString * const AEAudioUnitOutputDidChangeSampleRateNotification = @"AEAudioUnitOutputDidChangeSampleRateNotification";
NSString * const AEAudioUnitOutputDidChangeNumberOfOutputChannelsNotification = @"AEAudioUnitOutputDidChangeNumberOfOutputChannelsNotification";

#ifdef DEBUG
static const AESeconds kRenderTimeReportInterval = 0.0;   // Seconds between render time reports; 0 = no reporting
static const double kRenderBudgetWarningThreshold = 0.75; // Ratio of total buffer duration to hit before budget overrun warnings
static const AESeconds kRenderBudgetWarningInitialDelay = 4.0; // Seconds to wait before warning about budget overrun
#endif

@interface AEAudioUnitInputModule ()
- (instancetype)initWithRenderer:(AERenderer *)renderer audioUnit:(AEIOAudioUnit *)audioUnit;
@end

@interface AEAudioUnitOutput () {
#ifdef DEBUG
    AESeconds _averageRenderDurationAccumulator;
    int       _averageRenderDurationSampleCount;
    AESeconds _maximumRenderDuration;
    AESeconds _lastReportTime;
    AESeconds _firstReportTime;
#endif
}
@property (nonatomic, strong) AEIOAudioUnit * ioUnit;
@property (nonatomic, strong) AEManagedValue * rendererValue;
@property (nonatomic, strong, readwrite) AEAudioUnitInputModule * inputModule;
@property (nonatomic, strong) id ioUnitStreamChangeObserverToken;
@end

@implementation AEAudioUnitOutput
@dynamic renderer, audioUnit, sampleRate, currentSampleRate, running, numberOfOutputChannels;
#if TARGET_OS_IPHONE
@dynamic latencyCompensation;
#endif

- (instancetype)initWithRenderer:(AERenderer *)renderer {
    if ( !(self = [super init]) ) return nil;
    
    AEManagedValue * rendererValue = [AEManagedValue new];
    self.rendererValue = rendererValue;
    
    self.ioUnit = [AEIOAudioUnit new];
    self.ioUnit.outputEnabled = YES;
    
    __unsafe_unretained AEAudioUnitOutput * weakSelf = self;
    self.ioUnit.renderBlock = ^(AudioBufferList * _Nonnull ioData, UInt32 frames, const AudioTimeStamp * _Nonnull timestamp) {
        AEManagedValueCommitPendingUpdates();
        
        __unsafe_unretained AERenderer * renderer = (__bridge AERenderer*)AEManagedValueGetValue(rendererValue);
        if ( renderer ) {
            #ifdef DEBUG
                AEHostTicks start = AECurrentTimeInHostTicks();
            #endif
            
            AERendererRun(renderer, ioData, frames, timestamp);
            
            #ifdef DEBUG
                AEAudioUnitOutputReportRenderTime(weakSelf,
                    AESecondsFromHostTicks(AECurrentTimeInHostTicks() - start),
                    (double)frames / AEIOAudioUnitGetSampleRate(weakSelf->_ioUnit));
            #endif
        } else {
            AEAudioBufferListSilence(ioData, 0, frames);
        }
    };
    
    self.ioUnitStreamChangeObserverToken =
    [[NSNotificationCenter defaultCenter] addObserverForName:AEIOAudioUnitDidUpdateStreamFormatNotification object:self.ioUnit
                                                       queue:NULL usingBlock:^(NSNotification * note) {
        BOOL rateChanged = fabs(weakSelf.renderer.sampleRate - weakSelf.ioUnit.currentSampleRate) > DBL_EPSILON;
        BOOL channelsChanged = weakSelf.renderer.numberOfOutputChannels != weakSelf.ioUnit.numberOfOutputChannels;
        
        weakSelf.renderer.sampleRate = weakSelf.ioUnit.currentSampleRate;
        weakSelf.renderer.numberOfOutputChannels = weakSelf.ioUnit.numberOfOutputChannels;
        
        if ( rateChanged ) {
           [[NSNotificationCenter defaultCenter]
            postNotificationName:AEAudioUnitOutputDidChangeSampleRateNotification object:weakSelf];
        }
        
        if ( channelsChanged ) {
           [[NSNotificationCenter defaultCenter]
            postNotificationName:AEAudioUnitOutputDidChangeNumberOfOutputChannelsNotification object:weakSelf];
        }
    }];
    
#if TARGET_OS_IPHONE
    self.latencyCompensation = YES;
#endif
    
    self.renderer = renderer;
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.ioUnitStreamChangeObserverToken];
    self.ioUnit = nil;
}

- (BOOL)setup:(NSError * __autoreleasing *)error {
    return [self.ioUnit setup:error];
}

- (BOOL)start:(NSError *__autoreleasing *)error {
    if ( !self.ioUnit.audioUnit ) {
        if ( ![self.ioUnit setup:error] ) return NO;
    }
    
    return [self.ioUnit start:error];
}

- (void)stop {
    if ( !self.ioUnit.audioUnit ) return;
    [self.ioUnit stop];
}

- (AERenderer *)renderer {
    return self.rendererValue.objectValue;
}

- (void)setRenderer:(AERenderer *)renderer {
    renderer.sampleRate = self.ioUnit.currentSampleRate;
    renderer.numberOfOutputChannels = self.ioUnit.numberOfOutputChannels;
    renderer.isOffline = NO;
    
    self.rendererValue.objectValue = renderer;
}

- (AudioUnit)audioUnit {
    if ( !self.ioUnit.audioUnit ) {
        NSError * error = nil;
        if ( ![self.ioUnit setup:&error] ) {
            NSLog(@"Unable to set up IO unit: %@", error);
            return NULL;
        }
    }
    return self.ioUnit.audioUnit;
}

- (double)sampleRate {
    return self.ioUnit.sampleRate;
}

- (void)setSampleRate:(double)sampleRate {
    self.ioUnit.sampleRate = sampleRate;
}

- (double)currentSampleRate {
    return self.ioUnit.currentSampleRate;
}

- (BOOL)running {
    return self.ioUnit.running;
}

- (int)numberOfOutputChannels {
    return self.ioUnit.numberOfOutputChannels;
}

- (AEAudioUnitInputModule *)inputModule {
    if ( !_inputModule ) {
#if TARGET_OS_IPHONE
        _inputModule = [[AEAudioUnitInputModule alloc] initWithRenderer:self.renderer audioUnit:self.ioUnit];
#else
        _inputModule = [[AEAudioUnitInputModule alloc] initWithRenderer:self.renderer];
#endif
    }
    
    return _inputModule;
}

#if TARGET_OS_IPHONE
- (BOOL)latencyCompensation {
    return self.ioUnit.latencyCompensation;
}

- (void)setLatencyCompensation:(BOOL)latencyCompensation {
    self.ioUnit.latencyCompensation = latencyCompensation;
}

AESeconds AEAudioUnitOutputGetOutputLatency(__unsafe_unretained AEAudioUnitOutput * self) {
    return AEIOAudioUnitGetOutputLatency(self->_ioUnit);
}
#endif

AudioUnit _Nullable AEAudioUnitOutputGetAudioUnit(__unsafe_unretained AEAudioUnitOutput * self) {
    return AEIOAudioUnitGetAudioUnit(self->_ioUnit);
}

#ifdef DEBUG
static void AEAudioUnitOutputReportRenderTime(__unsafe_unretained AEAudioUnitOutput * self,
                                              AESeconds renderTime,
                                              AESeconds bufferDuration) {
    AESeconds now = AECurrentTimeInSeconds();
    if ( !self->_firstReportTime ) self->_firstReportTime = now;
    
    if ( now - self->_firstReportTime > kRenderBudgetWarningInitialDelay
            && renderTime > bufferDuration * kRenderBudgetWarningThreshold ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"Warning: render took %lfs, %0.4lf%% of buffer duration.",
                  renderTime, (renderTime / bufferDuration) * 100.0);
        });
    }
    
    if ( kRenderTimeReportInterval > 0 ) {
        self->_averageRenderDurationAccumulator += renderTime;
        self->_averageRenderDurationSampleCount++;
        
        self->_maximumRenderDuration = MAX(self->_maximumRenderDuration, renderTime);
        
        if ( now - self->_lastReportTime > kRenderTimeReportInterval ) {
            AESeconds average = self->_averageRenderDurationAccumulator / self->_averageRenderDurationSampleCount;
            AESeconds maximum = self->_maximumRenderDuration;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                AESeconds bufferDuration = self.ioUnit.IOBufferDuration;
                NSLog(@"Render time report: %lfs/%0.4lf%% average,\t%lfs/%0.4lf%% maximum",
                      average, (average/bufferDuration)*100.0, maximum, (maximum/bufferDuration)*100.0);
            });
            
            self->_lastReportTime = now;
            self->_averageRenderDurationAccumulator = 0;
            self->_averageRenderDurationSampleCount = 0;
            self->_maximumRenderDuration = 0;
        }
    }
}
#endif

@end
