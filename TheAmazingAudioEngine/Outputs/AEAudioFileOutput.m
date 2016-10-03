//
//  AEAudioFileOutput.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 7/04/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import "AEAudioFileOutput.h"
#import "AETypes.h"
#import "AEUtilities.h"
#import "AERenderer.h"
#import "AEBufferStack.h"
#import "AEAudioBufferListUtilities.h"

@interface AEAudioFileOutput () {
    ExtAudioFileRef _audioFile;
}
@property (nonatomic, readwrite) double sampleRate;
@property (nonatomic, readwrite) int numberOfChannels;
@property (nonatomic, strong, readwrite) NSURL * fileURL;
@property (nonatomic, readwrite) UInt64 numberOfFramesRecorded;
@end

@implementation AEAudioFileOutput

- (instancetype)initWithRenderer:(AERenderer *)renderer URL:(NSURL *)url type:(AEAudioFileType)type
                      sampleRate:(double)sampleRate channelCount:(int)channelCount
                           error:(NSError *__autoreleasing  _Nullable *)error {
    if ( !(self = [super init]) ) return nil;

    if ( !(_audioFile = AEExtAudioFileCreate(url, type, sampleRate, channelCount, error)) ) return nil;

    self.fileURL = url;
    self.sampleRate = sampleRate;
    self.numberOfChannels = channelCount;
    self.renderer = renderer;

    return self;
}

- (void)dealloc {
    if ( _audioFile ) {
        [self finishWriting];
    }
}

- (void)setRenderer:(AERenderer *)renderer {
    _renderer = renderer;
    _renderer.sampleRate = self.sampleRate;
    _renderer.numberOfOutputChannels = self.numberOfChannels;
    _renderer.isOffline = YES;
}

- (void)runForDuration:(AESeconds)duration completionBlock:(AEAudioFileOutputCompletionBlock)completionBlock {
    assert(_audioFile);
    
    // Perform render in background thread
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        
        // Allocate render buffer
        AudioBufferList * abl
            = AEAudioBufferListCreateWithFormat(AEAudioDescriptionWithChannelsAndRate(self.numberOfChannels, self.sampleRate),
                                                AEBufferStackMaxFramesPerSlice);
        AudioTimeStamp timestamp = { .mFlags = kAudioTimeStampSampleTimeValid, .mSampleTime = 0 };
        
        // Run for frame count
        UInt32 remainingFrames = round(duration * self.sampleRate);
        OSStatus status = noErr;
        while ( remainingFrames > 0 ) {
            UInt32 frames = MIN(remainingFrames, AEBufferStackMaxFramesPerSlice);
            AEAudioBufferListSetLength(abl, frames);
            
            // Run renderer
            AERendererRun(_renderer, abl, frames, &timestamp);
            
            // Write to file
            status = ExtAudioFileWrite(_audioFile, frames, abl);
            if ( !AECheckOSStatus(status, "ExtAudioFileWrite") ) {
                break;
            }
            
            remainingFrames -= frames;
            timestamp.mSampleTime += frames;
            _numberOfFramesRecorded += frames;
        }
        
        AEAudioBufferListFree(abl);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError * error = nil;
            if ( status != noErr ) {
                error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Couldn't write to file" }];
            }
            completionBlock(error);
        });
    });
}

- (void)runUntilCondition:(AEAudioFileOutputConditionBlock)conditionBlock
          completionBlock:(AEAudioFileOutputCompletionBlock)completionBlock {
    assert(_audioFile);
    
    // Perform render in background thread
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        
        // Allocate render buffer
        AudioBufferList * abl
            = AEAudioBufferListCreateWithFormat(AEAudioDescriptionWithChannelsAndRate(self.numberOfChannels, self.sampleRate),
                                                AEBufferStackMaxFramesPerSlice);
        AudioTimeStamp timestamp = { .mFlags = kAudioTimeStampSampleTimeValid, .mSampleTime = 0 };
        
        // Run while not stopped by condition
        OSStatus status = noErr;
        while ( !conditionBlock() ) {
            UInt32 frames = AEBufferStackMaxFramesPerSlice;
            
            // Run renderer
            AERendererRun(_renderer, abl, AEBufferStackMaxFramesPerSlice, &timestamp);
            
            // Write to file
            status = ExtAudioFileWrite(_audioFile, AEBufferStackMaxFramesPerSlice, abl);
            if ( !AECheckOSStatus(status, "ExtAudioFileWrite") ) {
                break;
            }
            
            timestamp.mSampleTime += frames;
            _numberOfFramesRecorded += frames;
        }
        
        AEAudioBufferListFree(abl);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError * error = nil;
            if ( status != noErr ) {
                error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Couldn't write to file" }];
            }
            completionBlock(error);
        });
    });
}

- (void)finishWriting {
    AECheckOSStatus(ExtAudioFileDispose(_audioFile), "AudioFileClose");
    _audioFile = NULL;
}

@end
