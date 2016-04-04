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
@import AVFoundation;

@interface AEAudioUnitOutput ()
@property (nonatomic, strong) AEIOAudioUnit * ioUnit;
@property (nonatomic, strong) AEManagedValue * rendererValue;
@property (nonatomic, strong) id ioUnitStreamChangeObserverToken;
@end

@implementation AEAudioUnitOutput
@dynamic renderer, audioUnit, sampleRate, currentSampleRate, running, outputChannels;
#if TARGET_OS_IPHONE
@dynamic latencyCompensation;
#endif

- (instancetype)initWithRenderer:(AERenderer *)renderer {
    if ( !(self = [super init]) ) return nil;
    
    AEManagedValue * rendererValue = [AEManagedValue new];
    rendererValue.objectValue = renderer;
    self.rendererValue = rendererValue;
    
    self.ioUnit = [AEIOAudioUnit new];
    self.ioUnit.outputEnabled = YES;
    self.ioUnit.renderBlock = ^(AudioBufferList * _Nonnull ioData, UInt32 frames, const AudioTimeStamp * _Nonnull timestamp) {
        __unsafe_unretained AERenderer * renderer = (__bridge AERenderer*)AEManagedValueGetValue(rendererValue);
        if ( renderer ) {
            AERendererRun(renderer, ioData, frames, timestamp);
        } else {
            AEAudioBufferListSilence(ioData, AEAudioDescription, 0, frames);
        }
    };
    
    self.ioUnitStreamChangeObserverToken =
    [[NSNotificationCenter defaultCenter] addObserverForName:AEIOAudioUnitDidUpdateStreamFormatNotification object:self.ioUnit
                                                       queue:NULL usingBlock:^(NSNotification * _Nonnull note) {
        self.renderer.sampleRate = self.ioUnit.currentSampleRate;
        self.renderer.outputChannels = self.ioUnit.outputChannels;
    }];
    
    if ( ![self.ioUnit setup:NULL] ) return nil;
    
#if TARGET_OS_IPHONE
    self.latencyCompensation = YES;
#endif
    
    self.renderer = renderer;
    self.renderer.sampleRate = self.ioUnit.currentSampleRate;
    self.renderer.outputChannels = self.ioUnit.outputChannels;
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.ioUnitStreamChangeObserverToken];
    self.ioUnit = nil;
}

- (BOOL)start:(NSError *__autoreleasing *)error {
    return [self.ioUnit start:error];
}

- (void)stop {
    [self.ioUnit stop];
}

- (AERenderer *)renderer {
    return self.rendererValue.objectValue;
}

- (void)setRenderer:(AERenderer *)renderer {
    self.rendererValue.objectValue = renderer;
}

- (AudioUnit)audioUnit {
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

- (int)outputChannels {
    return self.ioUnit.outputChannels;
}

#if TARGET_OS_IPHONE
- (BOOL)latencyCompensation {
    return self.ioUnit.latencyCompensation;
}

- (void)setLatencyCompensation:(BOOL)latencyCompensation {
    self.ioUnit.latencyCompensation = latencyCompensation;
}
#endif

AudioUnit _Nullable AEAudioUnitOutputGetAudioUnit(__unsafe_unretained AEAudioUnitOutput * _Nonnull output) {
    return AEIOAudioUnitGetAudioUnit(output->_ioUnit);
}

@end
