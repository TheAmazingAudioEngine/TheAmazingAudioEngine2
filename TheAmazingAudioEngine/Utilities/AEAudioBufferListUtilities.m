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
#import "AEUtilities.h"

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

AudioBufferList *AEAudioBufferListCreateWithContentsOfFile(NSString * filePath, AudioStreamBasicDescription audioFormat) {
    AudioStreamBasicDescription fileFormat;
    UInt64 length;
    NSError * error = nil;
    ExtAudioFileRef audioFile = AEExtAudioFileOpen([NSURL fileURLWithPath:filePath], &fileFormat, &length, &error);
    
    if ( !audioFile ) {
        NSLog(@"Unable to open %@ for reading: %@", filePath, error.localizedDescription);
        return NULL;
    }
    
    if ( !audioFormat.mSampleRate ) audioFormat.mSampleRate = fileFormat.mSampleRate;
    
    if ( !AECheckOSStatus(ExtAudioFileSetProperty(audioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(audioFormat), &audioFormat),
                          "ExtAudioFileSetProperty") ) {
        ExtAudioFileDispose(audioFile);
        return NULL;
    }
    
    UInt32 lengthAtTargetRate = (UInt32)floor(((double)length / fileFormat.mSampleRate) * audioFormat.mSampleRate);
    AudioBufferList * output = AEAudioBufferListCreateWithFormat(audioFormat, lengthAtTargetRate);
    
    UInt32 blockSize = 4096;
    UInt32 remaining = lengthAtTargetRate;
    UInt32 readFrames = 0;
    while ( remaining > 0 ) {
        UInt32 block = MIN(blockSize, remaining);
        AEAudioBufferListCopyOnStackWithByteOffset(target, output, (readFrames * audioFormat.mBytesPerFrame));
        AEAudioBufferListSetLength(target, block);
        if ( !AECheckOSStatus(ExtAudioFileRead(audioFile, &block, target), "ExtAudioFileRead") || block == 0 ) {
            break;
        }
        readFrames += block;
        remaining -= block;
    }
    
    ExtAudioFileDispose(audioFile);
    
    AEAudioBufferListSetLength(output, readFrames);
    return output;
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
               length * audioFormat.mBytesPerFrame);
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

    for ( int i=0; i<target->mNumberBuffers; i++ ) {
        int sourceBuffer = i;
        if ( sourceBuffer >= source->mNumberBuffers ) {
            if ( i > 2 ) break;
            sourceBuffer = source->mNumberBuffers-1;
        }
        
        memcpy(target->mBuffers[i].mData + (targetOffset * audioFormat.mBytesPerFrame),
               source->mBuffers[sourceBuffer].mData + (sourceOffset * audioFormat.mBytesPerFrame),
               length * audioFormat.mBytesPerFrame);
    }
}

BOOL AEAudioBufferListIsSilent(const AudioBufferList *bufferList) {
    for ( int i=0; i<bufferList->mNumberBuffers; i++ ) {
        float * samples = (float *)bufferList->mBuffers[i].mData;
        UInt32 length = bufferList->mBuffers[i].mDataByteSize / sizeof(float);
        if ( length == 0 ) continue;
        
        if ( samples[0] != 0.0f ) return NO;
        if ( samples[length-1] != 0.0f ) return NO;
        if ( samples[(length-1)/2] != 0.0f ) return NO;
        for ( int j=1; j<length-2; j++ ) {
            if ( samples[j] != 0.0f ) return NO;
        }
    }
    return YES;
}
