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

NSString * const AERendererDidChangeSampleRateNotification = @"AERendererDidChangeSampleRateNotification";
NSString * const AERendererDidChangeChannelCountNotification = @"AERendererDidChangeChannelCountNotification";

@interface AERenderer ()
@property (nonatomic, strong) AEManagedValue * blockValue;
@property (nonatomic, readwrite) AEBufferStack * stack;
@end

@implementation AERenderer
@dynamic block;

- (instancetype)init {
    if ( !(self = [super init]) ) return nil;
    _outputChannels = 2;
    _sampleRate = 44100.0;
    self.blockValue = [AEManagedValue new];
    self.stack = AEBufferStackNew(0);
    return self;
}

void AERendererRun(__unsafe_unretained AERenderer * THIS, AudioBufferList * bufferList, UInt32 frames,
                   const AudioTimeStamp * timestamp) {
    
    // Reset the buffer stack, and set the frame count
    AEBufferStackReset(THIS->_stack);
    AEBufferStackSetFrameCount(THIS->_stack, frames);
    
    // Clear the output buffer
    for ( int i=0; i<bufferList->mNumberBuffers; i++ ) {
        memset(bufferList->mBuffers[i].mData, 0, frames * AEAudioDescription.mBytesPerFrame);
    }
    
    // Run the block
    __unsafe_unretained AERenderLoopBlock block = (__bridge AERenderLoopBlock)AEManagedValueGetValue(THIS->_blockValue);
    if ( block ) {
        AERenderContext context = { bufferList, frames, THIS->_sampleRate, timestamp, THIS->_stack };
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

- (void)setOutputChannels:(int)outputChannels {
    if ( _outputChannels == outputChannels ) return;
    _outputChannels = outputChannels;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AERendererDidChangeChannelCountNotification object:self];
}

@end
