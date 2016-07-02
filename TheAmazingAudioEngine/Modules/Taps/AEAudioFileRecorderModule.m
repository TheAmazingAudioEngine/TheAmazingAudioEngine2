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
#import <AudioToolbox/AudioToolbox.h>

@interface AEAudioFileRecorderModule () {
    ExtAudioFileRef _audioFile;
    AEHostTicks    _startTime;
    AEHostTicks    _stopTime;
    BOOL           _complete;
    UInt32         _recordedFrames;
}
@property (nonatomic, readwrite) int numberOfChannels;
@property (nonatomic, readwrite) BOOL recording;
@property (nonatomic, copy) void (^completionBlock)();
@property (nonatomic, strong) NSTimer * pollTimer;
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
    
    return self;
}

- (void)dealloc {
    if ( self.pollTimer ) {
        [self.pollTimer invalidate];
    }
    if ( _audioFile ) {
        [self finishWriting];
    }
}

- (void)beginRecordingAtTime:(AEHostTicks)time {
    self.recording = YES;
    _complete = NO;
    _recordedFrames = 0;
    _startTime = time ? time : AECurrentTimeInHostTicks();
}

- (void)stopRecordingAtTime:(AEHostTicks)time completionBlock:(AEAudioFileRecorderModuleCompletionBlock)block {
    self.completionBlock = block;
    _stopTime = time ? time : AECurrentTimeInHostTicks();
    self.pollTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:[AEWeakRetainingProxy proxyWithTarget:self]
                                                    selector:@selector(pollForCompletion) userInfo:nil repeats:YES];
}

static void AEAudioFileRecorderModuleProcess(__unsafe_unretained AEAudioFileRecorderModule * THIS,
                                        const AERenderContext * _Nonnull context) {
    
    if ( !THIS->_recording || THIS->_complete ) return;
    
    AEHostTicks startTime = THIS->_startTime;
    AEHostTicks stopTime = THIS->_stopTime;
    
    if ( stopTime && stopTime < context->timestamp->mHostTime ) {
        THIS->_complete = YES;
        return;
    }
    
    AEHostTicks hostTimeAtBufferEnd
        = context->timestamp->mHostTime + AEHostTicksFromSeconds((double)context->frames / context->sampleRate);
    if ( startTime && startTime > hostTimeAtBufferEnd ) {
        return;
    }
    
    THIS->_startTime = 0;
    
    const AudioBufferList * abl = AEBufferStackGet(context->stack, 0);
    if ( !abl ) return;
    
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
    }
}

- (void)pollForCompletion {
    if ( _complete ) {
        [self.pollTimer invalidate];
        self.pollTimer = nil;
        self.recording = NO;
        [self finishWriting];
        if ( self.completionBlock ) self.completionBlock();
        self.completionBlock = nil;
    }
}

- (void)finishWriting {
    AECheckOSStatus(ExtAudioFileDispose(_audioFile), "AudioFileClose");
    _audioFile = NULL;
}

@end
