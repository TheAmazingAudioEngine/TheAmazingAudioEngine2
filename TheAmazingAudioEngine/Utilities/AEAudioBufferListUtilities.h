//
//  AEAudioBufferListUtilities.h
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 24/03/2016.
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
#import "AETypes.h"

/*!
 * Allocate an audio buffer list and the associated mData pointers, using the default audio format.
 *
 *  Note: Do not use this utility from within the Core Audio thread (such as inside a render
 *  callback). It may cause the thread to block, inducing audio stutters.
 *
 * @param frameCount The number of frames to allocate space for (or 0 to just allocate the list structure itself)
 * @return The allocated and initialised audio buffer list
 */
AudioBufferList *AEAudioBufferListCreate(int frameCount);

/*!
 * Allocate an audio buffer list and the associated mData pointers, with a custom audio format.
 *
 *  Note: Do not use this utility from within the Core Audio thread (such as inside a render
 *  callback). It may cause the thread to block, inducing audio stutters.
 *
 * @param audioFormat Audio format describing audio to be stored in buffer list
 * @param frameCount The number of frames to allocate space for (or 0 to just allocate the list structure itself)
 * @return The allocated and initialised audio buffer list
 */
AudioBufferList *AEAudioBufferListCreateWithFormat(AudioStreamBasicDescription audioFormat, int frameCount);

/*!
 * Create an audio buffer list on the stack, using the default audio format.
 *
 *  This is useful for creating buffers for temporary use, without needing to perform any
 *  memory allocations. It will create a local AudioBufferList* variable on the stack, with 
 *  a name given by the first argument, and initialise the buffer according to the given
 *  audio format.
 *
 *  The created buffer will have NULL mData pointers and 0 mDataByteSize: you will need to 
 *  assign these to point to a memory buffer.
 *
 * @param name Name of the variable to create on the stack
 */
#define AEAudioBufferListCreateOnStack(name) \
    AEAudioBufferListCreateOnStackWithFormat(name, AEAudioDescription)

/*!
 * Create an audio buffer list on the stack, with a custom audio format.
 *
 *  This is useful for creating buffers for temporary use, without needing to perform any
 *  memory allocations. It will create a local AudioBufferList* variable on the stack, with 
 *  a name given by the first argument, and initialise the buffer according to the given
 *  audio format.
 *
 *  The created buffer will have NULL mData pointers and 0 mDataByteSize: you will need to 
 *  assign these to point to a memory buffer.
 *
 * @param name Name of the variable to create on the stack
 * @param audioFormat The audio format to use
 */
