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
void AEDSPApplyGain(const AudioBufferList * bufferList, float gain, UInt32 frames, const AudioBufferList * output);

/*!
 * Apply a ramp to values in a buffer list
 *
 * @param bufferList Audio buffer list, in non-interleaved float format
 * @param start Starting gain (power ratio) on input; final gain value on output
 * @param step Amount per frame to advance gain
 * @param frames Length of buffer in frames
 */
void AEDSPApplyRamp(const AudioBufferList * bufferList, float * start, float step, UInt32 frames, const AudioBufferList * output);

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
void AEDSPApplyEqualPowerRamp(const AudioBufferList * bufferList, float * start, float step, UInt32 frames, float * scratch, const AudioBufferList * output);

/*!
 * Scale values in a buffer list by some gain value, with smoothing to avoid discontinuities
 *
 * @param bufferList Audio buffer list, in non-interleaved float format
 * @param targetGain Target gain amount (power ratio)
 * @param currentGain On input, current gain; on output, the new gain. Store this and pass it back to this
 *  function on successive calls for a smooth ramp
 * @param frames Length of buffer in frames
 */
void AEDSPApplyGainSmoothed(const AudioBufferList * bufferList, float targetGain, float * currentGain, UInt32 frames, const AudioBufferList * output);

/*!
 * Scale values in a buffer list by some gain value, with smoothing to avoid discontinuities
 *
 * @param bufferList Audio buffer list, in non-interleaved float format
 * @param targetGain Target gain amount (power ratio)
 * @param currentGain On input, current gain; on output, the new gain. Store this and pass it back to this
 *  function on successive calls for a smooth ramp
 * @param frames Length of buffer in frames
 * @param step Amount per frame to advance gain
 * @param maximumRampDuration Longest 0.0-1.0/1.0-0.0 transition to allow, in frames (or zero, to not limit transition duration)
 * @param output The target buffer
 */
void AEDSPApplyGainWithRamp(const AudioBufferList * bufferList, float targetGain, float * currentGain, UInt32 frames, float step, UInt32 maximumRampDuration, const AudioBufferList * output);
    
/*!
 * Scale values in a single buffer by some gain value, with smoothing to avoid discontinuities
 *
 * @param buffer Float array
 * @param targetGain Target gain amount (power ratio)
 * @param currentGain On input, current gain; on output, the new gain
 * @param frames Length of buffer in frames
 */
void AEDSPApplyGainSmoothedMono(float * buffer, float targetGain, float * currentGain, UInt32 frames, float * output);

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
void AEDSPApplyVolumeAndBalance(const AudioBufferList * bufferList, float targetVolume, float * currentVolume, float targetBalance, float * currentBalance, UInt32 frames, const AudioBufferList * output);


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
 * Crossfade from one buffer to another
 *
 * @param a First buffer list
 * @param b Second buffer list
 * @param target Target buffer list
 * @param frames Number of frames to crossfade over
 */
void AEDSPCrossfade(const AudioBufferList * a, const AudioBufferList * b, const AudioBufferList * target, UInt32 frames);

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

/*!
 * Convert decibels to power ratio
 *
 * @param decibels Value in decibels
 * @param minDb Minimum value in dB
 * @return Power ratio value
 */
static inline double AEDSPDecibelsToRatioClipped(double decibels, double minDb) {
    return decibels <= minDb ? 0 : pow(10.0, decibels / 20.0);
}

/*!
 * Convert a UI fader position to decibels
 *
 *  Position of 0 corresponds to -INFINITY; position of 1 corresponds to maxDb.
 *
 * @param position Fader position (0 - 1)
 * @param minDb Minimum value in dB
 * @param midDb Middle value in dB; the largest range of the fader will range from 0dB to this value
 * @param maxDb Maximum value in dB
 * @return Corresponding value in decibels
 */
double AEDSPFaderPositionToDecibels(double position, double minDb, double midDb, double maxDb);

/*!
 * Convert a UI fader position to decibels
 *
 *  Position of 0 corresponds to -INFINITY; position of 1 corresponds to maxDb.
 *
 * @param decibels Value in decibels
 * @param minDb Minimum value in dB (at position 0, will return -INFINITY)
 * @param midDb Middle value in dB; the largest range of the fader will range from 0dB to this value
 * @param maxDb Maximum value in dB
 * @return Corresponding fader position
 */
double AEDSPDecibelsToFaderPosition(double decibels, double minDb, double midDb, double maxDb);

/*!
 * Structure for FFT convolution
 */
typedef struct AEDSPFFTConvolution_t AEDSPFFTConvolution;

/*!
 * FFT convolution operation
 */
typedef enum {
    
    //! Default convolution (returns only non-zero-padded elements a la Matlab "valid" and vDSP_conv behaviour)
    AEDSPFFTConvolutionOperation_Convolution,
    //! Full convolution
    AEDSPFFTConvolutionOperation_ConvolutionFull,
    //! Default correlation (returns only non-zero-padded elements a la Matlab "valid" and vDSP_conv behaviour)
    AEDSPFFTConvolutionOperation_Correlation,
    //! Full correlation
    AEDSPFFTConvolutionOperation_CorrelationFull
    
} AEDSPFFTConvolutionOperation;

