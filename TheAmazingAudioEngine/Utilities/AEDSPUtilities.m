//
//  AEDSPUtilities.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 1/04/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import "AEDSPUtilities.h"
#import <Accelerate/Accelerate.h>

static const UInt32 kMaxFramesPerSlice = 4096;
static const UInt32 kGainSmoothingRampDuration = 128;
static const float kGainSmoothingRampStep = 1.0 / kGainSmoothingRampDuration;
static const float kSmoothGainThreshold = kGainSmoothingRampStep;
static const UInt32 kMinRampDurationForPowerCurve = 8192;
static const float kPowerCurvePower = 3.0;

void AEDSPApplyGain(const AudioBufferList * bufferList, float gain, UInt32 frames) {
    for ( int i=0; i < bufferList->mNumberBuffers; i++ ) {
        if ( gain < FLT_EPSILON ) {
            vDSP_vclr(bufferList->mBuffers[i].mData, 1, frames);
        } else {
            vDSP_vsmul(bufferList->mBuffers[i].mData, 1, &gain, bufferList->mBuffers[i].mData, 1, frames);
        }
    }
}

void AEDSPApplyRamp(const AudioBufferList * bufferList, float * start, float step, UInt32 frames) {
    if ( bufferList->mNumberBuffers == 2 ) {
        // Stereo buffer: use stereo utility
        vDSP_vrampmul2(bufferList->mBuffers[0].mData, bufferList->mBuffers[1].mData, 1, start, &step,
                       bufferList->mBuffers[0].mData, bufferList->mBuffers[1].mData, 1, frames);
    } else {
        // Mono or multi-channel buffer: treat channel by channel
        float s = *start;
        for ( int i=0; i < bufferList->mNumberBuffers; i++ ) {
            s = *start;
            vDSP_vrampmul(bufferList->mBuffers[i].mData, 1, &s, &step, bufferList->mBuffers[i].mData, 1, frames);
        }
        *start = s;
    }
}

void AEDSPApplyEqualPowerRamp(const AudioBufferList * bufferList, float * start, float step, UInt32 frames, float * scratch) {
    static float __staticBuffer[kMaxFramesPerSlice];
    if ( !scratch ) scratch = __staticBuffer;
    
    // Create envelope
    float startRadians = *start * M_PI_2;
    float stepRadians = step * M_PI_2;
    vDSP_vramp(&startRadians, &stepRadians, scratch, 1, frames);
    int frameCount = frames;
    vvsinf(scratch, scratch, &frameCount);
    *start += frames * step;
    
    // Apply envelope to each buffer
    for ( int i=0; i<bufferList->mNumberBuffers; i++ ) {
        vDSP_vmul(bufferList->mBuffers[i].mData, 1, scratch, 1, bufferList->mBuffers[i].mData, 1, frames);
    }
}

void AEDSPApplyGainSmoothed(const AudioBufferList * bufferList, float targetGain, float * currentGain, UInt32 frames) {
    AEDSPApplyGainWithRamp(bufferList, targetGain, currentGain, frames, 0);
}

void AEDSPApplyGainWithRamp(const AudioBufferList * bufferList, float targetGain, float * currentGain, UInt32 frames,
                                    UInt32 rampDuration) {
    
    float diff = fabsf(targetGain - *currentGain);
    if ( diff > kSmoothGainThreshold ) {
        // Need to apply ramp
        UInt32 duration = MIN(diff * (rampDuration ? rampDuration : kGainSmoothingRampDuration), frames);
        float step = (targetGain > *currentGain ? 1.0 : -1.0) * (rampDuration ? 1.0/rampDuration : kGainSmoothingRampStep);
        
        if ( rampDuration > kMinRampDurationForPowerCurve ) {
            // We're going to use a power function curve for more linear-sounding transitions.
            // Invert power function to get current t
            float t = powf(*currentGain, 1.0/kPowerCurvePower);
            
            // Calculate target for this segment
            float localTarget = powf(t + (step * duration), kPowerCurvePower);
            
            // Calculate step
            step = (localTarget - *currentGain) / (float)duration;
        }
        
        AEDSPApplyRamp(bufferList, currentGain, step, duration);
        
        if ( duration < frames && fabsf(targetGain - 1.0f) > FLT_EPSILON ) {
            // Apply constant gain, now, with offset
            *currentGain = targetGain;
            for ( int i=0; i < bufferList->mNumberBuffers; i++ ) {
                vDSP_vsmul((float*)bufferList->mBuffers[i].mData + duration, 1, &targetGain,
                           (float*)bufferList->mBuffers[i].mData + duration, 1, frames - duration);
            }
        }
    } else {
        *currentGain = targetGain;
        
        if ( fabsf(targetGain - 1.0f) > FLT_EPSILON ) {
            // Just apply gain
            AEDSPApplyGain(bufferList, targetGain, frames);
        }
    }
}