#define AEAudioBufferListCreateOnStackWithFormat(name, audioFormat) \
    int name ## _numberBuffers = audioFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved \
                                    ? audioFormat.mChannelsPerFrame : 1; \
    char name ## _bytes[sizeof(AudioBufferList)+(sizeof(AudioBuffer)*(name ## _numberBuffers-1))]; \
    memset(&name ## _bytes, 0, sizeof(name ## _bytes)); \
    AudioBufferList * name = (AudioBufferList*)name ## _bytes; \
    name->mNumberBuffers = name ## _numberBuffers; \
    for ( int i=0; i<name->mNumberBuffers; i++ ) { \
        name->mBuffers[i].mNumberChannels \
            = audioFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved ? 1 : audioFormat.mChannelsPerFrame; \
    }

/*!
 * Create a stack copy of the given audio buffer list and offset mData pointers
 *
 *  This is useful for creating buffers that point to an offset into the original buffer,
 *  to fill later regions of the buffer. It will create a local AudioBufferList* variable 
 *  on the stack, with a name given by the first argument, copy the original AudioBufferList 
 *  structure values, and offset the mData and mDataByteSize variables.
 *
 *  Note that only the AudioBufferList structure itself will be copied, not the data to
 *  which it points.
 *
 * @param name Name of the variable to create on the stack
 * @param sourceBufferList The original buffer list to copy
 * @param offsetFrames Number of frames of noninterleaved float to offset mData/mDataByteSize members
 */
#define AEAudioBufferListCopyOnStack(name, sourceBufferList, offsetFrames) \
    AEAudioBufferListCopyOnStackWithByteOffset(name, sourceBufferList, offsetFrames * AEAudioDescription.mBytesPerFrame)

/*!
 * Create a stack copy of the given audio buffer list and offset mData pointers, with offset in bytes
 *
 *  This is useful for creating buffers that point to an offset into the original buffer,
 *  to fill later regions of the buffer. It will create a local AudioBufferList* variable 
 *  on the stack, with a name given by the first argument, copy the original AudioBufferList 
 *  structure values, and offset the mData and mDataByteSize variables.
 *
 *  Note that only the AudioBufferList structure itself will be copied, not the data to
 *  which it points.
 *
 * @param name Name of the variable to create on the stack
 * @param sourceBufferList The original buffer list to copy
 * @param offsetBytes Number of bytes to offset mData/mDataByteSize members
 */
#define AEAudioBufferListCopyOnStackWithByteOffset(name, sourceBufferList, offsetBytes) \
    char name ## _bytes[sizeof(AudioBufferList)+(sizeof(AudioBuffer)*(sourceBufferList->mNumberBuffers-1))]; \
    memcpy(name ## _bytes, sourceBufferList, sizeof(name ## _bytes)); \
    AudioBufferList * name = (AudioBufferList*)name ## _bytes; \
    for ( int i=0; i<name->mNumberBuffers; i++ ) { \
        name->mBuffers[i].mData = (char*)name->mBuffers[i].mData + offsetBytes; \
        name->mBuffers[i].mDataByteSize -= offsetBytes; \
    }

/*!
 * Create a stack copy of an audio buffer list that points to a subset of its channels
 *
 * @param name Name of the variable to create on the stack
 * @param sourceBufferList The original buffer list to copy
 * @param channelSet The subset of channels
 */
#define AEAudioBufferListCopyOnStackWithChannelSubset(name, sourceBufferList, channelSet) \
    int name ## _bufferCount = MIN(sourceBufferList->mNumberBuffers-1, channelSet.lastChannel) - \
                               MIN(sourceBufferList->mNumberBuffers-1, channelSet.firstChannel) + 1; \
    char name ## _bytes[sizeof(AudioBufferList)+(sizeof(AudioBuffer)*(name ## _bufferCount-1))]; \
    AudioBufferList * name = (AudioBufferList*)name ## _bytes; \
    name->mNumberBuffers = name ## _bufferCount; \
    memcpy(name->mBuffers, &sourceBufferList->mBuffers[MIN(sourceBufferList->mNumberBuffers-1, channelSet.firstChannel)], \
        sizeof(AudioBuffer) * name ## _bufferCount);

/*!
 * Create a copy of an audio buffer list
 *
 *  Note: Do not use this utility from within the Core Audio thread (such as inside a render
 *  callback). It may cause the thread to block, inducing audio stutters.
 *
 * @param original The original AudioBufferList to copy
 * @return The new, copied audio buffer list
 */
AudioBufferList *AEAudioBufferListCopy(const AudioBufferList *original);

/*!
 * Free a buffer list and associated mData buffers
 *
 *  Note: Do not use this utility from within the Core Audio thread (such as inside a render
 *  callback). It may cause the thread to block, inducing audio stutters.
 */
void AEAudioBufferListFree(AudioBufferList *bufferList);

/*!
 * Get the number of frames in a buffer list, with the default audio format
 *
 *  Calculates the frame count in the buffer list based on the given
 *  audio format. Optionally also provides the channel count.
 *
 * @param bufferList  Pointer to an AudioBufferList containing audio
 * @param oNumberOfChannels If not NULL, will be set to the number of channels of audio in 'list'
 * @return Number of frames in the buffer list
 */
UInt32 AEAudioBufferListGetLength(const AudioBufferList *bufferList, int *oNumberOfChannels);

/*!
 * Get the number of frames in a buffer list, with a custom audio format
 *
 *  Calculates the frame count in the buffer list based on the given
 *  audio format. Optionally also provides the channel count.
 *
 * @param bufferList Pointer to an AudioBufferList containing audio
 * @param audioFormat Audio format describing the audio in the buffer list
 * @param oNumberOfChannels If not NULL, will be set to the number of channels of audio in 'list'
 * @return Number of frames in the buffer list
 */
UInt32 AEAudioBufferListGetLengthWithFormat(const AudioBufferList *bufferList,
                                            AudioStreamBasicDescription audioFormat,
                                            int *oNumberOfChannels);

/*!
 * Set the number of frames in a buffer list, with the default audio format
 *
 *  Calculates the frame count in the buffer list based on the given
 *  audio format, and assigns it to the buffer list members.
 *
 * @param bufferList Pointer to an AudioBufferList containing audio
 * @param frames The number of frames to set
 */
void AEAudioBufferListSetLength(AudioBufferList *bufferList, UInt32 frames);

/*!
 * Set the number of frames in a buffer list, with a custom audio format
 *
 *  Calculates the frame count in the buffer list based on the given
 *  audio format, and assigns it to the buffer list members.
 *
 * @param bufferList Pointer to an AudioBufferList containing audio
 * @param audioFormat Audio format describing the audio in the buffer list
 * @param frames The number of frames to set
 */
void AEAudioBufferListSetLengthWithFormat(AudioBufferList *bufferList,
                                          AudioStreamBasicDescription audioFormat,
                                          UInt32 frames);

/*!
 * Offset the pointers in a buffer list, with the default audio format
 *
 *  Increments the mData pointers in the buffer list by the given number
 *  of frames. This is useful for filling a buffer in incremental stages.
 *
 * @param bufferList Pointer to an AudioBufferList containing audio
 * @param frames The number of frames to offset the mData pointers by
 */
void AEAudioBufferListOffset(AudioBufferList *bufferList, UInt32 frames);

/*!
 * Offset the pointers in a buffer list, with a custom audio format
 *
 *  Increments the mData pointers in the buffer list by the given number
 *  of frames. This is useful for filling a buffer in incremental stages.
 *
 * @param bufferList Pointer to an AudioBufferList containing audio
 * @param audioFormat Audio format describing the audio in the buffer list
 * @param frames The number of frames to offset the mData pointers by
 */
void AEAudioBufferListOffsetWithFormat(AudioBufferList *bufferList,
                                       AudioStreamBasicDescription audioFormat,
                                       UInt32 frames);

/*!
 * Assign values of one buffer list to another, with the default audio format
 *
 *  Note that this simply assigns the buffer list values; if you wish to copy
 *  the contents, use AEAudioBufferListCopy or AEAudioBufferListCopyContents
 *
 * @param target Target buffer list, to assign values to
 * @param source Source buffer list, to assign values from
 * @param offset Offset into target buffer
 * @param length Length to assign, in frames
 */
void AEAudioBufferListAssign(AudioBufferList * target, const AudioBufferList * source, UInt32 offset, UInt32 length);
    
/*!
 * Assign values of one buffer list to another, with the default audio format
 *
 *  Note that this simply assigns the buffer list values; if you wish to copy
 *  the contents, use AEAudioBufferListCopy or AEAudioBufferListCopyContents
 *
 * @param target Target buffer list, to assign values to
 * @param source Source buffer list, to assign values from
 * @param audioFormat Audio format describing the audio in the buffer list
 * @param offset Offset into target buffer
 * @param length Length to assign, in frames
 */
void AEAudioBufferListAssignWithFormat(AudioBufferList * target, const AudioBufferList * source,
                                       AudioStreamBasicDescription audioFormat, UInt32 offset, UInt32 length);

/*!
 * Silence an audio buffer list (zero out frames), with the default audio format
 *
 * @param bufferList Pointer to an AudioBufferList containing audio
 * @param offset Offset into buffer
 * @param length Number of frames to silence (0 for whole buffer)
 */
void AEAudioBufferListSilence(const AudioBufferList *bufferList, UInt32 offset, UInt32 length);

/*!
 * Silence an audio buffer list (zero out frames), with a custom audio format
 *
 * @param bufferList Pointer to an AudioBufferList containing audio
 * @param audioFormat Audio format describing the audio in the buffer list
 * @param offset Offset into buffer
 * @param length Number of frames to silence (0 for whole buffer)
 */
void AEAudioBufferListSilenceWithFormat(const AudioBufferList *bufferList,
                                        AudioStreamBasicDescription audioFormat,
                                        UInt32 offset,
                                        UInt32 length);

/*!
 * Copy the contents of one AudioBufferList to another, with the default audio format
 *
 * @param target Target buffer list, to copy to
 * @param source Source buffer list, to copy from
 * @param targetOffset Offset into target buffer
 * @param sourceOffset Offset into source buffer
 * @param length Number of frames to copy (0 for whole buffer)
 */
void AEAudioBufferListCopyContents(const AudioBufferList * target,
                                   const AudioBufferList * source,
                                   UInt32 targetOffset,
                                   UInt32 sourceOffset,
                                   UInt32 length);

/*!
 * Copy the contents of one AudioBufferList to another, with a custom audio format
 *
 * @param target Target buffer list, to copy to
 * @param source Source buffer list, to copy from
 * @param audioFormat Audio format describing the audio in the buffer list
 * @param targetOffset Offset into target buffer
 * @param sourceOffset Offset into source buffer
 * @param length Number of frames to copy (0 for whole buffer)
 */
void AEAudioBufferListCopyContentsWithFormat(const AudioBufferList * target,
                                             const AudioBufferList * source,
                                             AudioStreamBasicDescription audioFormat,
                                             UInt32 targetOffset,
                                             UInt32 sourceOffset,
                                             UInt32 length);

/*!
 * Get the size of an AudioBufferList structure
 *
 *  Use this method when doing a memcpy of AudioBufferLists, for example.
 *
 *  Note: This method returns the size of the AudioBufferList structure itself, not the
 *  audio bytes it points to.
 *
 * @param bufferList Pointer to an AudioBufferList
 * @return Size of the AudioBufferList structure
 */
static inline size_t AEAudioBufferListGetStructSize(const AudioBufferList *bufferList) {
    return sizeof(AudioBufferList) + (bufferList->mNumberBuffers-1) * sizeof(AudioBuffer);
}
    
#ifdef __cplusplus
}
#endif
