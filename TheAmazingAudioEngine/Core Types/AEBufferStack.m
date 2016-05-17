//
//  AEBufferStack.m
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

#import "AEBufferStack.h"
#import "AETypes.h"
#import "AEDSPUtilities.h"
#import "AEUtilities.h"

const UInt32 AEBufferStackMaxFramesPerSlice = 4096;
static const int kDefaultPoolSize = 16;

typedef struct _AEBufferStackBufferLinkedList {
    void * buffer;
    struct _AEBufferStackBufferLinkedList * next;
} AEBufferStackPoolEntry;

typedef struct {
    void * bytes;
    AEBufferStackPoolEntry * free;
    AEBufferStackPoolEntry * used;
} AEBufferStackPool;

struct AEBufferStack {
    int                poolSize;
    int                maxChannelsPerBuffer;
    UInt32             frameCount;
    int                stackCount;
    AEBufferStackPool  audioPool;
    AEBufferStackPool  bufferListPool;
};

static void AEBufferStackPoolInit(AEBufferStackPool * pool, int entries, size_t bytesPerEntry);
static void AEBufferStackPoolCleanup(AEBufferStackPool * pool);
static void AEBufferStackPoolReset(AEBufferStackPool * pool);
static void * AEBufferStackPoolGetNextFreeBuffer(AEBufferStackPool * pool);
static BOOL AEBufferStackPoolFreeBuffer(AEBufferStackPool * pool, void * buffer);
static void * AEBufferStackPoolGetUsedBufferAtIndex(const AEBufferStackPool * pool, int index);
static void AEBufferStackSwapTopTwoUsedBuffers(AEBufferStackPool * pool);

AEBufferStack * AEBufferStackNew(int poolSize) {
    return AEBufferStackNewWithOptions(poolSize, 2, 0);
}

AEBufferStack * AEBufferStackNewWithOptions(int poolSize, int maxChannelsPerBuffer, int numberOfSingleChannelBuffers) {
    if ( !poolSize ) poolSize = kDefaultPoolSize;
    if ( !numberOfSingleChannelBuffers ) numberOfSingleChannelBuffers = poolSize * maxChannelsPerBuffer;
    
    AEBufferStack * stack = (AEBufferStack*)calloc(1, sizeof(AEBufferStack));
    stack->poolSize = poolSize;
    stack->maxChannelsPerBuffer = maxChannelsPerBuffer;
    stack->frameCount = AEBufferStackMaxFramesPerSlice;
    
    size_t bytesPerBufferChannel = AEBufferStackMaxFramesPerSlice * AEAudioDescription.mBytesPerFrame;
    AEBufferStackPoolInit(&stack->audioPool, numberOfSingleChannelBuffers, bytesPerBufferChannel);
    
    size_t bytesPerBufferListEntry = sizeof(AudioBufferList) + ((maxChannelsPerBuffer-1) * sizeof(AudioBuffer));
    AEBufferStackPoolInit(&stack->bufferListPool, poolSize, bytesPerBufferListEntry);
    
    return stack;
}

void AEBufferStackFree(AEBufferStack * stack) {
    AEBufferStackPoolCleanup(&stack->audioPool);
    AEBufferStackPoolCleanup(&stack->bufferListPool);
    free(stack);
}

void AEBufferStackSetFrameCount(AEBufferStack * stack, UInt32 frameCount) {
    assert(frameCount <= AEBufferStackMaxFramesPerSlice);
    stack->frameCount = frameCount;
}

UInt32 AEBufferStackGetFrameCount(const AEBufferStack * stack) {
    return stack->frameCount;
}

int AEBufferStackGetPoolSize(const AEBufferStack * stack) {
    return stack->poolSize;
}

int AEBufferStackGetMaximumChannelsPerBuffer(const AEBufferStack * stack) {
    return stack->maxChannelsPerBuffer;
}

int AEBufferStackCount(const AEBufferStack * stack) {
    return stack->stackCount;
}

const AudioBufferList * AEBufferStackGet(const AEBufferStack * stack, int index) {
    if ( index >= stack->stackCount ) return NULL;
    return (const AudioBufferList*)AEBufferStackPoolGetUsedBufferAtIndex(&stack->bufferListPool, index);
}

const AudioBufferList * AEBufferStackPush(AEBufferStack * stack, int count) {
    return AEBufferStackPushWithChannels(stack, count, 2);
}

