//
//  TPCircularBuffer+MultiProducer.h
//  Circular/Ring buffer implementation
//
//  https://github.com/michaeltyson/TPCircularBuffer
//
//  Created by Michael Tyson on 26/02/2025.
//
//  Copyright (C) 2025 A Tasty Pixel
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

#ifndef TPCircularBuffer_MultiProducer_h
#define TPCircularBuffer_MultiProducer_h

#ifdef __cplusplus
extern "C" {
#endif

#include "TPCircularBuffer.h"
#include <pthread.h>

typedef struct {
    int maxProducerCount;           // Maximum number of producers
    struct {
        pthread_t threadId;         // The thread that owns this buffer (zero if unclaimed)
        TPCircularBuffer buffer;    // The circular buffer for that thread
        uint64_t lastUse;           // Timestamp (in ticks) when this buffer was last used
    } * producerEntries;
} TPMultiProducerBuffer;

/*!
 * Initialize a multi-producer buffer
 *
 * @param mpBuffer The buffer to initialize
 * @param length The length of each circular buffer
 * @param maxProducerCount The maximum number of producers
 * @return true if successful, false if insufficient memory
 */
bool TPMultiProducerBufferInit(TPMultiProducerBuffer * mpBuffer, int32_t length, int maxProducerCount);

/*!
 * Free resources
 *
 * @param mpBuffer The buffer to clean up
 */
void TPMultiProducerBufferCleanup(TPMultiProducerBuffer * mpBuffer);

/*!
 * Get a TPCircularBuffer for the current thread
 *
 *  This will either return the buffer for the current thread, or claim a new buffer if the thread count is not exceeded.
 *  It will be reserved for the current thread until TPMultiProducerBufferRelinquishCircularBufferForProducerThread is called,
 *  or another thread claims it if it has been unused for a while and the active thread count is exceeded.
 *
 * @param mpBuffer The buffer
 * @return The circular buffer for the current thread
 */
TPCircularBuffer * TPMultiProducerBufferGetProducerBuffer(TPMultiProducerBuffer * mpBuffer);

/*!
 * Relinquish the buffer for the current thread
 *
 *  This should be called after you no longer need the circular buffer for the current thread.
 *  This will allow another thread to claim the buffer.
 *
 * @param mpBuffer The buffer
 */
void TPMultiProducerBufferRelinquishCircularBufferForProducerThread(TPMultiProducerBuffer * mpBuffer);

/*!
 * A macro that can be used by a consumer to iterate over all producer buffers
 *
 *  Example usage:
 *    TPCircularBuffer * buffer;
 *    TPMultiProducerBufferIterateBuffers(&THIS->_multiProducerBuffer, buffer) {
 *     ...
 *    }
 *
 * @param mpBuffer The buffer
 * @param circularBuffer A TPCircularBuffer pointer that will be set to each buffer in turn
 */
#define TPMultiProducerBufferIterateBuffers(mpBuffer, circularBufferVariableName) \
    for (int __producerIndex = 0; __producerIndex < (mpBuffer)->maxProducerCount; __producerIndex++) \
        if ((circularBufferVariableName = &((mpBuffer)->producerEntries[__producerIndex].buffer))) \


#ifdef __cplusplus
}
#endif

#endif
