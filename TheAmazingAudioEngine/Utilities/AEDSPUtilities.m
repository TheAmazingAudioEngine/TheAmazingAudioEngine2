//
//  AEDSPUtilities.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 1/04/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import "AEDSPUtilities.h"
@import Accelerate;

static const UInt32 kMaxFramesPerSlice = 4096;
static const UInt32 kGainSmoothingRampDuration = 128;
static const float kGainSmoothingRampStep = 1.0 / kGainSmoothingRampDuration;
static const float kSmoothGainThreshold = kGainSmoothingRampStep;

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
    float diff = fabsf(targetGain - *currentGain);
    if ( diff > kSmoothGainThreshold ) {
        // Need to apply ramp
        UInt32 rampDuration = MIN(diff * kGainSmoothingRampDuration, frames);
        float step = targetGain > *currentGain ? kGainSmoothingRampStep : -kGainSmoothingRampStep;
        AEDSPApplyRamp(bufferList, currentGain, step, rampDuration);
        
        if ( rampDuration < frames && targetGain < 1.0-FLT_EPSILON ) {
            // Apply constant gain, now, with offset
            for ( int i=0; i < bufferList->mNumberBuffers; i++ ) {
                vDSP_vsmul((float*)bufferList->mBuffers[i].mData + rampDuration, 1, &targetGain,
                           (float*)bufferList->mBuffers[i].mData + rampDuration, 1, frames - rampDuration);
            }
        }
    } else if ( targetGain < 1.0-FLT_EPSILON ) {
        // Just apply gain
        AEDSPApplyGain(bufferList, targetGain, frames);
    }
}

void AEDSPApplyGainSmoothedMono(float * buffer, float targetGain, float * currentGain, UInt32 frames) {
    float diff = fabsf(targetGain - *currentGain);
    if ( diff > kSmoothGainThreshold ) {
        // Need to apply ramp
        UInt32 rampDuration = MIN(diff * kGainSmoothingRampDuration, frames);
        float step = targetGain > *currentGain ? kGainSmoothingRampStep : -kGainSmoothingRampStep;
        vDSP_vrampmul(buffer, 1, currentGain, &step, buffer, 1, rampDuration);
        
        if ( rampDuration < frames && targetGain < 1.0-FLT_EPSILON ) {
            // Apply constant gain, now, with offset
            vDSP_vsmul(buffer + rampDuration, 1, &targetGain, buffer + rampDuration, 1, frames - rampDuration);
        }
    } else if ( targetGain < FLT_EPSILON ) {
        // Zero
        vDSP_vclr(buffer, 1, frames);
    } else if ( targetGain < 1.0-FLT_EPSILON ) {
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
        vDSP_vsmul(buffer2, 1, &gain2, buffer2, 1, frames);
    }
    
    // Mix
    if ( gain1 != 1.0f ) {
        vDSP_vsma(buffer1, 1, &gain1, buffer2, 1, output, 1, frames);
    } else {
        vDSP_vadd(buffer1, 1, buffer2, 1, output, 1, frames);
    }
}
