//
//  AECircularBuffer.m
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

#import "AECircularBuffer.h"
#import "TPCircularBuffer+AudioBufferList.h"
#import "AETypes.h"

BOOL AECircularBufferInit(AECircularBuffer * buffer, UInt32 capacityInFrames, int channelCount, double sampleRate) {
    buffer->audioDescription = AEAudioDescriptionWithChannelsAndRate(channelCount, sampleRate);
    
    // Determine capacity in bytes
    size_t bytes = capacityInFrames * buffer->audioDescription.mBytesPerFrame * channelCount;
    
     // Increase capacity slightly to make room for metadata
    bytes += MIN(2048, bytes * 0.15);
    
    return TPCircularBufferInit(&buffer->buffer, (int32_t)bytes);
}

void AECircularBufferCleanup(AECircularBuffer *buffer) {
    TPCircularBufferCleanup(&buffer->buffer);
}

void AECircularBufferClear(AECircularBuffer *buffer) {
    TPCircularBufferClear(&buffer->buffer);
}

void AECircularBufferSetAtomic(AECircularBuffer *buffer, BOOL atomic) {
    TPCircularBufferSetAtomic(&buffer->buffer, atomic);
}

void AECircularBufferSetChannelCountAndSampleRate(AECircularBuffer * buffer,
                                                  int channelCount,
                                                  double sampleRate) {
    TPCircularBufferClear(&buffer->buffer);
    buffer->audioDescription = AEAudioDescriptionWithChannelsAndRate(channelCount, sampleRate);
}

UInt32 AECircularBufferGetAvailableSpace(AECircularBuffer *buffer) {
    return TPCircularBufferGetAvailableSpace(&buffer->buffer, &buffer->audioDescription);
}

BOOL AECircularBufferEnqueue(AECircularBuffer *buffer,
                             const AudioBufferList *bufferList,
                             const AudioTimeStamp *timestamp,
                             UInt32 frames) {
    return TPCircularBufferCopyAudioBufferList(&buffer->buffer, bufferList, timestamp, frames, &buffer->audioDescription);
}

AudioBufferList * AECircularBufferPrepareEmptyAudioBufferList(AECircularBuffer *buffer,
                                                              UInt32 frameCount,
                                                              const AudioTimeStamp *timestamp) {
    return TPCircularBufferPrepareEmptyAudioBufferListWithAudioFormat(&buffer->buffer, &buffer->audioDescription, frameCount, timestamp);
}

void AECircularBufferProduceAudioBufferList(AECircularBuffer *buffer) {
    return TPCircularBufferProduceAudioBufferList(&buffer->buffer, NULL);
}

UInt32 AECircularBufferPeek(AECircularBuffer *buffer, AudioTimeStamp *outTimestamp) {
    return TPCircularBufferPeek(&buffer->buffer, outTimestamp, &buffer->audioDescription);
}

void AECircularBufferDequeue(AECircularBuffer *buffer,
                             UInt32 *ioLengthInFrames,
                             const AudioBufferList *outputBufferList,
                             AudioTimeStamp *outTimestamp) {
    return TPCircularBufferDequeueBufferListFrames(&buffer->buffer, ioLengthInFrames, outputBufferList, outTimestamp, &buffer->audioDescription);
}

AudioBufferList * AECircularBufferNextBufferList(AECircularBuffer *buffer,
                                                 AudioTimeStamp *outTimestamp,
                                                 const AudioBufferList * lastBufferList) {
    return lastBufferList ?
        TPCircularBufferNextBufferListAfter(&buffer->buffer, lastBufferList, outTimestamp)
        : TPCircularBufferNextBufferList(&buffer->buffer, outTimestamp);
}

void AECircularBufferConsumeNextBufferList(AECircularBuffer *buffer) {
    return TPCircularBufferConsumeNextBufferList(&buffer->buffer);
}

void AECircularBufferConsumeNextBufferListPartial(AECircularBuffer *buffer, UInt32 frames) {
    return TPCircularBufferConsumeNextBufferListPartial(&buffer->buffer, frames, &buffer->audioDescription);
}
