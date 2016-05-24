//
//  AERenderer.m
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

#import "AERenderer.h"
#import "AETypes.h"
#import "AEManagedValue.h"
#import "AEAudioBufferListUtilities.h"

NSString * const AERendererDidChangeSampleRateNotification = @"AERendererDidChangeSampleRateNotification";
NSString * const AERendererDidChangeNumberOfOutputChannelsNotification = @"AERendererDidChangeNumberOfOutputChannelsNotification";

@interface AERenderer () {
    UInt32 _sampleTime;
}
@property (nonatomic, strong) AEManagedValue * blockValue;
@property (nonatomic, readwrite) AEBufferStack * stack;
@end

@implementation AERenderer
@dynamic block;

- (instancetype)init {
    if ( !(self = [super init]) ) return nil;
    _numberOfOutputChannels = 2;
    _sampleRate = 44100.0;
    self.blockValue = [AEManagedValue new];
    self.stack = AEBufferStackNew(0);
    return self;
}

- (void)dealloc {
    AEBufferStackFree(self.stack);
}

void AERendererRun(__unsafe_unretained AERenderer * THIS, const AudioBufferList * bufferList, UInt32 frames,
                   const AudioTimeStamp * timestamp) {
    
    // Reset the buffer stack, and set the frame count
    AEBufferStackReset(THIS->_stack);
    AEBufferStackSetFrameCount(THIS->_stack, frames);
    
    // Clear the output buffer
    AEAudioBufferListSilence(bufferList, 0, frames);
    
    // Run the block
    __unsafe_unretained AERenderLoopBlock block = (__bridge AERenderLoopBlock)AEManagedValueGetValue(THIS->_blockValue);
    if ( block ) {
        
        // Set our own sample time, to ensure continuity
        AudioTimeStamp time = *timestamp;
        time.mFlags |= kAudioTimeStampSampleTimeValid;
        time.mSampleTime = THIS->_sampleTime;
        THIS->_sampleTime += frames;
        
        AERenderContext context = {
            .output = bufferList,
            .frames = frames,
            .sampleRate = THIS->_sampleRate,
            .timestamp = &time,
            .offlineRendering = THIS->_isOffline,
            .stack = THIS->_stack
        };
        
        block(&context);
    }
}

- (void)setBlock:(AERenderLoopBlock)block {
    self.blockValue.objectValue = [block copy];
}

- (AERenderLoopBlock)block {
    return self.blockValue.objectValue;
}

- (void)setSampleRate:(double)sampleRate {
    if ( fabs(sampleRate - _sampleRate) < DBL_EPSILON ) return;
    _sampleRate = sampleRate;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AERendererDidChangeSampleRateNotification object:self];
}

- (void)setNumberOfOutputChannels:(int)numberOfOutputChannels {
    if ( _numberOfOutputChannels == numberOfOutputChannels ) return;
    _numberOfOutputChannels = numberOfOutputChannels;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AERendererDidChangeNumberOfOutputChannelsNotification object:self];
}

@end
