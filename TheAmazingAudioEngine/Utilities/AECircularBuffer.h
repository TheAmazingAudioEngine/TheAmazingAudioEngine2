//
//  AECircularBuffer.h
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 29/04/2016.
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

#import "TPCircularBuffer.h"
#import <AudioToolbox/AudioToolbox.h>

#ifdef __cplusplus
extern "C" {
#endif

#define AECircularBufferCopyAll UINT32_MAX

/*!
 * Circular buffer
 *
 *  This utility provides a thread-safe and lock-free FIFO buffer that operates on AudioBufferLists 
 *  and tracks the AudioTimeStamps corresponding to the audio.
 *
 *  It provides a convenience wrapper to TPCircularBuffer and its AudioBufferList utilities, by avoiding
 *  the need to provide an AudioStreamBasicDescription to the various functions, among other things.
 *
 *  It's generally preferable to use this interface instead of TPCircularBuffer if you're just
 *  using the TAAE audio format (non-interleaved float).
 */
typedef struct {
    TPCircularBuffer buffer;
    AudioStreamBasicDescription audioDescription;
} AECircularBuffer;

/*!
 * Initialize buffer
 *
 *  Note that the length is advisory only; the true buffer length will
 *  be multiples of the device page size (e.g. 4096 bytes)
 *
 * @param buffer Circular buffer
 * @param capacityInFrames Amount of audio frames you wish to store in the buffer
 * @param channelCount Number of channels of audio you'll be working with
 * @param sampleRate Sample rate of audio, used to work with AudioTimeStamps
 * @return YES on success, NO on buffer allocation failure
 */
BOOL AECircularBufferInit(AECircularBuffer * buffer, UInt32 capacityInFrames, int channelCount, double sampleRate);

/*!
 * Cleanup buffer
 *
 *  Releases buffer resources.
 */
void AECircularBufferCleanup(AECircularBuffer *buffer);

/*!
 * Clear buffer
 *
 *  Resets buffer to original, empty state.
 *
 *  This is safe for use by consumer while producer is accessing the buffer.
 */
void AECircularBufferClear(AECircularBuffer *buffer);

/*!
 * Set the atomicity
 *
 *  If you set the atomiticy to false using this method, the buffer will
 *  not use atomic operations. This can be used to give the compiler a little
 *  more optimisation opportunities when the buffer is only used on one thread.
 *
 *  Important note: Only set this to false if you know what you're doing!
 *
 *  The default value is true (the buffer will use atomic operations)
 *
 * @param buffer Circular buffer
 * @param atomic Whether the buffer is atomic (default true)
 */
void AECircularBufferSetAtomic(AECircularBuffer *buffer, BOOL atomic);

/*!
 * Change channel count and/or sample rate
 *
 *  This will cause the buffer to clear any existing audio, and reconfigure to use the new
 *  channel count and sample rate. Note that it will not alter the buffer's capacity; if you
 *  need to increase capacity to cater to a larger number of channels/frames, then you'll
 *  need to cleanup and re-initialize the buffer.
 *
 *  You should only use this on the consumer thread.
 *
 * @param buffer Circular buffer
 * @param channelCount Number of channels of audio you'll be working with
 * @param sampleRate Sample rate of audio, used to work with AudioTimeStamps
 */
void AECircularBufferSetChannelCountAndSampleRate(AECircularBuffer * buffer,
                                                  int channelCount,
                                                  double sampleRate);

#pragma mark - Producing

/*!
 * Determine how many much space there is in the buffer
 *
 *  Determines the number of frames of audio that can be buffered.
 *
 *  Note: This function should only be used on the producer thread, not the consumer thread.
 *
 * @param buffer Circular buffer
 * @return The number of frames that can be stored in the buffer
 */
UInt32 AECircularBufferGetAvailableSpace(AECircularBuffer *buffer);

/*!
 * Copy the audio buffer list onto the buffer
 *
 * @param buffer Circular buffer
 * @param bufferList Buffer list containing audio to copy to buffer
 * @param timestamp The timestamp associated with the buffer, or NULL
 * @param frames Length of audio in frames, or AECircularBufferCopyAll to copy the whole buffer
 * @return YES if buffer list was successfully copied; NO if there was insufficient space
 */
BOOL AECircularBufferEnqueue(AECircularBuffer *buffer,
                             const AudioBufferList *bufferList,
                             const AudioTimeStamp *timestamp,
                             UInt32 frames);

/*!
 * Prepare an empty buffer list, stored on the circular buffer
 *
 * @param buffer Circular buffer
 * @param frameCount The number of frames that will be stored
 * @param timestamp The timestamp associated with the buffer, or NULL.
 * @return The empty buffer list, or NULL if circular buffer has insufficient space
 */
AudioBufferList * AECircularBufferPrepareEmptyAudioBufferList(AECircularBuffer *buffer,
                                                              UInt32 frameCount,
                                                              const AudioTimeStamp *timestamp);

/*!
 * Mark next audio buffer list as ready for reading
 *
 *  This marks the audio buffer list prepared using AECircularBufferPrepareEmptyAudioBufferList
 *  as ready for reading. You must not call this function without first calling
 *  AECircularBufferPrepareEmptyAudioBufferList.
 *
 * @param buffer Circular buffer
 */
void AECircularBufferProduceAudioBufferList(AECircularBuffer *buffer);

#pragma mark - Consuming
    
/*!
 * Determine how many frames of audio are buffered
 *
 *  Note: This function should only be used on the consumer thread, not the producer thread.
 *
 * @param buffer Circular buffer
 * @param outTimestamp On output, if not NULL, the timestamp corresponding to the first audio frame
 * @return The number of frames queued in the buffer
 */
UInt32 AECircularBufferPeek(AECircularBuffer *buffer, AudioTimeStamp *outTimestamp);

/*!
 * Copy a certain number of frames from the buffer and dequeue
 *
 * @param buffer Circular buffer
 * @param ioLengthInFrames On input, the number of frames to consume; on output, the number of frames provided
 * @param outputBufferList The buffer list to copy audio to, or NULL to discard audio.
 * @param outTimestamp On output, if not NULL, the timestamp corresponding to the first audio frame returned
 */
void AECircularBufferDequeue(AECircularBuffer *buffer,
                             UInt32 *ioLengthInFrames,
                             const AudioBufferList *outputBufferList,
                             AudioTimeStamp *outTimestamp);

/*!
 * Access the next stored buffer list
 *
 * @param buffer Circular buffer
 * @param outTimestamp On output, if not NULL, the timestamp corresponding to the buffer
 * @param lastBufferList If not NULL, the preceding buffer list on the buffer. The next buffer list after this will be returned; use this to iterate through all queued buffers. If NULL, this function will return the first queued buffer.
 * @return Pointer to the next queued buffer list
 */
AudioBufferList * AECircularBufferNextBufferList(AECircularBuffer *buffer,
                                                 AudioTimeStamp *outTimestamp,
                                                 const AudioBufferList * lastBufferList);

/*!
 * Consume the next buffer list available for reading
 *
 * @param buffer Circular buffer
 */
void AECircularBufferConsumeNextBufferList(AECircularBuffer *buffer);

/*!
 * Consume a portion of the next buffer list
 *
 *  This will also increment the sample time and host time portions of the timestamp of
 *  the buffer list, if present.
 *
 * @param buffer Circular buffer
 * @param frames The number of frames to consume from the buffer list
 */
void AECircularBufferConsumeNextBufferListPartial(AECircularBuffer *buffer, UInt32 frames);

#ifdef __cplusplus
}
#endif