#ifdef DEBUG
static void AEBufferStackPushFailed() {}
#endif

const AudioBufferList * AEBufferStackPushWithChannels(AEBufferStack * stack, int count, int channelCount) {
    assert(channelCount > 0);
    if ( stack->stackCount+count > stack->poolSize ) {
#ifdef DEBUG
        if ( AERateLimit() )
            printf("Couldn't push a buffer. Add a breakpoint on AEBufferStackPushFailed to debug.\n");
        AEBufferStackPushFailed();
#endif
        return NULL;
    }
    
    if ( channelCount > stack->maxChannelsPerBuffer ) {
#ifdef DEBUG
        if ( AERateLimit() )
            printf("Tried to push a buffer with too many channels. Add a breakpoint on AEBufferStackPushFailed to debug.\n");
        AEBufferStackPushFailed();
#endif
        return NULL;
    }
    
    size_t sizePerBuffer = stack->frameCount * AEAudioDescription.mBytesPerFrame;
    AudioBufferList * first = NULL;
    for ( int j=0; j<count; j++ ) {
        AudioBufferList * buffer = (AudioBufferList *)AEBufferStackPoolGetNextFreeBuffer(&stack->bufferListPool);
        assert(buffer);
        if ( !first ) first = buffer;
        
        buffer->mNumberBuffers = channelCount;
        for ( int i=0; i<channelCount; i++ ) {
            buffer->mBuffers[i].mNumberChannels = 1;
            buffer->mBuffers[i].mDataByteSize = (UInt32)sizePerBuffer;
            buffer->mBuffers[i].mData = AEBufferStackPoolGetNextFreeBuffer(&stack->audioPool);
            assert(buffer->mBuffers[i].mData);
        }
        stack->stackCount++;
    }
    
    return first;
}

const AudioBufferList * AEBufferStackPushExternal(AEBufferStack * stack, const AudioBufferList * buffer) {
    
    assert(buffer->mNumberBuffers > 0);
    if ( stack->stackCount+1 > stack->poolSize ) {
#ifdef DEBUG
        if ( AERateLimit() )
            printf("Couldn't push a buffer. Add a breakpoint on AEBufferStackPushFailed to debug.\n");
        AEBufferStackPushFailed();
#endif
        return NULL;
    }
    
    if ( buffer->mNumberBuffers > stack->maxChannelsPerBuffer ) {
#ifdef DEBUG
        if ( AERateLimit() )
            printf("Tried to push a buffer with too many channels. Add a breakpoint on AEBufferStackPushFailed to debug.\n");
        AEBufferStackPushFailed();
#endif
        return NULL;
    }
    
#ifdef DEBUG
    if ( buffer->mBuffers[0].mDataByteSize < stack->frameCount * AEAudioDescription.mBytesPerFrame ) {
        if ( AERateLimit() )
            printf("Warning: Pushed a buffer with %d frames < %d\n",
                   buffer->mBuffers[0].mDataByteSize / AEAudioDescription.mBytesPerFrame,
                   stack->frameCount);
    }
#endif
    
    AudioBufferList * newBuffer
        = (AudioBufferList *)AEBufferStackPoolGetNextFreeBuffer(&stack->bufferListPool);
    assert(newBuffer);
    memcpy(newBuffer, buffer, AEAudioBufferListGetStructSize(buffer));
    
    stack->stackCount++;
    
    return newBuffer;
}

const AudioBufferList * AEBufferStackDuplicate(AEBufferStack * stack) {
    const AudioBufferList * top = AEBufferStackGet(stack, 0);
    if ( !top ) return NULL;
    
    const AudioBufferList * duplicate = AEBufferStackPushWithChannels(stack, 1, top->mNumberBuffers);
    if ( !duplicate ) return NULL;
    
    for ( int i=0; i<duplicate->mNumberBuffers; i++ ) {
        memcpy(duplicate->mBuffers[i].mData, top->mBuffers[i].mData, duplicate->mBuffers[i].mDataByteSize);
    }
    
    return duplicate;
}

void AEBufferStackSwap(AEBufferStack * stack) {
    AEBufferStackSwapTopTwoUsedBuffers(&stack->bufferListPool);
}