void AEDSPApplyGainSmoothedMono(float * buffer, float targetGain, float * currentGain, UInt32 frames) {
    float diff = fabsf(targetGain - *currentGain);
    if ( diff > kSmoothGainThreshold ) {
        // Need to apply ramp
        UInt32 rampDuration = MIN(diff * kGainSmoothingRampDuration, frames);
        float step = targetGain > *currentGain ? kGainSmoothingRampStep : -kGainSmoothingRampStep;
        vDSP_vrampmul(buffer, 1, currentGain, &step, buffer, 1, rampDuration);
        
        if ( rampDuration < frames && fabsf(targetGain - 1.0f) > FLT_EPSILON ) {
            // Apply constant gain, now, with offset
            vDSP_vsmul(buffer + rampDuration, 1, &targetGain, buffer + rampDuration, 1, frames - rampDuration);
        }
    } else if ( targetGain < FLT_EPSILON ) {
        // Zero
        vDSP_vclr(buffer, 1, frames);
    } else if ( fabsf(targetGain - 1.0f) > FLT_EPSILON ) {
        // Just apply gain
        vDSP_vsmul(buffer, 1, &targetGain, buffer, 1, frames);
    }
}

void AEDSPApplyVolumeAndBalance(const AudioBufferList * bufferList, float targetVolume, float * currentVolume,
                                float targetBalance, float * currentBalance, UInt32 frames) {
    BOOL hasCurrentVol = currentVolume != NULL;
    BOOL hasCurrentBal = currentBalance != NULL;
    if ( !hasCurrentVol ) currentVolume = &targetVolume;
    if ( !hasCurrentBal ) currentBalance = &targetBalance;
    
    if ( bufferList->mNumberBuffers == 2 ) {
        if ( fabsf(targetBalance) < FLT_EPSILON && fabsf(*currentBalance) < FLT_EPSILON ) {
            // Balance is centered, can treat both channels the same
            AEDSPApplyGainSmoothed(bufferList, targetVolume, currentVolume, frames);
        } else {
            // Balance non-centered, need to apply different gains to each channel
            float targetGains[] = {
                targetVolume * (targetBalance <= 0.0 ? 1.0 : 1.0-targetBalance),
                targetVolume * (targetBalance >= 0.0 ? 1.0 : 1.0+targetBalance) };
            float currentGains[] = {
                *currentVolume * (*currentBalance <= 0.0 ? 1.0 : 1.0-*currentBalance),
                *currentVolume * (*currentBalance >= 0.0 ? 1.0 : 1.0+*currentBalance) };
            
            AEDSPApplyGainSmoothedMono(bufferList->mBuffers[0].mData, targetGains[0], &currentGains[0], frames);
            AEDSPApplyGainSmoothedMono(bufferList->mBuffers[1].mData, targetGains[1], &currentGains[1], frames);
            
            if ( hasCurrentVol ) {
                *currentVolume = fabsf(*currentVolume-targetVolume) < FLT_EPSILON ? targetVolume :
                    *currentVolume < targetVolume ? MIN(targetVolume, *currentVolume + kGainSmoothingRampStep*frames) :
                    /* *currentVolume > targetVolume */ MAX(targetVolume, *currentVolume - kGainSmoothingRampStep*frames);
            }
            if ( hasCurrentBal ) {
                *currentBalance = fabsf(*currentBalance-targetBalance) < FLT_EPSILON ? targetBalance :
                    *currentBalance < targetBalance ? MIN(targetBalance, *currentBalance + 2*kGainSmoothingRampStep*frames) :
                    /* *currentBalance > targetBalance */ MAX(targetBalance, *currentBalance - 2*kGainSmoothingRampStep*frames);
            }
        }
    } else {
        // Mono or non-stereo buffer only - just apply volume
        AEDSPApplyGainSmoothed(bufferList, targetVolume, currentVolume, frames);
    }
}

