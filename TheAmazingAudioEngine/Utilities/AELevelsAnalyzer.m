//
//  AELevelsAnalyzer.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 30/11/17.
//  Copyright © 2017 A Tasty Pixel. All rights reserved.
//

#import "AELevelsAnalyzer.h"
#import "AETime.h"
#import "AEDSPUtilities.h"
#import <Accelerate/Accelerate.h>

static const float kAvgFalloffPerAnalysis = 0.1;
static const float kPeakFalloffPerAnalysis = 0.01;
static const AESeconds kAnalysisTimeout = 0.05;
static const AESeconds kTimeoutAnalysisFalloffInterval = 1.0;

@interface AELevelsAnalyzer () {
    AEHostTicks _lastAnalysis;
    float _average;
    float _peak;
}
@end

@implementation AELevelsAnalyzer
@dynamic peak, average;

void AELevelsAnalyzerAnalyzeBuffer(__unsafe_unretained AELevelsAnalyzer * THIS,
                                   const AudioBufferList * buffer,
                                   UInt32 numberFrames) {
    float max = 0;
    
    if ( numberFrames > 0 && buffer ) {
        for ( int i=0; i<buffer->mNumberBuffers; i++ ) {
            vDSP_maxmgv((float*)buffer->mBuffers[i].mData, 1, &max, numberFrames);
        }
    }
    
    THIS->_lastAnalysis = AECurrentTimeInHostTicks();
    THIS->_average = (kAvgFalloffPerAnalysis * max) + ((1.0-kAvgFalloffPerAnalysis) * THIS->_average);
    THIS->_peak = MAX(max, ((1.0-kPeakFalloffPerAnalysis) * THIS->_peak));
}

- (double)peak {
    AESeconds sinceLast = AECurrentTimeInSeconds()-AESecondsFromHostTicks(_lastAnalysis);
    if ( sinceLast < kAnalysisTimeout ) {
        return AEDSPRatioToDecibels(_peak);
    } else if ( sinceLast > kAnalysisTimeout+kTimeoutAnalysisFalloffInterval ) {
        return -INFINITY;
    } else {
        return AEDSPRatioToDecibels(_peak * (1.0 - (sinceLast / kTimeoutAnalysisFalloffInterval)));
    }
}

- (double)average {
    AESeconds sinceLast = AECurrentTimeInSeconds()-AESecondsFromHostTicks(_lastAnalysis);
    if ( sinceLast < kAnalysisTimeout ) {
        return AEDSPRatioToDecibels(_average);
    } else if ( sinceLast > kAnalysisTimeout+kTimeoutAnalysisFalloffInterval ) {
        return -INFINITY;
    } else {
        return AEDSPRatioToDecibels(_average * (1.0 - (sinceLast / kTimeoutAnalysisFalloffInterval)));
    }
}

@end