void AEBufferStackPop(AEBufferStack * stack, int count) {
    count = MIN(count, stack->stackCount);
    if ( count == 0 ) {
        return;
    }
    for ( int i=0; i<count; i++ ) {
        AEBufferStackRemove(stack, 0);
    }
}

void AEBufferStackRemove(AEBufferStack * stack, int index) {
    AudioBufferList * buffer = (AudioBufferList *)AEBufferStackPoolGetUsedBufferAtIndex(&stack->bufferListPool, index);
    if ( !buffer ) {
        return;
    }
    for ( int j=buffer->mNumberBuffers-1; j >= 0; j-- ) {
        // Free buffers in reverse order, so that they're in correct order if we push again
        AEBufferStackPoolFreeBuffer(&stack->audioPool, buffer->mBuffers[j].mData);
    }
    AEBufferStackPoolFreeBuffer(&stack->bufferListPool, buffer);
    stack->stackCount--;
}

const AudioBufferList * AEBufferStackMix(AEBufferStack * stack, int count) {
    return AEBufferStackMixWithGain(stack, count, NULL);
}

const AudioBufferList * AEBufferStackMixWithGain(AEBufferStack * stack, int count, const float * gains) {
    if ( count != 0 && count < 2 ) return NULL;
    
    for ( int i=1; count ? i<count : 1; i++ ) {
        const AudioBufferList * abl1 = AEBufferStackGet(stack, 0);
        const AudioBufferList * abl2 = AEBufferStackGet(stack, 1);
        if ( !abl1 || !abl2 ) return AEBufferStackGet(stack, 0);
        
        float abl1Gain = i == 1 && gains ? gains[0] : 1.0;
        float abl2Gain = gains ? gains[i] : 1.0;
        
        if ( abl2->mNumberBuffers < abl1->mNumberBuffers ) {
            // Swap abl1 and abl2, so that we're writing into the buffer with more channels
            AEBufferStackSwap(stack);
            abl1 = AEBufferStackGet(stack, 0);
            abl2 = AEBufferStackGet(stack, 1);
            float tmp = abl2Gain;
            abl2Gain = abl1Gain;
            abl1Gain = tmp;
        }
        
        AEBufferStackPop(stack, 1);

        if ( i == 1 ) {
            AEDSPApplyGain(abl1, abl1Gain, stack->frameCount);
        }
        
        AEDSPMix(abl1, abl2, 1, abl2Gain, YES, stack->frameCount, abl2);
    }
    
    return AEBufferStackGet(stack, 0);
}

void AEBufferStackApplyVolumeAndBalance(AEBufferStack * stack,
                                        float targetVolume, float * currentVolume,
                                        float targetBalance, float * currentBalance) {
    const AudioBufferList * abl = AEBufferStackGet(stack, 0);
    if ( !abl ) return;
    
    if ( fabsf(targetBalance) > FLT_EPSILON && abl->mNumberBuffers == 1 ) {
        // Make mono buffer stereo
        AEBufferStackPop(stack, 1);
        abl = AEBufferStackPushWithChannels(stack, 1, 2);
        if ( !abl ) {
            // Restore prior buffer and bail
            AEBufferStackPushWithChannels(stack, 1, 1);
            return;
        }
        memcpy(abl->mBuffers[1].mData, abl->mBuffers[0].mData, abl->mBuffers[1].mDataByteSize);
    }
    
    AEDSPApplyVolumeAndBalance(abl, targetVolume, currentVolume, targetBalance, currentBalance, stack->frameCount);
}

void AEBufferStackSilence(AEBufferStack * stack) {
    const AudioBufferList * abl = AEBufferStackGet(stack, 0);
    if ( !abl ) return;
    AEAudioBufferListSilence(abl, 0, stack->frameCount);
}

void AEBufferStackMixToBufferList(AEBufferStack * stack, int bufferCount, const AudioBufferList * output) {
    // Mix stack items
    for ( int i=0; bufferCount ? i<bufferCount : 1; i++ ) {
        const AudioBufferList * abl = AEBufferStackGet(stack, i);
        if ( !abl ) return;
        AEDSPMix(abl, output, 1, 1, YES, stack->frameCount, output);
    }
}