void AEDSPMix(const AudioBufferList * abl1, const AudioBufferList * abl2, float gain1, float gain2,
              BOOL monoToStereo, UInt32 frames, const AudioBufferList * output) {
    
    if ( !frames ) frames = output->mBuffers[0].mDataByteSize / sizeof(float);
    
    if ( gain2 != 1.0f && gain1 == 1.0f ) {
        // Swap around, for efficiency
        const AudioBufferList * atmp = abl2;
        abl2 = abl1;
        abl1 = atmp;
        float gtmp = gain2;
        gain2 = gain1;
        gain1 = gtmp;
    }
    
    if ( gain2 != 1.0 ) {
        // Pre-apply gain to second abl
        AEDSPApplyGain(abl2, gain2, frames);
    }
    
    // Mix
    for ( int i=0; i < output->mNumberBuffers; i++ ) {
        int abl1Buffer =
            i < abl1->mNumberBuffers ? i :
            monoToStereo && abl1->mNumberBuffers == 1 && output->mNumberBuffers == 2 ? 0 :
            -1;
        int abl2Buffer =
            i < abl2->mNumberBuffers ? i :
            monoToStereo && abl2->mNumberBuffers == 1 && output->mNumberBuffers == 2 ? 0 :
            -1;
        
        if ( abl1Buffer != -1 && abl2Buffer != -1 ) {
            // Mix channels in common
            if ( gain1 != 1.0 ) {
                vDSP_vsma(abl1->mBuffers[abl1Buffer].mData, 1, &gain1,
                          abl2->mBuffers[abl2Buffer].mData, 1,
                          output->mBuffers[i].mData, 1, frames);
            } else {
                vDSP_vadd(abl1->mBuffers[abl1Buffer].mData, 1,
                          abl2->mBuffers[abl2Buffer].mData, 1,
                          output->mBuffers[i].mData, 1, frames);
            }
        } else if ( abl1Buffer != -1 && (output != abl1 || gain1 != 1.0) ) {
            if ( gain1 == 1.0 ) {
                memcpy(output->mBuffers[i].mData, abl1->mBuffers[abl1Buffer].mData, output->mBuffers[i].mDataByteSize);
            } else {
                vDSP_vsmul(abl1->mBuffers[abl1Buffer].mData, 1, &gain1,
                           output->mBuffers[i].mData, 1, frames);
            }
        } else if ( abl2Buffer != -1 && (output != abl2 || gain2 != 1.0) ) {
            if ( gain2 == 1.0 ) {
                memcpy(output->mBuffers[i].mData, abl2->mBuffers[abl2Buffer].mData, output->mBuffers[i].mDataByteSize);
            } else {
                vDSP_vsmul(abl2->mBuffers[abl2Buffer].mData, 1, &gain2,
                           output->mBuffers[i].mData, 1, frames);
            }
        }
    }
    
    if ( output->mNumberBuffers == 1 ) {
        // If output is mono and abl1 has more channels, mix them all in
        if ( abl1->mNumberBuffers > 1 ) {
            for ( int i=1; i<abl1->mNumberBuffers; i++ ) {
                if ( gain1 != 1.0 ) {
                    vDSP_vsma((float*)abl1->mBuffers[i].mData, 1, &gain1,
                              (float*)output->mBuffers[0].mData, 1,
                              (float*)output->mBuffers[0].mData, 1, frames);
                } else {
                    vDSP_vadd((float*)abl1->mBuffers[i].mData, 1,
                              (float*)output->mBuffers[0].mData, 1,
                              (float*)output->mBuffers[0].mData, 1, frames);
                }
            }
        }
        
        // If output is mono and abl2 has more channels, mix them all in
        if ( abl2->mNumberBuffers > 1 ) {
            for ( int i=1; i<abl2->mNumberBuffers; i++ ) {
                vDSP_vadd((float*)abl2->mBuffers[i].mData, 1,
                          (float*)output->mBuffers[0].mData, 1,
                          (float*)output->mBuffers[0].mData, 1, frames);
            }
        }
    }
}

