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
#import <Accelerate/Accelerate.h>

const AEHostTicks AEAudioFileOutputInitialHostTicksValue = 1000;

@interface AEAudioFileOutput ()
@property (nonatomic, readwrite) double sampleRate;
@property (nonatomic, readwrite) int numberOfChannels;
@property (nonatomic, readwrite) BOOL multiTrackOutput;
@property (nonatomic, strong, readwrite) NSString * path;
@property (nonatomic) ExtAudioFileRef * audioFiles;
@property (nonatomic, readwrite) UInt64 numberOfFramesRecorded;
@property (nonatomic) AudioTimeStamp timestamp;
@end

@implementation AEAudioFileOutput

- (instancetype)initWithRenderer:(AERenderer *)renderer path:(NSString *)path type:(AEAudioFileType)type
                      sampleRate:(double)sampleRate channelCount:(int)channelCount
                           error:(NSError *__autoreleasing  _Nullable *)error {
    if ( !(self = [super init]) ) return nil;
 
    NSFileManager * fm = [NSFileManager defaultManager];
    if ( channelCount > 2 && ![fm fileExistsAtPath:path] ) {
        if ( ![fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error] ) {
            return nil;
        }
    }
    
    int audioFileCount = ceil(channelCount/2.0);
    self.audioFiles = malloc(sizeof(ExtAudioFileRef) * audioFileCount);
    if ( audioFileCount == 1 ) {
        if ( !(_audioFiles[0] = AEExtAudioFileCreate([NSURL fileURLWithPath:path], type, sampleRate, channelCount, error)) ) return nil;
    } else {
        NSString * pathExtension = type == AEAudioFileTypeM4A ? @"m4a" : type == AEAudioFileTypeWAVInt16 ? @"wav" : @"aiff";
        for ( int i=0; i<audioFileCount; i++ ) {
            NSString * filename = [[NSString stringWithFormat:@"Track %02d", i+1] stringByAppendingPathExtension:pathExtension];
            if ( !(_audioFiles[i] = AEExtAudioFileCreate([NSURL fileURLWithPath:[path stringByAppendingPathComponent:filename]], type, sampleRate, 2, error)) ) return nil;
        }
    }
    
    self.path = path;
    self.sampleRate = sampleRate;
    self.numberOfChannels = channelCount;
    self.renderer = renderer;
    _timestamp.mFlags = kAudioTimeStampSampleTimeValid | kAudioTimeStampHostTimeValid;
    _timestamp.mHostTime = AEAudioFileOutputInitialHostTicksValue;
    
    return self;
}

- (void)dealloc {
    if ( _audioFiles ) {
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
    assert(_audioFiles);
    
    // Perform render in background thread
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        
        // Allocate render buffer
        AudioBufferList * abl
            = AEAudioBufferListCreateWithFormat(AEAudioDescriptionWithChannelsAndRate(self.numberOfChannels, self.sampleRate),
                                                AEBufferStackMaxFramesPerSlice);
        
        // Run for frame count
        UInt32 remainingFrames = round(duration * self.sampleRate);
        BOOL waitForSilence = self.extendRecordingUntilSilence;
        UInt32 remainingDecayFrames = 10 * self.sampleRate;
        OSStatus status = noErr;
        while ( 1 ) {
            UInt32 frames = MIN(remainingFrames ? remainingFrames : waitForSilence ? MIN(512, remainingDecayFrames) : 0, AEBufferStackMaxFramesPerSlice);
            if ( frames == 0 ) break;
            
            AEAudioBufferListSetLength(abl, frames);
            
            // Run renderer
            AERendererRun(self.renderer, abl, frames, &self->_timestamp);
            
            if ( remainingFrames > 0 ) remainingFrames -= frames;
            if ( remainingFrames == 0 && waitForSilence ) {
                // Evaluate frames, waiting for silence
                remainingDecayFrames -= frames;
                float max = 0;
                for ( int i=0;i<abl->mNumberBuffers && max == 0; i++ ) {
                    float maxChannel = 0;
                    vDSP_maxmgv(abl->mBuffers[0].mData, 1, &maxChannel, frames);
                    max = MAX(max, maxChannel);
                }
                if ( max < 0.0001 ) {
                    break;
                }
            }
            
            // Write to file
            if ( ![self writeFrames:frames fromBuffer:abl] ) {
                break;
            }
            
            self->_timestamp.mSampleTime += frames;
            self->_timestamp.mHostTime += AEHostTicksFromSeconds((double)frames / self.sampleRate);
            self->_numberOfFramesRecorded += frames;
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
    assert(_audioFiles);
    
    // Perform render in background thread
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        
        // Allocate render buffer
        AudioBufferList * abl
            = AEAudioBufferListCreateWithFormat(AEAudioDescriptionWithChannelsAndRate(self.numberOfChannels, self.sampleRate),
                                                AEBufferStackMaxFramesPerSlice);
        
        // Run while not stopped by condition
        OSStatus status = noErr;
        while ( !conditionBlock() ) {
            UInt32 frames = AEBufferStackMaxFramesPerSlice;
            
            // Run renderer
            AERendererRun(self.renderer, abl, AEBufferStackMaxFramesPerSlice, &self->_timestamp);
            
            // Write to file
            if ( ![self writeFrames:AEBufferStackMaxFramesPerSlice fromBuffer:abl] ) {
                break;
            }
            
            self->_timestamp.mSampleTime += frames;
            self->_timestamp.mHostTime += AEHostTicksFromSeconds((double)frames / self.sampleRate);
            self->_numberOfFramesRecorded += frames;
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

- (BOOL)writeFrames:(UInt32)frames fromBuffer:(AudioBufferList *)abl {
    if ( self.numberOfChannels <= 2 ) {
        OSStatus status = ExtAudioFileWrite(_audioFiles[0], frames, abl);
        return AECheckOSStatus(status, "ExtAudioFileWrite");
    } else {
        int audioFileCount = ceil(self.numberOfChannels/2.0);
        for ( int i=0; i<audioFileCount; i++ ) {
            AEChannelSet channels = AEChannelSetMake(i*2, (i*2)+1);
            AEAudioBufferListCopyOnStackWithChannelSubset(subbuffer, abl, channels);
            OSStatus status = ExtAudioFileWrite(_audioFiles[i], frames, subbuffer);
            if ( !AECheckOSStatus(status, "ExtAudioFileWrite") ) {
                return NO;
            }
        }
        return YES;
    }
}

- (void)finishWriting {
    int audioFileCount = ceil(self.numberOfChannels/2.0);
    for ( int i=0; i<audioFileCount; i++ ) {
        AECheckOSStatus(ExtAudioFileDispose(_audioFiles[i]), "AudioFileClose");
    }
    free(_audioFiles);
    self.audioFiles = NULL;
}

@end