void AEBufferStackMixToBufferListChannels(AEBufferStack * stack, int bufferCount, AEChannelSet channels, const AudioBufferList * output) {
    
    // Setup output buffer
    AEAudioBufferListCopyOnStackWithChannelSubset(outputBuffer, output, channels);
    
    // Mix stack items
    for ( int i=0; bufferCount ? i<bufferCount : 1; i++ ) {
        const AudioBufferList * abl = AEBufferStackGet(stack, i);
        if ( !abl ) return;
        AEDSPMix(abl, outputBuffer, 1, 1, YES, stack->frameCount, outputBuffer);
    }
}

void AEBufferStackReset(AEBufferStack * stack) {
    AEBufferStackPoolReset(&stack->audioPool);
    AEBufferStackPoolReset(&stack->bufferListPool);
    stack->stackCount = 0;
}

#pragma mark - Helpers

static void AEBufferStackPoolInit(AEBufferStackPool * pool, int entries, size_t bytesPerEntry) {
    pool->bytes = malloc(entries * bytesPerEntry);
    pool->used = NULL;
    
    AEBufferStackPoolEntry ** nextPtr = &pool->free;
    for ( int i=0; i<entries; i++ ){
        AEBufferStackPoolEntry * entry = (AEBufferStackPoolEntry*)calloc(1, sizeof(AEBufferStackPoolEntry));
        entry->buffer = pool->bytes + (i * bytesPerEntry);
        *nextPtr = entry;
        nextPtr = &entry->next;
    }
}

static void AEBufferStackPoolCleanup(AEBufferStackPool * pool) {
    while ( pool->free ) {
        AEBufferStackPoolEntry * next = pool->free->next;
        free(pool->free);
        pool->free = next;
    }
    while ( pool->used ) {
        AEBufferStackPoolEntry * next = pool->used->next;
        free(pool->used);
        pool->used = next;
    }
    free(pool->bytes);
}

static void AEBufferStackPoolReset(AEBufferStackPool * pool) {
    // Return all used buffers back to the free list
    AEBufferStackPoolEntry * entry = pool->used;
    while ( entry ) {
        // Point top entry at beginning of free list, and point free list to top entry (i.e. insert into free list)
        AEBufferStackPoolEntry * next = entry->next;
        entry->next = pool->free;
        pool->free = entry;
        
        entry = next;
    }
    
    pool->used = NULL;
}

static void * AEBufferStackPoolGetNextFreeBuffer(AEBufferStackPool * pool) {
    // Get entry at top of free list
    AEBufferStackPoolEntry * entry = pool->free;
    if ( !entry ) return NULL;
    
    // Point free list at next entry (i.e. remove the top entry from the list)
    pool->free = entry->next;
    
    // Point top entry at beginning of used list, and point used list to top entry (i.e. insert into used list)
    entry->next = pool->used;
    pool->used = entry;
    
    return entry->buffer;
}

static BOOL AEBufferStackPoolFreeBuffer(AEBufferStackPool * pool, void * buffer) {
    
    AEBufferStackPoolEntry * entry = NULL;
    if ( pool->used && pool->used->buffer == buffer ) {
        // Found the corresponding entry at the top. Remove it from the used list.
        entry = pool->used;
        pool->used = entry->next;
        
    } else {
        // Find it in the list, and note the preceding item
        AEBufferStackPoolEntry * preceding = pool->used;
        while ( preceding && preceding->next && preceding->next->buffer != buffer ) {
            preceding = preceding->next;
        }
        if ( preceding && preceding->next ) {
            // Found it. Remove it from the list
            entry = preceding->next;
            preceding->next = entry->next;
        }
    }
    
    if ( !entry ) {
        return NO;
    }
    
    // Point top entry at beginning of free list, and point free list to top entry (i.e. insert into free list)
    entry->next = pool->free;
    pool->free = entry;
    
    return YES;
}

static void * AEBufferStackPoolGetUsedBufferAtIndex(const AEBufferStackPool * pool, int index) {
    AEBufferStackPoolEntry * entry = pool->used;
    for ( int i=0; i<index && entry; i++ ) {
        entry = entry->next;
    }
    return entry ? entry->buffer : NULL;
}

static void AEBufferStackSwapTopTwoUsedBuffers(AEBufferStackPool * pool) {
    AEBufferStackPoolEntry * entry = pool->used;
    if ( !entry ) return;
    AEBufferStackPoolEntry * next = entry->next;
    if ( !next ) return;
    
    entry->next = next->next;
    next->next = entry;
    pool->used = next;
}