void AEDSPMixMono(const float * buffer1, const float * buffer2, float gain1, float gain2, UInt32 frames, float * output) {
    if ( gain2 != 1.0f && gain1 == 1.0f ) {
        // Swap buffers around, for efficiency
        const float * tmpb = buffer2;
        buffer2 = buffer1;
        buffer1 = tmpb;
        const float tmpg = gain2;
        gain2 = gain1;
        gain1 = tmpg;
    }
    
    if ( gain2 != 1.0f) {
        // Pre-apply gain to second buffer
        vDSP_vsmul(buffer2, 1, &gain2, output, 1, frames);
        buffer2 = output;
    }
    
    // Mix
    if ( gain1 != 1.0f ) {
        vDSP_vsma(buffer1, 1, &gain1, buffer2, 1, output, 1, frames);
    } else {
        vDSP_vadd(buffer1, 1, buffer2, 1, output, 1, frames);
    }
}

void AEDSPCrossfade(const AudioBufferList * a, const AudioBufferList * b, const AudioBufferList * target, UInt32 frames) {
    assert(a->mNumberBuffers == b->mNumberBuffers && b->mNumberBuffers == target->mNumberBuffers);
    for ( int i=0; i<a->mNumberBuffers; i++ ) {
        vDSP_vtmerg(a->mBuffers[i].mData, 1, b->mBuffers[i].mData, 1, target->mBuffers[i].mData, 1, frames);
    }
}

#pragma mark - FFT Convolution

typedef struct AEDSPFFTConvolution_t {
    int length;
    vDSP_DFT_Setup forward;
    vDSP_DFT_Setup inverse;
    float * inputR;
    float * inputI;
    float * filterR;
    float * filterI;
    int filterLength;
    float * overflow;
    int overflowLength;
    float * temp;
    AEDSPFFTConvolutionOperation operation;
} AEDSPFFTConvolution;

int AEDSPFFTConvolutionCalculateFFTLength(int length) {
    // Select FFT length. Length must be power of 2, or f * 2^n, where f is 3, 5, or 15 and n is at least 4.
    int fftLength = pow(2, ceil(log2(length)));
    if ( fftLength != length ) {
        // See if there's an f * 2^n form that's less than the next highest power of two
        const int fs[] = {3, 5, 15};
        for ( int i=0; i<sizeof(fs)/sizeof(fs[0]); i++ ) {
            int N = (int)ceilf(log2f(length/(float)fs[i]));
            if ( N < 4 ) continue;
            int l = fs[i] * pow(2,N);
            if ( l > fftLength ) {
                break;
            }
            if ( l >= length ) {
                fftLength = l;
                break;
            }
        }
    }
    return fftLength;
}

AEDSPFFTConvolution * AEDSPFFTConvolutionInit(int length) {
    int fftLength = AEDSPFFTConvolutionCalculateFFTLength(length);
    
    AEDSPFFTConvolution * setup = calloc(1, sizeof(AEDSPFFTConvolution));
    setup->length = fftLength;
    setup->inputR = malloc(sizeof(float) * fftLength/2);
    setup->inputI = malloc(sizeof(float) * fftLength/2);
    setup->filterR = malloc(sizeof(float) * fftLength/2);
    setup->filterI = malloc(sizeof(float) * fftLength/2);
    setup->overflow = malloc(sizeof(float) * fftLength);
    setup->temp = malloc(sizeof(float) * fftLength);
    setup->forward = vDSP_DFT_zrop_CreateSetup(0, fftLength, vDSP_DFT_FORWARD);
    setup->inverse = vDSP_DFT_zrop_CreateSetup(setup->forward, fftLength, vDSP_DFT_INVERSE);
    return setup;
}

void AEDSPFFTConvolutionDealloc(AEDSPFFTConvolution * setup) {
    free(setup->inputR);
    free(setup->inputI);
    free(setup->filterR);
    free(setup->filterI);
    free(setup->overflow);
    free(setup->temp);
    vDSP_DFT_DestroySetup(setup->forward);
    vDSP_DFT_DestroySetup(setup->inverse);
    free(setup);
}

