//
//  AESplitterModule.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 30/05/2016.
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

#import "AESplitterModule.h"
#import "AEAudioBufferListUtilities.h"
#import "AEBufferStack.h"
#import "AEUtilities.h"

@interface AESplitterModule () {
    AudioBufferList * _buffer;
    AudioTimeStamp _timestamp;
    UInt64 _bufferedTime;
    UInt32 _bufferedFrames;
}
@property (nonatomic, strong, readwrite) AEModule * module;
@end

@implementation AESplitterModule

- (instancetype)initWithRenderer:(AERenderer *)renderer module:(AEModule *)module {
    if ( !(self = [super initWithRenderer:renderer]) ) return nil;
    _numberOfChannels = 2;
    _buffer = AEAudioBufferListCreate(AEBufferStackMaxFramesPerSlice);
    _bufferedTime = UINT32_MAX;
    self.module = module;
    self.processFunction = AESplitterModuleProcess;
    return self;
}

- (void)setNumberOfChannels:(int)numberOfChannels {
    _numberOfChannels = numberOfChannels;
    AEAudioBufferListFree(_buffer);
    _buffer = AEAudioBufferListCreateWithFormat(AEAudioDescriptionWithChannelsAndRate(_numberOfChannels, 0),
                                                AEBufferStackMaxFramesPerSlice);
}

static void AESplitterModuleProcess(__unsafe_unretained AESplitterModule * self, const AERenderContext * _Nonnull context) {
    
    if ( (UInt64)context->timestamp->mSampleTime != self->_bufferedTime ) {
        
        // Run module, cache result
        #ifdef DEBUG
        int priorStackDepth = AEBufferStackCount(context->stack);
        #endif
        
        AEModuleProcess(self->_module, context);
        
        #ifdef DEBUG
        if ( AEBufferStackCount(context->stack) != priorStackDepth+1 ) {
            if ( AERateLimit() ) {
                printf("A module within AESplitterModule didn't push a buffer! Sure it's a generator?\n");
            }
            return;
        }
        #endif
        
        self->_timestamp = *AEBufferStackGetTimeStampForBuffer(context->stack, 0);
        self->_bufferedTime = (UInt64)context->timestamp->mSampleTime;
        self->_bufferedFrames = context->frames;
        AEAudioBufferListCopyContents(self->_buffer, AEBufferStackGet(context->stack, 0), 0, 0, context->frames);
    } else {
        
        // Return cached result
        #ifdef DEBUG
        if ( context->frames != self->_bufferedFrames && AERateLimit() ) {
            printf("AESplitterModule has been run with different frame counts. Are you using it from a variable-rate filter?\n");
        }
        #endif
        
        AEBufferStackPushWithChannels(context->stack, 1, self->_numberOfChannels);
        *AEBufferStackGetTimeStampForBuffer(context->stack, 0) = self->_timestamp;
        AEAudioBufferListCopyContents(AEBufferStackGet(context->stack, 0), self->_buffer, 0, 0, context->frames);
    }
}

@end
