//
//  TPCircularBuffer+MultiProducer.c
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

#include "TPCircularBuffer+MultiProducer.h"
#import <mach/mach_time.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <limits.h>

bool TPMultiProducerBufferInit(TPMultiProducerBuffer *mpBuffer, int32_t length, int maxProducerCount) {
    if (maxProducerCount <= 0) return false;
    mpBuffer->maxProducerCount = maxProducerCount;
    mpBuffer->producerEntries = malloc(sizeof(*mpBuffer->producerEntries) * maxProducerCount);
    if (!mpBuffer->producerEntries) {
        return false;
    }
    // Initialize each entry.
    for (int i = 0; i < maxProducerCount; i++) {
        mpBuffer->producerEntries[i].threadId = 0;  // unclaimed
        mpBuffer->producerEntries[i].lastUse = 0;
        if (!TPCircularBufferInit(&mpBuffer->producerEntries[i].buffer, length)) {
            // Cleanup any previously initialized buffers on error.
            for (int j = 0; j < i; j++) {
                TPCircularBufferCleanup(&mpBuffer->producerEntries[j].buffer);
            }
            free(mpBuffer->producerEntries);
            mpBuffer->producerEntries = NULL;
            return false;
        }
    }
    return true;
}

void TPMultiProducerBufferCleanup(TPMultiProducerBuffer *mpBuffer) {
    if (mpBuffer->producerEntries) {
        for (int i = 0; i < mpBuffer->maxProducerCount; i++) {
            TPCircularBufferCleanup(&mpBuffer->producerEntries[i].buffer);
        }
        free(mpBuffer->producerEntries);
        memset(mpBuffer, 0, sizeof(*mpBuffer));
    }
}

TPCircularBuffer * TPMultiProducerBufferGetProducerBuffer(TPMultiProducerBuffer *mpBuffer) {
    if ( mpBuffer->maxProducerCount == 1 ) {
        // If there's only one producer, just return the buffer.
        return &mpBuffer->producerEntries[0].buffer;
    }
    
    pthread_t currentThread = pthread_self();
    uint64_t now = mach_absolute_time();
    
    // Scan the array for an entry already claimed by this thread
    for (int i = 0; i < mpBuffer->maxProducerCount; i++) {
        if (mpBuffer->producerEntries[i].threadId &&
            pthread_equal(mpBuffer->producerEntries[i].threadId, currentThread)) {
            mpBuffer->producerEntries[i].lastUse = now;
            return &mpBuffer->producerEntries[i].buffer;
        }
    }
    
    // Scan for an unclaimed entry
    int chosenIndex = -1;
    pthread_t priorOwnerThread = 0;
    for (int i = 0; i < mpBuffer->maxProducerCount; i++) {
        if (mpBuffer->producerEntries[i].threadId == 0) {
            chosenIndex = i;
            break;
        }
    }
    
    // Find the oldest entry
    int oldestIndex = -1;
    uint64_t oldestTime = UINT64_MAX;
    if ( chosenIndex == -1 ) {
        for (int i = 0; i < mpBuffer->maxProducerCount; i++) {
            if (mpBuffer->producerEntries[i].lastUse < oldestTime) {
                oldestTime = mpBuffer->producerEntries[i].lastUse;
                priorOwnerThread = mpBuffer->producerEntries[i].threadId;
                oldestIndex = i;
            }
        }
        chosenIndex = oldestIndex;
    }
    
    // Claim the entry
    if (!__sync_bool_compare_and_swap(&mpBuffer->producerEntries[chosenIndex].threadId, priorOwnerThread, currentThread)) {
        // If CAS fails, some other thread changed it—retry.
        return TPMultiProducerBufferGetProducerBuffer(mpBuffer);
    }
    mpBuffer->producerEntries[chosenIndex].lastUse = now;
    return &mpBuffer->producerEntries[chosenIndex].buffer;
}

void TPMultiProducerBufferRelinquishCircularBufferForProducerThread(TPMultiProducerBuffer *mpBuffer) {
    pthread_t currentThread = pthread_self();
    // Find any entry that belongs to the current thread and release it atomically.
    for (int i = 0; i < mpBuffer->maxProducerCount; i++) {
        if (mpBuffer->producerEntries[i].threadId &&
            pthread_equal(mpBuffer->producerEntries[i].threadId, currentThread)) {
            __sync_bool_compare_and_swap(&mpBuffer->producerEntries[i].threadId, currentThread, 0);
            break;
        }
    }
}
