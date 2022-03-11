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
#import <stdatomic.h>
#import <os/lock.h>

@interface AEAudioFileRecorderModule () {
    ExtAudioFileRef _audioFile;
    os_unfair_lock  _audioFileMutex;
    AEHostTicks    _startTime;
    AEHostTicks    _stopTime;
    BOOL           _complete;
    UInt32         _recordedFrames;
    AEHostTicks    _lastTimestamp;
    AudioBufferList * _multiSourceMixBuffer;
    BOOL           _hasBeenStopped;
}
@property (nonatomic) AEAudioFileType type;
@property (nonatomic, readwrite) int numberOfChannels;
@property (nonatomic, readwrite) BOOL recording;
@property (nonatomic, strong, readwrite) NSString * path;
@property (nonatomic, strong) AEMainThreadEndpoint * stopRecordingNotificationEndpoint;
@property (nonatomic, strong) NSTimer * stopTimeout;
@end

@implementation AEAudioFileRecorderModule

- (instancetype)initWithRenderer:(AERenderer *)renderer path:(NSString *)path
                            type:(AEAudioFileType)type error:(NSError **)error {
    return [self initWithRenderer:renderer path:path type:type numberOfChannels:2 error:error];
}

- (instancetype)initWithRenderer:(AERenderer *)renderer path:(NSString *)path type:(AEAudioFileType)type
                numberOfChannels:(int)numberOfChannels error:(NSError **)error {
    
    if ( !(self = [super initWithRenderer:renderer]) ) return nil;
    
    self.path = path;
    self.type = type;
    self.numberOfChannels = numberOfChannels;
    
    if ( renderer ) {
        if ( ![self openFileForRecordingError:error] ) return nil;
    }
    
    self.processFunction = AEAudioFileRecorderModuleProcess;
    
    _audioFileMutex = OS_UNFAIR_LOCK_INIT;
    
    return self;
}

- (void)dealloc {
    if ( _audioFile ) {
        [self finishWriting];
    }
    if ( _multiSourceMixBuffer ) {
        AEAudioBufferListFree(_multiSourceMixBuffer);
    }
    if ( self.stopTimeout ) {
        [self.stopTimeout invalidate];
    }
}

- (void)setMultiSource:(BOOL)multiSource {
    if ( _multiSource == multiSource ) return;
    _multiSource = multiSource;
    if ( _multiSource && !_multiSourceMixBuffer ) {
        _multiSourceMixBuffer = AEAudioBufferListCreateWithFormat(AEAudioDescriptionWithChannelsAndRate(self.numberOfChannels, 0), AEBufferStackMaxFramesPerSlice);
    }
}

- (void)setRenderer:(AERenderer *)renderer {
    [super setRenderer:renderer];
    if ( renderer && _path && !_audioFile ) {
        [self openFileForRecordingError:NULL];
    }
}

- (BOOL)openFileForRecordingError:(NSError **)error {
    if ( !(_audioFile = AEExtAudioFileCreate([NSURL fileURLWithPath:self.path], self.type, self.renderer.sampleRate, self.numberOfChannels, error)) ) return NO;
    ExtAudioFileWriteAsync(_audioFile, 0, NULL); // Prime async recording
    return YES;
}

- (void)beginRecordingAtTime:(AEHostTicks)time {
    assert(!_complete);
    self.recording = YES;
    _recordedFrames = 0;
    _startTime = time ? time : AECurrentTimeInHostTicks();
    _stopTime = 0;
}

void AEAudioFileRecorderModuleBeginRecording(__unsafe_unretained AEAudioFileRecorderModule * THIS, AEHostTicks time) {
    assert(!THIS->_complete);
    THIS->_recording = YES;
    THIS->_recordedFrames = 0;
    THIS->_startTime = time ? time : AECurrentTimeInHostTicks();
    THIS->_stopTime = 0;
}

- (void)stopRecordingAtTime:(AEHostTicks)time completionBlock:(AEAudioFileRecorderModuleCompletionBlock)block {
    if ( _hasBeenStopped ) return;
    _hasBeenStopped = YES;
    
    if ( time && _lastTimestamp > AECurrentTimeInHostTicks()-AEHostTicksFromSeconds(0.5) ) {
        // Stop after a delay
        __weak typeof(self) weakSelf = self;
        self.stopRecordingNotificationEndpoint = [[AEMainThreadEndpoint alloc] initWithHandler:^(void * _Nullable data, size_t length) {
            [weakSelf.stopTimeout invalidate];
            weakSelf.stopTimeout = nil;
            weakSelf.stopRecordingNotificationEndpoint = nil;
            [weakSelf finishWriting];
            weakSelf.recording = NO;
            if ( block ) block();
        } bufferCapacity:32];
        
        self.stopTimeout = [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:NO block:^(NSTimer * timer) {
            weakSelf.stopTimeout = nil;
            weakSelf.stopRecordingNotificationEndpoint = nil;
            [weakSelf finishWriting];
            weakSelf.recording = NO;
            if ( block ) block();
        }];
        
        atomic_thread_fence(memory_order_release);
        _stopTime = time;
    } else {
        // Stop immediately
        os_unfair_lock_lock(&_audioFileMutex);
        [self finishWriting];
        self.recording = NO;
        os_unfair_lock_unlock(&_audioFileMutex);
        if ( block ) {
            block();
        }
    }
}

