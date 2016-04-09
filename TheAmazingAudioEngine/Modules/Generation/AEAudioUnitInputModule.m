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
#import "AEIOAudioUnit.h"
#import "AETypes.h"
#import "AEUtilities.h"
#import "AEBufferStack.h"
#import "AEAudioBufferListUtilities.h"
@import AVFoundation;

@interface AEAudioUnitInputModule ()
@property (nonatomic, strong) AEIOAudioUnit * ioUnit;
@property (nonatomic, readwrite) int inputChannels;
@property (nonatomic, strong) id ioUnitStreamChangeObserverToken;
@property (nonatomic) BOOL ownsIOUnit;
@end

@implementation AEAudioUnitInputModule
@dynamic audioUnit, running;
#if TARGET_OS_IPHONE
@dynamic latencyCompensation;
#endif

- (instancetype)initWithRenderer:(AERenderer *)renderer {
    return [self initWithRenderer:renderer audioUnit:nil];
}

- (instancetype)initWithRenderer:(AERenderer *)renderer audioUnit:(AEIOAudioUnit *)audioUnit {
    if ( !(self = [super initWithRenderer:renderer]) ) return nil;
    
    if ( audioUnit ) {
        self.ioUnit = audioUnit;
        self.ioUnit.inputEnabled = YES;
    } else {
        self.ioUnit = [AEIOAudioUnit new];
        self.ioUnit.inputEnabled = YES;
        self.ioUnit.sampleRate = self.renderer.sampleRate;
        self.ownsIOUnit = YES;
    }
    
    self.ioUnit.maxInputChannels = AEBufferStackGetMaximumChannelsPerBuffer(self.renderer.stack);
    
    __weak AEAudioUnitInputModule * weakSelf = self;
    self.ioUnitStreamChangeObserverToken =
    [[NSNotificationCenter defaultCenter] addObserverForName:AEIOAudioUnitDidUpdateStreamFormatNotification object:self.ioUnit
                                                       queue:NULL usingBlock:^(NSNotification * _Nonnull note) {
        weakSelf.inputChannels = weakSelf.ioUnit.inputChannels;
    }];
    
    if ( self.ownsIOUnit ) {
        if ( ![self.ioUnit setup:NULL] ) return nil;
    }
    
    self.inputChannels = self.ioUnit.inputChannels;
    self.processFunction = AEAudioUnitInputModuleProcess;
    
#if TARGET_OS_IPHONE
    self.latencyCompensation = YES;
#endif
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.ioUnitStreamChangeObserverToken];
}

- (BOOL)running {
    return self.ioUnit.running;
}

- (BOOL)start:(NSError *__autoreleasing *)error {
    if ( !self.ownsIOUnit ) return YES;
    return [self.ioUnit start:error];
}

- (void)stop {
    if ( !self.ownsIOUnit ) return;
    [self.ioUnit stop];
}

#if TARGET_OS_IPHONE
- (BOOL)latencyCompensation {
    return self.ioUnit.latencyCompensation;
}

- (void)setLatencyCompensation:(BOOL)latencyCompensation {
    self.ioUnit.latencyCompensation = latencyCompensation;
}

AESeconds AEAudioUnitInputModuleGetInputLatency(__unsafe_unretained AEAudioUnitInputModule * self) {
    return AEIOAudioUnitGetInputLatency(self->_ioUnit);
}
#endif

AudioTimeStamp AEAudioUnitInputModuleGetInputTimestamp(__unsafe_unretained AEAudioUnitInputModule * self) {
    return AEIOAudioUnitGetInputTimestamp(self->_ioUnit);
}

static void AEAudioUnitInputModuleProcess(__unsafe_unretained AEAudioUnitInputModule * self,
                                          const AERenderContext * _Nonnull context) {
    if ( !self->_inputChannels ) {
        const AudioBufferList * abl = AEBufferStackPush(context->stack, 1);
        AEAudioBufferListSilence(abl, AEAudioDescription, 0, context->frames);
        return;
    }
    
    const AudioBufferList * abl = AEBufferStackPushWithChannels(context->stack, 1, self->_inputChannels);
    if ( !abl) return;
    
    OSStatus status = AEIOAudioUnitRenderInput(self->_ioUnit, abl, context->frames);
    if ( status != noErr ) {
        if ( status == -1 || status == kAudioToolboxErr_CannotDoInCurrentContext ) {
            // Ignore these errors silently
        } else {
            AECheckOSStatus(status, "AudioUnitRender");
        }
        AEAudioBufferListSilence(abl, AEAudioDescription, 0, context->frames);
    }
}

- (void)rendererDidChangeSampleRate {
    if ( self.ownsIOUnit ) {
        self.ioUnit.sampleRate = self.renderer.sampleRate;
    }
}

@end
