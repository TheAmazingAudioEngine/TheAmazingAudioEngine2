//
//  AEDSPUtilities.h
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 1/04/2016.
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

#ifdef __cplusplus
extern "C" {
#endif

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "AEAudioBufferListUtilities.h"

/*!
 * Scale values in a buffer list by some gain value
 *
 * @param bufferList Audio buffer list, in non-interleaved float format
 * @param gain Gain amount (power ratio)
 * @param frames Length of buffer in frames
 */
void AEDSPApplyGain(const AudioBufferList * bufferList, float gain, UInt32 frames);

/*!
 * Apply a ramp to values in a buffer list
 *
 * @param bufferList Audio buffer list, in non-interleaved float format
 * @param start Starting gain (power ratio) on input; final gain value on output
 * @param step Amount per frame to advance gain
 * @param frames Length of buffer in frames
 */
void AEDSPApplyRamp(const AudioBufferList * bufferList, float * start, float step, UInt32 frames);

/*!
 * Apply an equal-power ramp to values in a buffer list
 *
 *  This uses a quarter-cycle cosine ramp envelope to preserve the power level, useful when 
 *  crossfading two signals without causing a bump in gain in the middle of the fade.
 *
 * @param bufferList Audio buffer list, in non-interleaved float format
 * @param start Starting gain (power ratio) on input; final gain value on output
 * @param step Amount per frame to advance gain
 * @param frames Length of buffer in frames
 * @param scratch A scratch buffer to use, or NULL to use an internal buffer. Not thread-safe if the latter is used.
 */
void AEDSPApplyEqualPowerRamp(const AudioBufferList * bufferList, float * start, float step, UInt32 frames, float * scratch);

/*!
 * Scale values in a buffer list by some gain value, with smoothing to avoid discontinuities
 *
 * @param bufferList Audio buffer list, in non-interleaved float format
 * @param targetGain Target gain amount (power ratio)
 * @param currentGain On input, current gain; on output, the new gain. Store this and pass it back to this
 *  function on successive calls for a smooth ramp
 * @param frames Length of buffer in frames
 */
void AEDSPApplyGainSmoothed(const AudioBufferList * bufferList, float targetGain, float * currentGain, UInt32 frames);

/*!
 * Scale values in a buffer list by some gain value, with smoothing to avoid discontinuities
 *
 * @param bufferList Audio buffer list, in non-interleaved float format
 * @param targetGain Target gain amount (power ratio)
 * @param currentGain On input, current gain; on output, the new gain. Store this and pass it back to this
 *  function on successive calls for a smooth ramp
 * @param frames Length of buffer in frames
 * @param rampDuration Duration of full 0.0-1.0/1.0-0.0 transition, in frames
 */
void AEDSPApplyGainWithRamp(const AudioBufferList * bufferList, float targetGain, float * currentGain, UInt32 frames,
                                    UInt32 rampDuration);
    
/*!
 * Scale values in a single buffer by some gain value, with smoothing to avoid discontinuities
 *
 * @param buffer Float array
 * @param targetGain Target gain amount (power ratio)
 * @param currentGain On input, current gain; on output, the new gain
 * @param frames Length of buffer in frames
 */
void AEDSPApplyGainSmoothedMono(float * buffer, float targetGain, float * currentGain, UInt32 frames);

/*!
 * Apply volume and balance controls to the buffer
 *
 *  This function applies gains to the given buffer to affect volume and balance, with a smoothing ramp
 *  applied to avoid discontinuities.
 *
 * @param bufferList Audio buffer list, in non-interleaved float format
 * @param targetVolume The target volume (power ratio)
 * @param currentVolume On input, the current volume; on output, the new volume. Store this and pass it
 *  back to this function on successive calls for a smooth ramp. If NULL, no smoothing will be applied.
 * @param targetBalance The target balance
 * @param currentBalance On input, the current balance; on output, the new balance. Store this and pass it
 *  back to this function on successive calls for a smooth ramp. If NULL, no smoothing will be applied.
 * @param frames Length of buffer in frames
 */
void AEDSPApplyVolumeAndBalance(const AudioBufferList * bufferList, float targetVolume, float * currentVolume,
                                float targetBalance, float * currentBalance, UInt32 frames);


/*!
 * Mix two buffer lists
 *
 *  Combines values in each buffer list, after scaling by given factors. If monoToStereo is YES,
 *  then if a buffer is mono, and the output is stereo, the buffer will have its channels doubled
 *  If the output is mono, any buffers with more channels will have these mixed down into the 
 *  mono output.
 *
 *  This method assumes the number of frames in each buffer is the same.
 *
 *  Note that input buffer contents may be modified during this operation.
 *
 * @param bufferList1 First buffer list, in non-interleaved float format
 * @param bufferList2 Second buffer list, in non-interleaved float format
 * @param gain1 Gain factor for first buffer list (power ratio)
 * @param gain2 Gain factor for second buffer list
 * @param monoToStereo Whether to double mono tracks to stereo, if output is stereo
 * @param frames Length of buffer in frames, or 0 for entire buffer (based on mDataByteSize fields)
 * @param output Output buffer list (may be same as bufferList1 or bufferList2)
 */
void AEDSPMix(const AudioBufferList * bufferList1, const AudioBufferList * bufferList2, float gain1, float gain2,
              BOOL monoToStereo, UInt32 frames, const AudioBufferList * output);

/*!
 * Mix two single mono buffers
 *
 * @param buffer1 First buffer
 * @param buffer2 Second buffer
 * @param gain1 Gain factor for first buffer (power ratio)
 * @param gain2 Gain factor for second buffer
 * @param frames Number of frames
 * @param output Output buffer
 */
void AEDSPMixMono(const float * buffer1, const float * buffer2, float gain1, float gain2, UInt32 frames, float * output);

/*!
 * Silence an audio buffer list (zero out frames)
 *
 * @param bufferList Pointer to an AudioBufferList containing audio
 * @param offset Offset into buffer
 * @param length Number of frames to silence (0 for whole buffer)
 */
#define AEDSPSilence AEAudioBufferListSilence

/*!
 * Generate oscillator/LFO
 *
 *  This function produces, sample by sample, an oscillator signal that approximates a sine wave. Its
 *  output lies in the range 0 - 1.
 *
 * @param rate Oscillation rate, per sample (frequency / sample rate)
 * @param position On input, current oscillator position; on output, new position.
 * @return One sample of oscillator signal
 */
static inline float AEDSPGenerateOscillator(float rate, float * position) {
    float x = *position;
    x *= x;
    x -= 1.0;
    x *= x;
    *position += rate;
    if ( *position > 1.0 ) *position -= 2.0;
    return x;
}

/*!
 * Convert decibels to power ratio
 *
 * @param decibels Value in decibels
 * @return Power ratio value
 */
static inline double AEDSPDecibelsToRatio(double decibels) {
    return pow(10.0, decibels / 20.0);
}

/*!
 * Convert power ratio to decibels
 *
 * @param ratio Power ratio
 * @return Value in decibels
 */
static inline double AEDSPRatioToDecibels(double ratio) {
    return 20.0 * log10(ratio);
}

#ifdef __cplusplus
}
#endif
