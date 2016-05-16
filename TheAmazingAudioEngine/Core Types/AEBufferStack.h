//
//  AEBufferStack.h
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 23/03/2016.
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

@import Foundation;
@import AudioToolbox;
#import "AETypes.h"

extern const UInt32 AEBufferStackMaxFramesPerSlice;

typedef struct AEBufferStack AEBufferStack;

/*!
 * Initialize a new buffer stack
 *
 * @param poolSize The number of audio buffer lists to make room for in the buffer pool, or 0 for default value
 * @return The new buffer stack
 */
AEBufferStack * AEBufferStackNew(int poolSize);

/*!
 * Initialize a new buffer stack, supplying additional options
 *
 * @param poolSize The number of audio buffer lists to make room for in the buffer pool, or 0 for default value
 * @param maxChannelsPerBuffer The maximum number of audio channels for each buffer (default 2)
 * @param numberOfSingleChannelBuffers Number of mono float buffers to allocate (or 0 for default: poolSize*maxChannelsPerBuffer)
 * @return The new buffer stack
 */
AEBufferStack * AEBufferStackNewWithOptions(int poolSize, int maxChannelsPerBuffer, int numberOfSingleChannelBuffers);

/*!
 * Clean up a buffer stack
 *
 * @param stack The stack
 */
void AEBufferStackFree(AEBufferStack * stack);

/*!
 * Set current frame count per buffer
 *
 * @param stack The stack
 * @param frameCount The number of frames for newly-pushed buffers
 */
void AEBufferStackSetFrameCount(AEBufferStack * stack, UInt32 frameCount);

/*!
 * Get the current frame count per buffer
 *
 * @param stack The stack
 * @return The current frame count for newly-pushed buffers
 */
UInt32 AEBufferStackGetFrameCount(const AEBufferStack * stack);

/*!
 * Get the pool size
 *
 * @param stack The stack
 * @return The current pool size
 */
int AEBufferStackGetPoolSize(const AEBufferStack * stack);

/*!
 * Get the maximum number of channels per buffer
 *
 * @param stack The stack
 * @return The maximum number of channels per buffer
 */
int AEBufferStackGetMaximumChannelsPerBuffer(const AEBufferStack * stack);

/*!
 * Get the current stack count
 *
 * @param stack The stack
 * @return Number of buffers currently on stack
 */
int AEBufferStackCount(const AEBufferStack * stack);

/*!
 * Get a buffer
 *
 * @param stack The stack
 * @param index The buffer index
 * @return The buffer at the given index (0 is the top of the stack: the most recently pushed buffer)
 */
const AudioBufferList * AEBufferStackGet(const AEBufferStack * stack, int index);

/*!
 * Push one or more new buffers onto the stack
 *
 *  Note that a buffer that has been pushed immediately after a pop points to the same data -
 *  essentially, this is a no-op. If a buffer is pushed immediately after a pop with more
 *  channels, then the first channels up to the prior channel count point to the same data,
 *  and later channels point to new buffers.
 *
 * @param stack The stack
 * @param count Number of buffers to push
 * @return The first new buffer
 */
const AudioBufferList * AEBufferStackPush(AEBufferStack * stack, int count);

/*!
 * Push one or more new buffers onto the stack
 *
 *  Note that a buffer that has been pushed immediately after a pop points to the same data -
 *  essentially, this is a no-op. If a buffer is pushed immediately after a pop with more
 *  channels, then the first channels up to the prior channel count point to the same data,
 *  and later channels point to new buffers.
 *
 * @param stack The stack
 * @param count Number of buffers to push
 * @param channelCount Number of channels of audio for each buffer
 * @return The first new buffer
 */
const AudioBufferList * AEBufferStackPushWithChannels(AEBufferStack * stack, int count, int channelCount);

/*!
 * Duplicate the top buffer on the stack
 *
 *  Pushes a new buffer onto the stack which is a copy of the prior buffer.
 *
 * @param stack The stack
 * @return The duplicated buffer
 */
const AudioBufferList * AEBufferStackDuplicate(AEBufferStack * stack);