/*!
 * Initialize FFT convolution
 *
 *  Choose a length that is equal to the length of the filter, plus the processing block
 *  size you would like to use (this utility will automatically break processing up into
 *  blocks of this size if necessary). For example, for convolving a signal by a 4096-element
 *  filter in blocks of 512 frames, you would select a length of 4096+512.
 *
 * @param length Block length (this utility will select an appropriate FFT size at least this length)
 * @returns Allocated setup structure
 */
AEDSPFFTConvolution * AEDSPFFTConvolutionInit(int length);

/*!
 * Return appropriate FFT size greater than or equal to the given length
 *
 *  This is used automatically by AEDSPFFTConvolutionInit, but can be used in advance to make
 *  other determinations in advance.
 */
int AEDSPFFTConvolutionCalculateFFTLength(int length);

/*!
 * Deallocate FFT convolution resources
 *
 * @param setup Setup structure
 */
void AEDSPFFTConvolutionDealloc(AEDSPFFTConvolution * setup);

/*!
 * Perform a single convolution
 *
 *  For one-off processing, use this method. For operation on continuous signals, use
 *  AEDSPFFTConvolutionPrepareContinuous and AEDSPFFTConvolutionExecuteContinuous.
 *
 * @param setup Setup structure
 * @param input Input signal
 * @param inputLength Length of input signal
 * @param filter Filter signal
 * @param filterLength Length of filter signal (must be less than or equal to the setup length)
 * @param output Output buffer (can be same as input, for in-place processing, must have length of inputLength)
 * @param outputLength Length of output
 * @param operation Operation to perform
 */
void AEDSPFFTConvolutionExecute(AEDSPFFTConvolution * setup, float * input, int inputLength, float * filter, int filterLength, float * output, int outputLength, AEDSPFFTConvolutionOperation operation);

/*!
 * Prepare for execution on continuous signals
 *
 *  This utility allows you to prepare for convolving the given filter with a continuous input
 *  signal, via AEDSPFFTConvolutionExecuteContinuous.
 *
 *  You may call this function during use to update the filter without affecting continuous operation.
 *
 * @param setup Setup structure
 * @param filter Filter signal
 * @param filterLength Length of filter signal (must be less than or equal to the setup length)
 * @param operation Operation to perform
 */
void AEDSPFFTConvolutionPrepareContinuous(AEDSPFFTConvolution * setup, float * filter, int filterLength, AEDSPFFTConvolutionOperation operation);

/*!
 * Process a continuous signal
 *
 *  Use AEDSPFFTConvolutionPrepareContinuous to setup this utility, then call this method
 *  to process input buffers.
 *
 * @param setup Setup structure
 * @param input Input signal
 * @param inputLength Length of input signal
 * @param output Output buffer (can be same as input, for in-place processing, must have length of inputLength)
 * @param outputLength Length of output
 */
void AEDSPFFTConvolutionExecuteContinuous(AEDSPFFTConvolution * setup, float * input, int inputLength, float * output, int outputLength);

/*!
 * Reset internal buffers before processing a new continuous signal
 *
 * @param setup Setup structure
 */
void AEDSPFFTConvolutionReset(AEDSPFFTConvolution * setup);

/*!
 * Identify the peaks in a distribution
 *
 * @param distribution Array of floats to analyse
 * @param startIndex The start element of the sub-range to search (use higher value than endIndex to perform a reverse search)
 * @param endIndex The end element of the sub-range to search
 * @param leadingDelta The minimum height of the leading edge of peaks (relative to the preceding valley)
 * @param trailingDelta The minimum height of the trailing edge of peaks (next valley depth, relative to the peak height)
 * @param minimumSeparation The minimum space between successive peaks (a peak within this distance of the preceding one will be ignored)
 * @param sort Whether to sort results. Passing YES will cause this method to dynamically allocate a buffer to store all impulses, returning the highest peaks; this is not realtime safe.
 * @param peaks A buffer to store the discovered peaks, as a list of indices into the distribution
 * @param maxPeaks Size of peaks buffer
 * @return The number of peaks identified
 */
int AEDSPFindPeaksInDistribution(float * distribution, int startIndex, int endIndex, float leadingDelta, float trailingDelta, int minimumSeparation, BOOL sort, int * peaks, int maxPeaks);

/*!
 * Perform a peak-descent given the distribution, to find the onset of a peak
 *
 * @param index Index of the peak, from which we will descend backwards in the distribution
 * @param distribution Array of floats to analyse
 * @param length Length of distribution
 * @param maxOffset The maximum number of samples to move backward; the returned value will be >= index-maxOffset
 * @param maxStep The maximum step size at each step of the algorithm (e.g. 10 samples)
 * @param minimumGradient The gradient threshold (e.g. 0.1); to continue descent, (distribution[prior] - distribution[candidate])  / distribution[peak] must be greater than this
 */
int AEDSPFindPeakOnset(int index, float * distribution, int length, int maxOffset, int maxStep, float minimumGradient);

#ifdef __cplusplus
}
#endif
