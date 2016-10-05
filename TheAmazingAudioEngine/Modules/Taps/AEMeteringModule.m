//
//  AEMeteringModule.m
//  TheAmazingAudioEngine
//
//  Created by Leo Thiessen on 2016-04-14.
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

#import "AEMeteringModule.h"
@import Accelerate;

/*!
 * Audio level metering data
 */
typedef struct __audio_meters_t {
    int      maxChannel;
    int      capacity;
    double * chanMeanAccumulator;
    int      chanMeanBlockCount;
    float *  chanPeak;
    float *  chanAverage;
    BOOL     reset;
} audio_meters_t;

@interface AEMeteringModule () {
    AEMeteringLevels levelsStruct;
    audio_meters_t   metersStruct;
}
@end

@implementation AEMeteringModule

- (instancetype _Nullable)initWithRenderer:(AERenderer * _Nullable)renderer {
    if ( !(self = [super initWithRenderer:renderer]) ) {
        return nil;
    }
    [self _setupWithMaxChannel:2]; // default of 2 channels, aka "stereo"
    return self;
}

- (instancetype _Nullable)initWithRenderer:(AERenderer * _Nullable)renderer maxChannel:(int)maxChannel {
    if ( maxChannel < 1 || !(self = [super initWithRenderer:renderer]) ) {
        return nil;
    }
    [self _setupWithMaxChannel:maxChannel];
    return self;
}

- (void)_setupWithMaxChannel:(int)maxChannel {
    metersStruct.maxChannel          = maxChannel;
    metersStruct.capacity            = maxChannel;
    metersStruct.chanMeanAccumulator = calloc(maxChannel, sizeof(double));
    metersStruct.chanMeanBlockCount  = 0;
    metersStruct.chanPeak            = calloc(maxChannel, sizeof(float));
    metersStruct.chanAverage         = calloc(maxChannel, sizeof(float));
    metersStruct.reset               = NO;
    
    levelsStruct.maxChannel = maxChannel;
    levelsStruct.channels   = calloc(maxChannel, sizeof(AEMeteringChannelLevels));
    
    self.processFunction = AEMeteringModuleProcess;
}

- (void)dealloc {
    if ( levelsStruct.channels ) {
        free(levelsStruct.channels);
    }
    free(metersStruct.chanMeanAccumulator);
    free(metersStruct.chanPeak);
    free(metersStruct.chanAverage);
}

- (void)rendererDidChangeNumberOfChannels {
    int newChannelCount = self.renderer.numberOfOutputChannels;
    if ( newChannelCount <= metersStruct.capacity ) {
        metersStruct.maxChannel = newChannelCount;
        levelsStruct.maxChannel  = newChannelCount;
        if ( levelsStruct.channels ) {
            for ( int i = newChannelCount; i < metersStruct.capacity; ++i ) { // Zero out any unused capacity
                levelsStruct.channels[i].average = 0;
                levelsStruct.channels[i].peak = 0;
            }
        }
    }
}

- (AEMeteringLevels * _Nonnull)levels {
    if ( levelsStruct.channels ) {
        for ( int i = 0; i < metersStruct.maxChannel; ++i ) {
            levelsStruct.channels[i].average = metersStruct.chanAverage[i];
            levelsStruct.channels[i].peak = metersStruct.chanPeak[i];
        }
        metersStruct.reset = YES;
    }
    return &levelsStruct;
}

static void AEMeteringModuleProcess(__unsafe_unretained AEMeteringModule * self,
                                    const AERenderContext * _Nonnull context) {
    const AudioBufferList * abl = AEBufferStackGet(context->stack, 0);
    if ( !abl ) return;
    
    if ( self->metersStruct.reset ) {
        self->metersStruct.reset = NO;
        self->metersStruct.chanMeanBlockCount = 0;
        vDSP_vclr(self->metersStruct.chanPeak, 1, self->metersStruct.capacity);
        vDSP_vclr(self->metersStruct.chanAverage, 1, self->metersStruct.capacity);
        vDSP_vclrD(self->metersStruct.chanMeanAccumulator, 1, self->metersStruct.capacity);
    }
    
    float peak, avg;
    for ( int i = 0; i < abl->mNumberBuffers && i < self->metersStruct.maxChannel; ++i ) {
        peak = 0, avg = 0;
        vDSP_maxmgv((float*)abl->mBuffers[i].mData, 1, &peak, context->frames);
        if ( peak > self->metersStruct.chanPeak[i] ) { self->metersStruct.chanPeak[i] = peak; }
        vDSP_meamgv((float*)abl->mBuffers[i].mData, 1, &avg, context->frames);
        self->metersStruct.chanMeanAccumulator[i] += avg;
        if ( i == 0 ) { self->metersStruct.chanMeanBlockCount++; }
        self->metersStruct.chanAverage[i] = self->metersStruct.chanMeanAccumulator[i] / (double)self->metersStruct.chanMeanBlockCount;
    }
}

@end