inline static void AEDSPFFTConvolutionInterleaveAndPad(float * buffer, float * real, float * imag, int length, int fftLength, BOOL reverse) {
    
    if ( reverse ) {
        DSPSplitComplex split = { .realp = imag, .imagp = real };
        vDSP_ctoz((DSPComplex *)(buffer + length - 2), -2, &split, 1, length/2);
    } else {
        DSPSplitComplex split = { .realp = real, .imagp = imag };
        vDSP_ctoz((DSPComplex *)buffer, 2, &split, 1, length/2);
    }
    
    if ( length < fftLength ) {
        int padding = (fftLength/2)-(length/2);
        vDSP_vclr(real+(length/2), 1, padding);
        vDSP_vclr(imag+(length/2), 1, padding);
        if ( length%2 ) {
            if ( reverse ) {
                real[(length/2)] = buffer[0];
            } else {
                real[(length/2)] = buffer[length-1];
            }
        }
    }
}

void AEDSPFFTConvolutionPrepareContinuous(AEDSPFFTConvolution * setup, float * filter, int filterLength, AEDSPFFTConvolutionOperation operation) {
    assert(filterLength < setup->length);
    setup->operation = operation;
    setup->filterLength = filterLength;
    
    // Perform forward FFT of filter signal
    AEDSPFFTConvolutionInterleaveAndPad(filter, setup->filterR, setup->filterI, filterLength, setup->length, operation == AEDSPFFTConvolutionOperation_Correlation || operation == AEDSPFFTConvolutionOperation_CorrelationFull);
    vDSP_DFT_Execute(setup->forward, setup->filterR, setup->filterI, setup->filterR, setup->filterI);
}

void AEDSPFFTConvolutionReset(AEDSPFFTConvolution * setup) {
    setup->overflowLength = 0;
}
    
static void _AEDSPFFTConvolutionExecute(AEDSPFFTConvolution * setup, float * input, int inputLength, float * output, int outputLength, AEDSPFFTConvolutionOperation operation, BOOL continuous) {
    int filterLength = setup->filterLength;
    BOOL overlapAdd = continuous || inputLength > setup->length - filterLength + 1;
    
    int outputElementsToSkip = 0;
    if ( operation == AEDSPFFTConvolutionOperation_Convolution || operation == AEDSPFFTConvolutionOperation_Correlation ) {
        // Skip filterLength-1 frames from start
        outputElementsToSkip = filterLength - 1;
    }
    
    while ( inputLength > 0 ) {
        int blockLength = overlapAdd ? MIN(setup->length - filterLength + 1, inputLength) : inputLength;
        
        // Perform forward FFT of input signal
        AEDSPFFTConvolutionInterleaveAndPad(input, setup->inputR, setup->inputI, blockLength, setup->length, NO);
        vDSP_DFT_Execute(setup->forward, setup->inputR, setup->inputI, setup->inputR, setup->inputI);
        
        // Multiply signals. The Nyquist value is stored in imag[0], so treat that differently
        DSPSplitComplex inputSplit = { .realp = setup->inputR, .imagp = setup->inputI };
        DSPSplitComplex filterSplit = { .realp = setup->filterR, .imagp = setup->filterI };
        float multipliedNyquist = setup->inputI[0] * setup->filterI[0];
        float priorFilterNyquist = setup->filterI[0];
        setup->inputI[0] = setup->filterI[0] = 0;
        vDSP_zvmul(&inputSplit, 1, &filterSplit, 1, &inputSplit, 1, (setup->length/2), 1);
        setup->inputI[0] = multipliedNyquist;
        setup->filterI[0] = priorFilterNyquist;
        
        // Perform inverse FFT
        vDSP_DFT_Execute(setup->inverse, setup->inputR, setup->inputI, setup->inputR, setup->inputI);

        // De-interleave to output
        vDSP_ztoc(&inputSplit, 1, (DSPComplex *)setup->temp, 2, setup->length/2);
        
        // Scale according to API convention (undo x2 scale for each forward transform, and xN scale for inverse)
        float scale = 1.0 / (2*2*setup->length);
        vDSP_vsmul(setup->temp, 1, &scale, setup->temp, 1, setup->length);
        
        if ( setup->overflowLength > 0 ) {
            // Add overflow from last block
            vDSP_vadd(setup->temp, 1, setup->overflow, 1, setup->temp, 1, setup->overflowLength);
        }
        
        // Save overflow
        if ( overlapAdd ) {
            setup->overflowLength = filterLength - 1;
            memcpy(setup->overflow, setup->temp + blockLength, sizeof(float) * setup->overflowLength);
        }
        
        // Save output
        int blockOutputLength = overlapAdd ? blockLength : blockLength + filterLength - 1;
        int skippedElements = MIN(outputElementsToSkip, blockOutputLength);
        blockOutputLength = MIN(outputLength, blockOutputLength - skippedElements);
        memcpy(output, setup->temp + skippedElements, sizeof(float) * blockOutputLength);
        
        // Advance
        inputLength -= blockLength;
        input += blockLength;
        outputLength -= blockOutputLength;
        output += blockOutputLength;
        outputElementsToSkip -= skippedElements;
    }
    
    if ( outputLength > 0 && setup->overflowLength > 0 ) {
        int length = MIN(outputLength, setup->overflowLength);
        int skippedElements = MIN(outputElementsToSkip, length);
        length -= skippedElements;
        memcpy(output, setup->overflow + skippedElements, length * sizeof(float));
        output += length;
        outputLength -= length;
        setup->overflowLength -= length+skippedElements;
    }
    
    if ( outputLength > 0 ) {
        memset(output, 0, outputLength * sizeof(float));
    }
}

