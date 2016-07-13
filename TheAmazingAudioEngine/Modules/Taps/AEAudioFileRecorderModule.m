//
//  AEAudioFileRecorderModule.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 1/04/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import "AEAudioFileRecorderModule.h"
#import "AEUtilities.h"
#import "AETypes.h"
#import "AEAudioBufferListUtilities.h"
#import "AEWeakRetainingProxy.h"
#import "AEDSPUtilities.h"
#import "AEMainThreadEndpoint.h"
#import <AudioToolbox/AudioToolbox.h>
#import <libkern/OSAtomic.h>
#import <pthread.h>

@interface AEAudioFileRecorderModule () {
    ExtAudioFileRef _audioFile;
    pthread_mutex_t _audioFileMutex;
    AEHostTicks    _startTime;
    AEHostTicks    _stopTime;
    BOOL           _complete;
    UInt32         _recordedFrames;
}
@property (nonatomic, readwrite) int numberOfChannels;
@property (nonatomic, readwrite) BOOL recording;
@property (nonatomic, strong) AEMainThreadEndpoint * stopRecordingNotificationEndpoint;
@end

@implementation AEAudioFileRecorderModule

- (instancetype)initWithRenderer:(AERenderer *)renderer URL:(NSURL *)url
                            type:(AEAudioFileType)type error:(NSError **)error {
    return [self initWithRenderer:renderer URL:url type:type numberOfChannels:2 error:error];
}

- (instancetype)initWithRenderer:(AERenderer *)renderer URL:(NSURL *)url type:(AEAudioFileType)type
                numberOfChannels:(int)numberOfChannels error:(NSError **)error {
    
    if ( !(self = [super initWithRenderer:renderer]) ) return nil;
    
    if ( !(_audioFile = AEExtAudioFileCreate(url, type, self.renderer.sampleRate, numberOfChannels, error)) ) return nil;
    
    // Prime async recording
    ExtAudioFileWriteAsync(_audioFile, 0, NULL);
    
    self.processFunction = AEAudioFileRecorderModuleProcess;
    self.numberOfChannels = numberOfChannels;
    
    pthread_mutex_init(&_audioFileMutex, NULL);
    
    return self;
}

- (void)dealloc {
    if ( _audioFile ) {
        [self finishWriting];
    }
    pthread_mutex_destroy(&_audioFileMutex);
}

- (void)beginRecordingAtTime:(AEHostTicks)time {
    self.recording = YES;
    _complete = NO;
    _recordedFrames = 0;
    _startTime = time ? time : AECurrentTimeInHostTicks();
}

- (void)stopRecordingAtTime:(AEHostTicks)time completionBlock:(AEAudioFileRecorderModuleCompletionBlock)block {
    if ( time ) {
        // Stop after a delay
        __weak typeof(self) weakSelf = self;
        self.stopRecordingNotificationEndpoint = [[AEMainThreadEndpoint alloc] initWithHandler:^(const void * _Nullable data, size_t length) {
            weakSelf.stopRecordingNotificationEndpoint = nil;
            [weakSelf finishWriting];
            weakSelf.recording = NO;
            if ( block ) block();
        } bufferCapacity:32];
        
        OSMemoryBarrier();
        _stopTime = time;
    } else {
        // Stop immediately
        pthread_mutex_lock(&_audioFileMutex);
        [self finishWriting];
        self.recording = NO;
        pthread_mutex_unlock(&_audioFileMutex);
        if ( block ) {
            block();
        }
    }
}

static void AEAudioFileRecorderModuleProcess(__unsafe_unretained AEAudioFileRecorderModule * THIS,
                                        const AERenderContext * _Nonnull context) {
    
    if ( pthread_mutex_trylock(&THIS->_audioFileMutex) != 0 ) {
        return;
    }
    
    if ( !THIS->_recording || THIS->_complete ) {
        pthread_mutex_unlock(&THIS->_audioFileMutex);
        return;
    }
    
    AEHostTicks startTime = THIS->_startTime;
    AEHostTicks stopTime = THIS->_stopTime;
    
    if ( stopTime && stopTime < context->timestamp->mHostTime ) {
        THIS->_complete = YES;
        AEMainThreadEndpointSend(THIS->_stopRecordingNotificationEndpoint, NULL, 0);
        pthread_mutex_unlock(&THIS->_audioFileMutex);
        return;
    }
    
    AEHostTicks hostTimeAtBufferEnd
        = context->timestamp->mHostTime + AEHostTicksFromSeconds((double)context->frames / context->sampleRate);
    if ( startTime && startTime > hostTimeAtBufferEnd ) {
        pthread_mutex_unlock(&THIS->_audioFileMutex);
        return;
    }
    
    THIS->_startTime = 0;
    
    const AudioBufferList * abl = AEBufferStackGet(context->stack, 0);
    if ( !abl ) {
        pthread_mutex_unlock(&THIS->_audioFileMutex);
        return;
    }
    
    // Prepare buffer with the right number of channels
    AEAudioBufferListCreateOnStackWithFormat(buffer, AEAudioDescriptionWithChannelsAndRate(THIS->_numberOfChannels, 0));
    for ( int i=0; i<buffer->mNumberBuffers; i++ ) {
        buffer->mBuffers[i] = abl->mBuffers[MIN(abl->mNumberBuffers-1, i)];
    }
    if ( buffer->mNumberBuffers == 1 && abl->mNumberBuffers > 1 ) {
        // Mix down to mono
        for ( int i=1; i<abl->mNumberBuffers; i++ ) {
            AEDSPMixMono(abl->mBuffers[i].mData, buffer->mBuffers[0].mData, 1.0, 1.0, context->frames, buffer->mBuffers[0].mData);
        }
    }
    
    // Advance frames, if we have a start time mid-buffer
    UInt32 frames = context->frames;
    if ( startTime && startTime > context->timestamp->mHostTime ) {
        UInt32 advanceFrames = round(AESecondsFromHostTicks(startTime - context->timestamp->mHostTime) * context->sampleRate);
        for ( int i=0; i<buffer->mNumberBuffers; i++ ) {
            buffer->mBuffers[i].mData += AEAudioDescription.mBytesPerFrame * advanceFrames;
            buffer->mBuffers[i].mDataByteSize -= AEAudioDescription.mBytesPerFrame * advanceFrames;
        }
        frames -= advanceFrames;
    }
    
    // Truncate if we have a stop time mid-buffer
    if ( stopTime && stopTime < hostTimeAtBufferEnd ) {
        UInt32 truncateFrames = round(AESecondsFromHostTicks(hostTimeAtBufferEnd - stopTime) * context->sampleRate);
        for ( int i=0; i<buffer->mNumberBuffers; i++ ) {
            buffer->mBuffers[i].mDataByteSize -= AEAudioDescription.mBytesPerFrame * truncateFrames;
        }
        frames -= truncateFrames;
    }
    
    AECheckOSStatus(ExtAudioFileWriteAsync(THIS->_audioFile, frames, buffer), "ExtAudioFileWriteAsync");
    THIS->_recordedFrames += frames;
    
    if ( stopTime && stopTime < hostTimeAtBufferEnd ) {
        THIS->_complete = YES;
        AEMainThreadEndpointSend(THIS->_stopRecordingNotificationEndpoint, NULL, 0);
    }
    
    pthread_mutex_unlock(&THIS->_audioFileMutex);
}

- (void)finishWriting {
    AECheckOSStatus(ExtAudioFileDispose(_audioFile), "AudioFileClose");
    _audioFile = NULL;
}

@end