/*!
 * Swap the top two stack items
 *
 * @param stack The stack
 */
void AEBufferStackSwap(AEBufferStack * stack);

/*!
 * Pop one or more buffers from the stack
 *
 *  The popped buffer remains valid until another buffer is pushed. A newly pushed buffer
 *  will use the same memory regions as the old one, and thus a pop followed by a push is
 *  essentially a no-op, given the same number of channels in each.
 *
 * @param stack The stack
 * @param count Number of buffers to pop, or 0 for all
 */
void AEBufferStackPop(AEBufferStack * stack, int count);

/*!
 * Remove a buffer from the stack
 *
 *  Remove an indexed buffer from within the stack. This has the same behaviour as AEBufferStackPop,
 *  in that a removal followed by a push results in a buffer pointing to the same memory.
 *
 * @param stack The stack
 * @param index The buffer index
 */
void AEBufferStackRemove(AEBufferStack * stack, int index);

/*!
 * Mix two or more buffers together
 *
 *  Pops the given number of buffers from the stack, and pushes a buffer with these mixed together.
 *
 *  When mixing a mono buffer and a stereo buffer, the mono buffer's channels will be duplicated.
 *
 * @param stack The stack
 * @param count Number of buffers to mix
 * @return The resulting buffer
 */
const AudioBufferList * AEBufferStackMix(AEBufferStack * stack, int count);

/*!
 * Mix two or more buffers together, with individual mix factors by which to scale each buffer
 *
 * @param stack The stack
 * @param count Number of buffers to mix
 * @param gains The gain factors (power ratio) for each buffer. You must provide 'count' values
 * @return The resulting buffer
 */
const AudioBufferList * AEBufferStackMixWithGain(AEBufferStack * stack, int count, const float * gains);

/*!
 * Apply volume and balance controls to the top buffer
 *
 *  This function applies gains to the given buffer to affect volume and balance, with a smoothing ramp
 *  applied to avoid discontinuities. If the buffer is mono, and the balance is non-zero, the buffer will
 *  be made stereo instead.
 *
 * @param stack The stack
 * @param targetVolume The target volume (power ratio)
 * @param currentVolume On input, the current volume; on output, the new volume. Store this and pass it
 *  back to this function on successive calls for a smooth ramp. If NULL, no smoothing will be applied.
 * @param targetBalance The target balance
 * @param currentBalance On input, the current balance; on output, the new balance. Store this and pass it
 *  back to this function on successive calls for a smooth ramp. If NULL, no smoothing will be applied.
 */
void AEBufferStackApplyVolumeAndBalance(AEBufferStack * stack,
                                        float targetVolume, float * currentVolume,
                                        float targetBalance, float * currentBalance);

/*!
 * Silence the top buffer
 *
 *  This function zereos out all samples in the topmost buffer.
 *
 * @param stack The stack
 */
void AEBufferStackSilence(AEBufferStack * stack);

/*!
 * Mix stack items onto an AudioBufferList
 *
 *  The given number of stack items will mixed into the buffer list.
 *
 * @param stack The stack
 * @param bufferCount Number of buffers to process, or 0 for all
 * @param output The output buffer list
 */
void AEBufferStackMixToBufferList(AEBufferStack * stack, int bufferCount, const AudioBufferList * output);

/*!
 * Mix stack items onto an AudioBufferList, with specific channel configuration
 *
 *  The given number of stack items will mixed into the buffer list.
 *
 * @param stack The stack
 * @param bufferCount Number of buffers to process, or 0 for all
 * @param channels The set of channels to output to. If stereo, any mono inputs will be doubled to stereo.
 *      If mono, any stereo inputs will be mixed down.
 * @param output The output buffer list
 */
void AEBufferStackMixToBufferListChannels(AEBufferStack * stack,
                                          int bufferCount,
                                          AEChannelSet channels,
                                          const AudioBufferList * output);

/*!
 * Reset the stack
 *
 *  This pops all items until the stack is empty
 *
 * @param stack The stack
 */
void AEBufferStackReset(AEBufferStack * stack);
#ifdef __cplusplus
}
#endif
