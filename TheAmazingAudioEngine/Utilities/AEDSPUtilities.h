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

@import Foundation;
@import AudioToolbox;

#ifdef __cplusplus
extern "C" {
#endif

/*
	Clear buffers in AudioBufferList using AEDSPClearAudioBuffer
	
	@param listPtr Pointer to AudioBufferList struct
	@param frameCount Number of frames to clear in each AudioBuffer
*/
void AEDSPClearBufferList(AudioBufferList *listPtr, UInt32 frameCount);


/*
	Clear buffer to zero using vDSP_vclr and set mDataByteSize accordingly
	
	@param bufferPtr Pointer to AudioBuffer struct
	@param frameCount Number of frames to clear, 
			mDataByteSize field will be set accordingly
*/
void AEDSPClearAudioBuffer(AudioBuffer *bufferPtr, UInt32 frameCount);


/*!
 * Scale values in a buffer list by some gain value
 *
 * @param bufferList Audio buffer list, in non-interleaved float format
 * @param gain Gain amount (power ratio)
 * @param frames Length in frames
 */
void AEDSPApplyGain(const AudioBufferList * bufferList, float gain, UInt32 frames);

/*!
 * Apply a ramp to values in a buffer list
 *
 * @param bufferList Audio buffer list, in non-interleaved float format
 * @param start Starting gain (power ratio) on input; final gain value on output
 * @param step Amount per frame to advance gain
 * @param frames Length in frames
 */
void AEDSPApplyRamp(const AudioBufferList * bufferList, float * start, float step, UInt32 frames);

/*!
 * Scale values in a buffer list by some gain value, with smoothing to avoid discontinuities
 *
 * @param bufferList Audio buffer list, in non-interleaved float format
 * @param targetGain Target gain amount (power ratio)
 * @param currentGain On input, current gain; on output, the new gain. Store this and pass it back to this
 *  function on successive calls for a smooth ramp
 * @param frames Length in frames
 */
void AEDSPApplyGainSmoothed(const AudioBufferList * bufferList, float targetGain, float * currentGain, UInt32 frames);

/*!
 * Scale values in a single buffer by some gain value, with smoothing to avoid discontinuities
 *
 * @param buffer Float array
 * @param targetGain Target gain amount (power ratio)
 * @param currentGain On input, current gain; on output, the new gain
 * @param frames Length in frames
 */
void AEDSPApplyGainSmoothedMono(float * buffer, float targetGain, float * currentGain, UInt32 frames);

/*!
 * Apply volume and balance controls to the buffer
 *
 *  This function applies gains to the given buffer to affect volume and balance, with a smoothing ramp
 *  applied to avoid discontinuities.
 *
 * @param buffer Audio buffer list, in non-interleaved float format
 * @param targetVolume The target volume (power ratio)
 * @param currentVolume On input, the current volume; on output, the new volume. Store this and pass it
 *  back to this function on successive calls for a smooth ramp. If NULL, no smoothing will be applied.
 * @param targetBalance The target balance
 * @param currentBalance On input, the current balance; on output, the new balance. Store this and pass it
 *  back to this function on successive calls for a smooth ramp. If NULL, no smoothing will be applied.
 * @param frames Length in frames
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
 * @param output Output buffer list (may be same as bufferList1 or bufferList2)
 */
void AEDSPMix(const AudioBufferList * bufferList1, const AudioBufferList * bufferList2, float gain1, float gain2,
              BOOL monoToStereo, const AudioBufferList * output);

/*!
 * Generate oscillator/LFO
 *
 *  This function produces, sample by sample, a sine-line oscillator signal. Its
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
static inline float AEDSPDecibelsToRatio(float decibels) {
    return powf(10.0f, decibels / 20.0f);
}

/*!
 * Convert power ratio to decibels
 *
 * @param ratio Power ratio
 * @return Value in decibels
 */
static inline float AEDSPRatioToDecibels(float ratio) {
    return 20.0f * log10f(ratio);
}

#ifdef __cplusplus
}
#endif
