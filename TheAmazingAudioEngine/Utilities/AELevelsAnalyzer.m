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

static const int kRMSWindowFrameCount = 4096;
static const int kRMSBufferBlockCountMax = kRMSWindowFrameCount / 64;
static const AESeconds kPeakHoldInterval = 0.5;
static const float kPeakFalloffPerSecond = 3.0;
static const AESeconds kAnalysisTimeout = 0.05;
static const AESeconds kTimeoutAnalysisFalloffInterval = 1.0;
static const AESeconds kQueryTimeout = 0.5;

@interface AELevelsAnalyzer () {
    AESeconds _lastAnalysis;
    AESeconds _lastPeak;
    AESeconds _lastQuery;
    float _peak;
    struct { float sumSquare; int n; } _sumSquareBuffer[kRMSBufferBlockCountMax];
    int _sumSquareBufferHead;
    float _sumSquareAccumulator;
    int _sumSquareN;
    float _meanSumSquare;
}
@end

@implementation AELevelsAnalyzer
@dynamic peak, average;

void AELevelsAnalyzerAnalyzeBuffer(__unsafe_unretained AELevelsAnalyzer * THIS, const AudioBufferList * buffer, UInt32 numberFrames) {
    AELevelsAnalyzerMixAndAnalyzeChannel(THIS, buffer, -1, numberFrames, YES);
}

void AELevelsAnalyzerMixAndAnalyzeBuffer(__unsafe_unretained AELevelsAnalyzer * THIS, const AudioBufferList * buffer, UInt32 numberFrames, BOOL first) {
    AELevelsAnalyzerMixAndAnalyzeChannel(THIS, buffer, -1, numberFrames, first);
}

void AELevelsAnalyzerAnalyzeBufferChannel(__unsafe_unretained AELevelsAnalyzer * THIS, const AudioBufferList * buffer, int channel, UInt32 numberFrames) {
    AELevelsAnalyzerMixAndAnalyzeChannel(THIS, buffer, channel, numberFrames, YES);
}

static void AELevelsAnalyzerMixAndAnalyzeChannel(__unsafe_unretained AELevelsAnalyzer * THIS, const AudioBufferList * buffer, int channel, UInt32 numberFrames, BOOL first) {
    AESeconds now = AECurrentTimeInSeconds();
    if ( now-THIS->_lastQuery > kQueryTimeout ) {
        memset(&THIS->_sumSquareBuffer, 0, sizeof(THIS->_sumSquareBuffer));
        THIS->_sumSquareN = 0;
        THIS->_sumSquareAccumulator = 0;
        THIS->_peak = 0;
        return;
    }
    
    float max = 0;
    float sumOfSquares = 0;
    if ( numberFrames > 0 && buffer ) {
        for ( int i=(channel == -1 ? 0 : channel); i<buffer->mNumberBuffers && (channel == -1 || i<channel+1); i++ ) {
            // Calculate max sample
            float bufferMax = max;
            vDSP_maxmgv((float*)buffer->mBuffers[i].mData, 1, &bufferMax, numberFrames);
            if ( bufferMax > max ) {
                max = bufferMax;
            }
            
            if ( bufferMax > 0 ) {
                // Calculate sum of squares (max over all channels)
                float channelSumSquare = 0;
                vDSP_svesq((float*)buffer->mBuffers[i].mData, 1, &channelSumSquare, numberFrames);
                sumOfSquares = MAX(channelSumSquare, sumOfSquares);
            }
        }
    }
    
    AESeconds sinceLastAnalysis = now-THIS->_lastAnalysis;
    THIS->_lastAnalysis = now;

    // Calculate peak, with dropoff
    if ( max >= THIS->_peak ) {
        THIS->_lastPeak = now;
        THIS->_peak = max;
    } else if ( now-THIS->_lastPeak > kPeakHoldInterval ) {
        THIS->_peak = (1.0-(sinceLastAnalysis*kPeakFalloffPerSecond)) * THIS->_peak;
    }
    
    // Calculate running RMS
    if ( numberFrames == 0 || sinceLastAnalysis > kTimeoutAnalysisFalloffInterval ) {
        memset(&THIS->_sumSquareBuffer, 0, sizeof(THIS->_sumSquareBuffer));
        THIS->_sumSquareAccumulator = 0;
        THIS->_sumSquareN = 0;
    }
    if ( numberFrames == 0 ) {
        THIS->_meanSumSquare = 0;
        return;
    }
    
    if ( first ) {
        int rmsBufferBlockCount = MIN(kRMSBufferBlockCountMax, (kRMSWindowFrameCount / numberFrames));
        THIS->_sumSquareBufferHead = (THIS->_sumSquareBufferHead + 1) % rmsBufferBlockCount;
        THIS->_sumSquareN += numberFrames - THIS->_sumSquareBuffer[THIS->_sumSquareBufferHead].n;
    }
    THIS->_sumSquareAccumulator += sumOfSquares - (first ? THIS->_sumSquareBuffer[THIS->_sumSquareBufferHead].sumSquare : 0);
    THIS->_sumSquareBuffer[THIS->_sumSquareBufferHead].sumSquare = sumOfSquares + (first ? 0 : THIS->_sumSquareBuffer[THIS->_sumSquareBufferHead].sumSquare);
    THIS->_sumSquareBuffer[THIS->_sumSquareBufferHead].n = numberFrames;
    THIS->_meanSumSquare = THIS->_sumSquareAccumulator / THIS->_sumSquareN;
}

- (double)peak {
    _lastQuery = AECurrentTimeInSeconds();
    AESeconds sinceLast = _lastQuery-_lastAnalysis;
    if ( sinceLast < kAnalysisTimeout ) {
        return AEDSPRatioToDecibels(_peak);
    } else if ( sinceLast > kAnalysisTimeout+kTimeoutAnalysisFalloffInterval ) {
        return -INFINITY;
    } else {
        return AEDSPRatioToDecibels(_peak * (1.0 - (sinceLast / kTimeoutAnalysisFalloffInterval)));
    }
}

- (double)average {
    _lastQuery = AECurrentTimeInSeconds();
    AESeconds sinceLast = _lastQuery-_lastAnalysis;
    if ( sinceLast < kAnalysisTimeout ) {
        return AEDSPRatioToDecibels(sqrt(_meanSumSquare));
    } else if ( sinceLast > kAnalysisTimeout+kTimeoutAnalysisFalloffInterval ) {
        return -INFINITY;
    } else {
        return AEDSPRatioToDecibels(sqrt(_meanSumSquare) * (1.0 - (sinceLast / kTimeoutAnalysisFalloffInterval)));
    }
}

@end
