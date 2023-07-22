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
    double _sumSquareAccumulator;
    int _sumSquareN;
    float _meanSumSquare;
    BOOL _nextBufferIsFirst;
}
@end

@implementation AELevelsAnalyzer
@dynamic peak, average;

- (instancetype)init {
    if ( !(self = [super init]) ) return nil;
    _gain = 1;
    return self;
}

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
    first |= THIS->_nextBufferIsFirst;
    THIS->_nextBufferIsFirst = NO;
    
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

    max *= THIS->_gain;
    sumOfSquares *= THIS->_gain*THIS->_gain;
    
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
    
    int rmsBufferBlockCount = MIN(kRMSBufferBlockCountMax, (kRMSWindowFrameCount / numberFrames));
    if ( first ) {
        THIS->_sumSquareBufferHead = (THIS->_sumSquareBufferHead + 1) % rmsBufferBlockCount;
        THIS->_sumSquareN += numberFrames - THIS->_sumSquareBuffer[THIS->_sumSquareBufferHead].n;
    }
    THIS->_sumSquareAccumulator += sumOfSquares - (first ? THIS->_sumSquareBuffer[THIS->_sumSquareBufferHead].sumSquare : 0);
    if ( THIS->_sumSquareAccumulator < 0 ) THIS->_sumSquareAccumulator = 0; // Deal with floating-point errors causing negative value
    THIS->_sumSquareBuffer[THIS->_sumSquareBufferHead].sumSquare = sumOfSquares + (first ? 0 : THIS->_sumSquareBuffer[THIS->_sumSquareBufferHead].sumSquare);
    THIS->_sumSquareBuffer[THIS->_sumSquareBufferHead].n = numberFrames;
    
    if ( first && THIS->_sumSquareBufferHead == 0 ) {
        // Periodically recalculate accumulator, to remove aggregate floating-point errors
        float acc = 0;
        for ( int i=0; i<rmsBufferBlockCount; i++ ) acc += THIS->_sumSquareBuffer[i].sumSquare;
        THIS->_sumSquareAccumulator = acc;
    }
    
    THIS->_meanSumSquare = THIS->_sumSquareAccumulator / THIS->_sumSquareN;
}

void AELevelsAnalyzerSetNextBufferIsFirst(__unsafe_unretained AELevelsAnalyzer * THIS) {
    THIS->_nextBufferIsFirst = YES;
}

double AELevelsAnalyzerGetPeak(__unsafe_unretained AELevelsAnalyzer * THIS) {
    THIS->_lastQuery = AECurrentTimeInSeconds();
    AESeconds sinceLast = THIS->_lastQuery-THIS->_lastAnalysis;
    if ( sinceLast < kAnalysisTimeout ) {
        return AEDSPRatioToDecibels(THIS->_peak);
    } else if ( sinceLast > kAnalysisTimeout+kTimeoutAnalysisFalloffInterval ) {
        return -INFINITY;
    } else {
        return AEDSPRatioToDecibels(THIS->_peak * (1.0 - ((sinceLast-kAnalysisTimeout) / kTimeoutAnalysisFalloffInterval)));
    }
}

double AELevelsAnalyzerGetAverage(__unsafe_unretained AELevelsAnalyzer * THIS) {
    THIS->_lastQuery = AECurrentTimeInSeconds();
    AESeconds sinceLast = THIS->_lastQuery-THIS->_lastAnalysis;
    if ( sinceLast < kAnalysisTimeout ) {
        return AEDSPRatioToDecibels(sqrt(THIS->_meanSumSquare));
    } else if ( sinceLast > kAnalysisTimeout+kTimeoutAnalysisFalloffInterval ) {
        return -INFINITY;
    } else {
        return AEDSPRatioToDecibels(sqrt(THIS->_meanSumSquare) * (1.0 - ((sinceLast-kAnalysisTimeout) / kTimeoutAnalysisFalloffInterval)));
    }
}

- (double)peak {
    return AELevelsAnalyzerGetPeak(self);
}

- (double)average {
    return AELevelsAnalyzerGetAverage(self);
}

@end


#pragma mark -



@interface AEStereoLevelsAnalyzer ()
@property (nonatomic, strong, readwrite) AELevelsAnalyzer * left;
@property (nonatomic, strong, readwrite) AELevelsAnalyzer * right;
@end

@implementation AEStereoLevelsAnalyzer

- (instancetype)init {
    if ( !(self = [super init]) ) return nil;
    _gain = 1;
    self.left = [AELevelsAnalyzer new];
    self.right = [AELevelsAnalyzer new];
    return self;
}

void AEStereoLevelsAnalyzerAnalyzeBuffer(__unsafe_unretained AEStereoLevelsAnalyzer * THIS, const AudioBufferList * buffer, UInt32 numberFrames) {
    AELevelsAnalyzerAnalyzeBufferChannel(THIS->_left, buffer, 0, numberFrames);
    AELevelsAnalyzerAnalyzeBufferChannel(THIS->_right, buffer, !buffer || buffer->mNumberBuffers < 2 ? 0 : 1, numberFrames);
}

void AEStereoLevelsAnalyzerMixAndAnalyzeBuffer(__unsafe_unretained AEStereoLevelsAnalyzer * THIS, const AudioBufferList * buffer, UInt32 numberFrames, BOOL first) {
    AELevelsAnalyzerMixAndAnalyzeChannel(THIS->_left, buffer, 0, numberFrames, first);
    AELevelsAnalyzerMixAndAnalyzeChannel(THIS->_right, buffer, !buffer || buffer->mNumberBuffers < 2 ? 0 : 1, numberFrames, first);
}

void AEStereoLevelsAnalyzerSetNextBufferIsFirst(__unsafe_unretained AEStereoLevelsAnalyzer * THIS) {
    AELevelsAnalyzerSetNextBufferIsFirst(THIS->_left);
    AELevelsAnalyzerSetNextBufferIsFirst(THIS->_right);
}

- (void)setGain:(double)gain {
    _gain = gain;
    self.left.gain = gain;
    self.right.gain = gain;
}

@end