void AEDSPFFTConvolutionExecuteContinuous(AEDSPFFTConvolution * setup, float * input, int inputLength, float * output, int outputLength) {
    _AEDSPFFTConvolutionExecute(setup, input, inputLength, output, outputLength, setup->operation, YES);
}

void AEDSPFFTConvolutionExecute(AEDSPFFTConvolution * setup, float * input, int inputLength, float * filter, int filterLength, float * output, int outputLength, AEDSPFFTConvolutionOperation operation) {
    if ( filter ) {
        AEDSPFFTConvolutionPrepareContinuous(setup, filter, filterLength, operation);
    }
    setup->overflowLength = 0;
    _AEDSPFFTConvolutionExecute(setup, input, inputLength, output, outputLength, operation, NO);
    setup->overflowLength = 0;
}


int AEDSPFindPeaksInDistribution(float * distribution, int start, int end, float leadingDelta, float trailingDelta, int minimumSeparation, BOOL sort, int * peaks, int maxPeaks) {
    int bufferSize = 128;
    struct { int index; float score; } * results = sort ? malloc(sizeof(*results) * bufferSize) : NULL;
    int peakCount = 0;
    
    BOOL seekMax = YES;
    int step = end > start ? 1 : -1;
    float max = -INFINITY, min = INFINITY;
    float lastValley = -INFINITY;
    int lastPeak = -1;
    int maxI = 0, minI = 0;
    for ( int i=start; step > 0 ? i<end : i >= end; i += step ) {
        float sample = distribution[i];
        
        if ( sample > max ) {
            max = sample;
            maxI = i;
        }
        if ( sample < min ) {
            min = sample;
            minI = i;
        }
        
        if ( seekMax ) {
            if ( sample < max-trailingDelta && lastValley < max-leadingDelta ) {
                if ( !minimumSeparation || lastPeak == -1 || i-lastPeak >= minimumSeparation ) {
                    if ( sort && peakCount >= bufferSize ) {
                        bufferSize += 128;
                        results = realloc(results, sizeof(*results)*bufferSize);
                    }
                    
                    if ( sort ) {
                        results[peakCount].index = maxI;
                        results[peakCount].score = max;
                    } else {
                        peaks[peakCount] = maxI;
                    }
                    
                    peakCount++;
                    
                    if ( peakCount == maxPeaks && !sort ) {
                        break;
                    }
                }
                
                min = sample;
                minI = i;
                seekMax = NO;
                lastPeak = i;
            }
        } else {
            if ( sample > min+leadingDelta ) {
                max = sample;
                maxI = i;
                lastValley = min;
                seekMax = YES;
            }
        }
    }
    
    if ( sort ) {
        qsort_b(results, peakCount, sizeof(*results), ^(const void * elem1, const void * elem2) {
            const typeof(*results) * e1 = elem1;
            const typeof(*results) * e2 = elem2;
            float diff = e1->score - e2->score;
            return diff < 0 ? 1 : diff > 0 ? -1 : 0;
        });
        
        for ( int i=0; i<maxPeaks && i<peakCount; i++ ) {
            peaks[i] = results[i].index;
        }
        
        free(results);
    }
    
    return MIN(maxPeaks, peakCount);
}