static void AEAudioFileRecorderModuleProcess(__unsafe_unretained AEAudioFileRecorderModule * THIS, const AERenderContext * _Nonnull context) {
    
    if ( !os_unfair_lock_trylock(&THIS->_audioFileMutex) ) {
        return;
    }
    
    if ( !THIS->_recording || THIS->_complete ) {
        os_unfair_lock_unlock(&THIS->_audioFileMutex);
        return;
    }
    
    AEHostTicks startTime = THIS->_startTime;
    AEHostTicks stopTime = THIS->_stopTime;
    AEHostTicks now = AEBufferStackGetTimeStampForBuffer(context->stack, 0)->mHostTime;
    
    if ( stopTime && stopTime < now ) {
        THIS->_complete = YES;
        AEMainThreadEndpointSend(THIS->_stopRecordingNotificationEndpoint, NULL, 0);
        os_unfair_lock_unlock(&THIS->_audioFileMutex);
        return;
    }
    
    AEHostTicks hostTimeAtBufferEnd = now + AEHostTicksFromSeconds((double)context->frames / context->sampleRate);
    if ( startTime && startTime > hostTimeAtBufferEnd ) {
        os_unfair_lock_unlock(&THIS->_audioFileMutex);
        return;
    }
    
    AEHostTicks previousTimestamp = THIS->_lastTimestamp;
    THIS->_lastTimestamp = now;
    THIS->_startTime = 0;
    
    const AudioBufferList * abl = AEBufferStackGet(context->stack, 0);
    if ( !abl ) {
        os_unfair_lock_unlock(&THIS->_audioFileMutex);
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
    if ( startTime && startTime > now ) {
        UInt32 advanceFrames = round(AESecondsFromHostTicks(startTime - now) * context->sampleRate);
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
    
    if ( THIS->_multiSource && previousTimestamp == now ) {
        // Additional invocation in same time interval: Mix in current buffer
        if ( frames != AEAudioBufferListGetLength(THIS->_multiSourceMixBuffer, NULL) ) {
            #ifdef DEBUG
            if ( AERateLimit() ) NSLog(@"Warning: Buffer length mismatch in %s: %d != %d", __FUNCTION__, frames, AEAudioBufferListGetLength(THIS->_multiSourceMixBuffer, NULL));
            #endif
            if ( frames < AEAudioBufferListGetLength(THIS->_multiSourceMixBuffer, NULL) ) {
                AEAudioBufferListSetLength(THIS->_multiSourceMixBuffer, frames);
            }
        }
        AEDSPMix(THIS->_multiSourceMixBuffer, abl, 1, 1, NO, frames, THIS->_multiSourceMixBuffer);
        
    } else if ( THIS->_multiSource ) {
        // New time interval; write out last interval
        if ( previousTimestamp ) {
            UInt32 recordFrames = AEAudioBufferListGetLength(THIS->_multiSourceMixBuffer, NULL);
            AECheckOSStatus(ExtAudioFileWriteAsync(THIS->_audioFile, recordFrames, THIS->_multiSourceMixBuffer), "ExtAudioFileWriteAsync");
            THIS->_recordedFrames += recordFrames;
            if ( stopTime && stopTime < previousTimestamp + AEHostTicksFromSeconds(((double)recordFrames+0.5) / context->sampleRate) ) {
                THIS->_complete = YES;
                AEMainThreadEndpointSend(THIS->_stopRecordingNotificationEndpoint, NULL, 0);
            }
        }
        
        // Save new frames to mix buffer
        AEAudioBufferListSetLength(THIS->_multiSourceMixBuffer, frames);
        AEAudioBufferListCopyContents(THIS->_multiSourceMixBuffer, buffer, 0, 0, frames);
        
    } else {
        AECheckOSStatus(ExtAudioFileWriteAsync(THIS->_audioFile, frames, buffer), "ExtAudioFileWriteAsync");
        THIS->_recordedFrames += frames;
        if ( stopTime && stopTime < hostTimeAtBufferEnd ) {
            THIS->_complete = YES;
            AEMainThreadEndpointSend(THIS->_stopRecordingNotificationEndpoint, NULL, 0);
        }
    }
    
    os_unfair_lock_unlock(&THIS->_audioFileMutex);
}

- (void)finishWriting {
    AECheckOSStatus(ExtAudioFileDispose(_audioFile), "AudioFileClose");
    _audioFile = NULL;
    _complete = YES;
}

@end
