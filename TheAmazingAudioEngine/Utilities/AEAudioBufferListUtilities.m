//
//  AEAudioBufferListUtilities.m
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

#import "AEAudioBufferListUtilities.h"

AudioBufferList *AEAudioBufferListCreate(int frameCount) {
    return AEAudioBufferListCreateWithFormat(AEAudioDescription, frameCount);
}

AudioBufferList *AEAudioBufferListCreateWithFormat(AudioStreamBasicDescription audioFormat, int frameCount) {
    int numberOfBuffers = audioFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved ? audioFormat.mChannelsPerFrame : 1;
    int channelsPerBuffer = audioFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved ? 1 : audioFormat.mChannelsPerFrame;
    int bytesPerBuffer = audioFormat.mBytesPerFrame * frameCount;
    
    AudioBufferList *audio = malloc(sizeof(AudioBufferList) + (numberOfBuffers-1)*sizeof(AudioBuffer));
    if ( !audio ) {
        return NULL;
    }
    audio->mNumberBuffers = numberOfBuffers;
    for ( int i=0; i<numberOfBuffers; i++ ) {
        if ( bytesPerBuffer > 0 ) {
            audio->mBuffers[i].mData = calloc(bytesPerBuffer, 1);
            if ( !audio->mBuffers[i].mData ) {
                for ( int j=0; j<i; j++ ) free(audio->mBuffers[j].mData);
                free(audio);
                return NULL;
            }
        } else {
            audio->mBuffers[i].mData = NULL;
        }
        audio->mBuffers[i].mDataByteSize = bytesPerBuffer;
        audio->mBuffers[i].mNumberChannels = channelsPerBuffer;
    }
    return audio;
}

AudioBufferList *AEAudioBufferListCopy(const AudioBufferList *original) {
    AudioBufferList *audio = malloc(sizeof(AudioBufferList) + (original->mNumberBuffers-1)*sizeof(AudioBuffer));
    if ( !audio ) {
        return NULL;
    }
    audio->mNumberBuffers = original->mNumberBuffers;
    for ( int i=0; i<original->mNumberBuffers; i++ ) {
        audio->mBuffers[i].mData = malloc(original->mBuffers[i].mDataByteSize);
        if ( !audio->mBuffers[i].mData ) {
            for ( int j=0; j<i; j++ ) free(audio->mBuffers[j].mData);
            free(audio);
            return NULL;
        }
        audio->mBuffers[i].mDataByteSize = original->mBuffers[i].mDataByteSize;
        audio->mBuffers[i].mNumberChannels = original->mBuffers[i].mNumberChannels;
        memcpy(audio->mBuffers[i].mData, original->mBuffers[i].mData, original->mBuffers[i].mDataByteSize);
    }
    return audio;
}

void AEAudioBufferListFree(AudioBufferList *bufferList ) {
    for ( int i=0; i<bufferList->mNumberBuffers; i++ ) {
        if ( bufferList->mBuffers[i].mData ) free(bufferList->mBuffers[i].mData);
    }
    free(bufferList);
}

UInt32 AEAudioBufferListGetLength(const AudioBufferList *bufferList, int *oNumberOfChannels) {
    return AEAudioBufferListGetLengthWithFormat(bufferList, AEAudioDescription, oNumberOfChannels);
}

UInt32 AEAudioBufferListGetLengthWithFormat(const AudioBufferList *bufferList,
                                            AudioStreamBasicDescription audioFormat,
                                            int *oNumberOfChannels) {
    if ( oNumberOfChannels ) {
        *oNumberOfChannels = audioFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved
            ? bufferList->mNumberBuffers : bufferList->mBuffers[0].mNumberChannels;
    }
    return bufferList->mBuffers[0].mDataByteSize / audioFormat.mBytesPerFrame;
}

void AEAudioBufferListSetLength(AudioBufferList *bufferList, UInt32 frames) {
    return AEAudioBufferListSetLengthWithFormat(bufferList, AEAudioDescription, frames);
}

