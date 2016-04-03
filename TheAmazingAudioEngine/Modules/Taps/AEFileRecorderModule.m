//
//  AEFileRecorderModule.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 1/04/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import "AEFileRecorderModule.h"
#import "AEUtilities.h"
#import "AETypes.h"
#import "AEAudioBufferListUtilities.h"

@import AudioToolbox;

@interface AEFileRecorderModule () {
    ExtAudioFileRef _audioFile;
    AEHostTicks    _startTime;
    AEHostTicks    _stopTime;
    BOOL           _complete;
    UInt32         _recordedFrames;
}
@property (nonatomic, readwrite) BOOL recording;
@property (nonatomic, copy) void (^completionBlock)();
@property (nonatomic, strong) NSTimer * pollTimer;
@end

@interface AEFileRecorderModuleWeakProxy : NSProxy
@property (nonatomic, weak) id target;
@end

@implementation AEFileRecorderModule

- (instancetype)initWithRenderer:(AERenderer *)renderer URL:(NSURL *)url
                            type:(AEFileRecorderModuleType)type error:(NSError **)error {
    if ( !(self = [super initWithRenderer:renderer]) ) return nil;
    
    if ( !(_audioFile = [self createAudioFileWriterForURL:url type:type error:error]) ) return nil;
    
    self.processFunction = AEFileRecorderModuleProcess;
    
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

- (void)stopRecordingAtTime:(AEHostTicks)time completionBlock:(void(^)())block {
    self.completionBlock = block;
    _stopTime = time ? time : AECurrentTimeInHostTicks();
    AEFileRecorderModuleWeakProxy * proxy = [AEFileRecorderModuleWeakProxy alloc];
    proxy.target = self;
    self.pollTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(pollForCompletion)
                                                    userInfo:nil repeats:YES];
}

static void AEFileRecorderModuleProcess(__unsafe_unretained AEFileRecorderModule * THIS,
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
    
    // Prepare stereo buffer
    AEAudioBufferListCreateOnStack(stereoBuffer, AEAudioDescription);
    for ( int i=0; i<stereoBuffer->mNumberBuffers; i++ ) {
        stereoBuffer->mBuffers[i] = abl->mBuffers[MIN(abl->mNumberBuffers, i)];
    }
    
    // Advance frames, if we have a start time mid-buffer
    UInt32 frames = context->frames;
    if ( startTime && startTime > context->timestamp->mHostTime ) {
        UInt32 advanceFrames = round(AESecondsFromHostTicks(startTime - context->timestamp->mHostTime) * context->sampleRate);
        for ( int i=0; i<stereoBuffer->mNumberBuffers; i++ ) {
            stereoBuffer->mBuffers[i].mData += AEAudioDescription.mBytesPerFrame * advanceFrames;
            stereoBuffer->mBuffers[i].mDataByteSize -= AEAudioDescription.mBytesPerFrame * advanceFrames;
        }
        frames -= advanceFrames;
    }
    
    // Truncate if we have a stop time mid-buffer
    if ( stopTime && stopTime < hostTimeAtBufferEnd ) {
        UInt32 truncateFrames = round(AESecondsFromHostTicks(hostTimeAtBufferEnd - stopTime) * context->sampleRate);
        for ( int i=0; i<stereoBuffer->mNumberBuffers; i++ ) {
            stereoBuffer->mBuffers[i].mDataByteSize -= AEAudioDescription.mBytesPerFrame * truncateFrames;
        }
        frames -= truncateFrames;
    }
    
    AECheckOSStatus(ExtAudioFileWriteAsync(THIS->_audioFile, frames, stereoBuffer), "ExtAudioFileWriteAsync");
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

- (ExtAudioFileRef)createAudioFileWriterForURL:(NSURL *)url type:(AEFileRecorderModuleType)type error:(NSError **)error {
    
    AudioStreamBasicDescription asbd = {
        .mChannelsPerFrame = 2,
        .mSampleRate = self.renderer.sampleRate,
    };
    AudioFileTypeID fileTypeID;
    
    if ( type == AEFileRecorderModuleTypeM4A ) {
        // Get the output audio description for encoding AAC
        asbd.mFormatID = kAudioFormatMPEG4AAC;
        UInt32 size = sizeof(asbd);
        OSStatus status = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &asbd);
        if ( !AECheckOSStatus(status, "AudioFormatGetProperty(kAudioFormatProperty_FormatInfo") ) {
            int fourCC = CFSwapInt32HostToBig(status);
            if ( error ) *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                                      code:status
                                                  userInfo:@{ NSLocalizedDescriptionKey:
                                                                  [NSString stringWithFormat:NSLocalizedString(@"Couldn't prepare the output format (error %d/%4.4s)", @""), status, (char*)&fourCC]}];
            return NULL;
        }
        fileTypeID = kAudioFileM4AType;
        
    } else if ( type == AEFileRecorderModuleTypeAIFFFloat32 ) {
        asbd.mFormatID = kAudioFormatLinearPCM;
        asbd.mFormatFlags = kLinearPCMFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsBigEndian;
        asbd.mBitsPerChannel = sizeof(float) * 8;
        asbd.mBytesPerPacket = asbd.mChannelsPerFrame * sizeof(float);
        asbd.mBytesPerFrame = asbd.mBytesPerPacket;
        asbd.mFramesPerPacket = 1;
        fileTypeID = kAudioFileAIFCType;
        
    } else { // AEFileRecorderModuleTypeAIFFInt16
        asbd.mFormatID = kAudioFormatLinearPCM;
        asbd.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagIsBigEndian;
        asbd.mBitsPerChannel = 16;
        asbd.mBytesPerPacket = asbd.mChannelsPerFrame * 2;
        asbd.mBytesPerFrame = asbd.mBytesPerPacket;
        asbd.mFramesPerPacket = 1;
        fileTypeID = kAudioFileAIFFType;
    }
    
    // Open the file
    ExtAudioFileRef audioFile;
    OSStatus status = ExtAudioFileCreateWithURL((__bridge CFURLRef)url, fileTypeID, &asbd, NULL, kAudioFileFlags_EraseFile,
                                                &audioFile);
    if ( !AECheckOSStatus(status, "ExtAudioFileCreateWithURL") ) {
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                     code:status
                                 userInfo:@{ NSLocalizedDescriptionKey:
                                                 NSLocalizedString(@"Couldn't open the output file", @"") }];
        return NULL;
    }
    
    // Set the client format
    status = ExtAudioFileSetProperty(audioFile,
                                     kExtAudioFileProperty_ClientDataFormat,
                                     sizeof(AudioStreamBasicDescription),
                                     &AEAudioDescription);
    if ( !AECheckOSStatus(status, "ExtAudioFileSetProperty") ) {
        ExtAudioFileDispose(audioFile);
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                     code:status
                                 userInfo:@{ NSLocalizedDescriptionKey:
                                                 NSLocalizedString(@"Couldn't configure the file writer", @"") }];
        return NULL;
    }
    
    // Prime async recording
    ExtAudioFileWriteAsync(audioFile, 0, NULL);
    
    return audioFile;
}

- (void)finishWriting {
    AECheckOSStatus(ExtAudioFileDispose(_audioFile), "AudioFileClose");
    _audioFile = NULL;
}

@end

@implementation AEFileRecorderModuleWeakProxy
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [_target methodSignatureForSelector:selector];
}
- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation setTarget:_target];
    [invocation invoke];
}
@end
