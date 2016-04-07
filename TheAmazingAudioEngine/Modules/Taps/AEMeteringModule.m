//
//  AEMeteringModule.m
//  TheAmazingAudioEngine
//
//  Created on 4/06/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import "AEMeteringModule.h"
#import <Accelerate/Accelerate.h>

@implementation AEMeteringModule {
    float _avgPowerLeft;
    float _avgPowerRight;
    float _peakPowerLeft;
    float _peakPowerRight;
}

- (instancetype)initWithRenderer:(AERenderer *)renderer {
    if ( !(self = [super initWithRenderer:renderer]) ) return nil;
    self.processFunction = AEMeteringModuleProcess;
    return self;
}

- (double)avgPowerLeft {
    return (double)_avgPowerLeft;
}

- (double)avgPowerRight {
    return (double)_avgPowerRight;
}

- (double)peakPowerLeft {
    return (double)_peakPowerLeft;
}

- (double)peakPowerRight {
    return (double)_peakPowerRight;
}

static void AEMeteringModuleProcess(__unsafe_unretained AEMeteringModule * THIS,
                                        const AERenderContext * _Nonnull context) {
    const AudioBufferList * abl = AEBufferStackGet(context->stack, 0);
    if ( !abl ) return;
    
    // "Left" Channel
    if ( abl->mNumberBuffers > 0 ) {
        float avg  = 0.0f, peak = 0.0f;
        vDSP_meamgv((float*)abl->mBuffers[0].mData, 1, &avg,  context->frames);
        vDSP_maxmgv((float*)abl->mBuffers[0].mData, 1, &peak, context->frames);
        THIS->_peakPowerLeft = peak;
        THIS->_avgPowerLeft = avg;
    }
    
    // "Right" Channel
    if ( abl->mNumberBuffers > 1 ) {
        float avg  = 0.0f, peak = 0.0f;
        vDSP_meamgv((float*)abl->mBuffers[1].mData, 1, &avg,  context->frames);
        vDSP_maxmgv((float*)abl->mBuffers[1].mData, 1, &peak, context->frames);
        THIS->_avgPowerRight = peak;
        THIS->_peakPowerRight = avg;
    }
}

@end