void AEAudioBufferListSetLengthWithFormat(AudioBufferList *bufferList,
                                          AudioStreamBasicDescription audioFormat,
                                          UInt32 frames) {
    for ( int i=0; i<bufferList->mNumberBuffers; i++ ) {
        bufferList->mBuffers[i].mDataByteSize = frames * audioFormat.mBytesPerFrame;
    }
}

void AEAudioBufferListOffset(AudioBufferList *bufferList, UInt32 frames) {
    return AEAudioBufferListOffsetWithFormat(bufferList, AEAudioDescription, frames);
}

void AEAudioBufferListOffsetWithFormat(AudioBufferList *bufferList,
                                       AudioStreamBasicDescription audioFormat,
                                       UInt32 frames) {
    for ( int i=0; i<bufferList->mNumberBuffers; i++ ) {
        bufferList->mBuffers[i].mData = (char*)bufferList->mBuffers[i].mData + frames * audioFormat.mBytesPerFrame;
        bufferList->mBuffers[i].mDataByteSize -= frames * audioFormat.mBytesPerFrame;
    }
}

void AEAudioBufferListAssign(AudioBufferList * target, const AudioBufferList * source, UInt32 offset, UInt32 length) {
    AEAudioBufferListAssignWithFormat(target, source, AEAudioDescription, offset, length);
}

void AEAudioBufferListAssignWithFormat(AudioBufferList * target, const AudioBufferList * source,
                                       AudioStreamBasicDescription audioFormat, UInt32 offset, UInt32 length) {
    target->mNumberBuffers = source->mNumberBuffers;
    for ( int i=0; i<source->mNumberBuffers; i++ ) {
        target->mBuffers[i].mNumberChannels = source->mBuffers[i].mNumberChannels;
        target->mBuffers[i].mData = source->mBuffers[i].mData + (offset * audioFormat.mBytesPerFrame);
        target->mBuffers[i].mDataByteSize = length * audioFormat.mBytesPerFrame;
    }
}

void AEAudioBufferListSilence(const AudioBufferList *bufferList, UInt32 offset, UInt32 length) {
    return AEAudioBufferListSilenceWithFormat(bufferList, AEAudioDescription, offset, length);
}

void AEAudioBufferListSilenceWithFormat(const AudioBufferList *bufferList,
                                        AudioStreamBasicDescription audioFormat,
                                        UInt32 offset,
                                        UInt32 length) {
    for ( int i=0; i<bufferList->mNumberBuffers; i++ ) {
        memset((char*)bufferList->mBuffers[i].mData + offset * audioFormat.mBytesPerFrame,
               0,
               length ? (length * audioFormat.mBytesPerFrame)
                      : (bufferList->mBuffers[i].mDataByteSize - offset * audioFormat.mBytesPerFrame));
    }
}

void AEAudioBufferListCopyContents(const AudioBufferList * target,
                                   const AudioBufferList * source,
                                   UInt32 targetOffset,
                                   UInt32 sourceOffset,
                                   UInt32 length) {
    AEAudioBufferListCopyContentsWithFormat(target, source, AEAudioDescription, targetOffset, sourceOffset, length);
}

void AEAudioBufferListCopyContentsWithFormat(const AudioBufferList * target,
                                             const AudioBufferList * source,
                                             AudioStreamBasicDescription audioFormat,
                                             UInt32 targetOffset,
                                             UInt32 sourceOffset,
                                             UInt32 length) {
    for ( int i=0; i<MIN(target->mNumberBuffers, source->mNumberBuffers); i++ ) {
        memcpy(target->mBuffers[i].mData + (targetOffset * audioFormat.mBytesPerFrame),
               source->mBuffers[i].mData + (sourceOffset * audioFormat.mBytesPerFrame),
               length ? (length * audioFormat.mBytesPerFrame)
                      : (MIN(target->mBuffers[i].mDataByteSize - targetOffset * audioFormat.mBytesPerFrame,
                             source->mBuffers[i].mDataByteSize - sourceOffset * audioFormat.mBytesPerFrame)));
    }
}
