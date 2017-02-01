//
//  AEAudioPasteboard.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 23/08/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import "AEAudioPasteboard.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import "AEUtilities.h"
#import "AEAudioBufferListUtilities.h"
#import <UIKit/UIKit.h>

static const double kSampleRate = 44100;
static const int kBitsPerSample = 16;
static const int kWaveAudioFormatPCM = 1;
static const OSStatus kFinishedStatus = -2222;

NSString * const AEAudioPasteboardInfoNumberOfChannelsKey = @"channels";
NSString * const AEAudioPasteboardInfoLengthInFramesKey = @"length";
NSString * const AEAudioPasteboardInfoDurationInSecondsKey = @"seconds";
NSString * const AEAudioPasteboardInfoSampleRateKey = @"sampleRate";
NSString * const AEAudioPasteboardInfoSizeInBytesKey = @"size";

NSString * const AEAudioPasteboardChangedNotification = @"AEAudioPasteboardChangedNotification";

NSString * const AEAudioPasteboardErrorDomain = @"AEAudioPasteboardErrorDomain";

typedef struct {
    __unsafe_unretained AEAudioPasteboardGeneratorBlock generator;
    AudioBufferList * sourceBuffer;
    AudioStreamBasicDescription sourceFormat;
    BOOL finished;
} input_proc_data_t;

#pragma mark - WAVE data structures

//! RIFF header chunk
typedef struct {
    char ID[4];
    int32_t Size;
    char Format[4];
} wave_riff_chunk_t;

//! RIFF format chunk
typedef struct {
    char ID[4];
    int32_t Size;
    int16_t AudioFormat;
    int16_t NumChannels;
    int32_t SampleRate;
    int32_t ByteRate;
    int16_t BlockAlign;
    int16_t BitsPerSample;
} wave_fmt_chunk_t;

//! Wave chunk
typedef struct {
    char ID[4];
    int32_t Size;
} wave_chunk_t;

//! Wave header; Assumes only RIFF header chunk followed by format chunk
typedef struct {
    wave_riff_chunk_t riff_chunk;
    wave_fmt_chunk_t fmt_chunk;
} wave_header_t;

//! RIFF header chunk followed by format chunk, followed by data chunk
typedef struct {
    wave_riff_chunk_t riff_chunk;
    wave_fmt_chunk_t fmt_chunk;
    wave_chunk_t data_chunk;
} wave_header_plus_data_t;

#pragma mark -

@implementation AEAudioPasteboard

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // UIPasteboard does not send its change notification when an app is in the background. So we need to
        // take note of the change count when we resign active, and compare when we resume foreground status again.
        __block NSInteger lastPasteboardChange;
        NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
        [nc addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:nil usingBlock:^(NSNotification * note) {
            lastPasteboardChange = [UIPasteboard generalPasteboard].changeCount;
        }];
        [nc addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:nil usingBlock:^(NSNotification * note) {
            if ( [UIPasteboard generalPasteboard].changeCount != lastPasteboardChange ) {
                [[NSNotificationCenter defaultCenter] postNotificationName:AEAudioPasteboardChangedNotification object:nil];
            }
        }];
        
        // Watch UIPasteboard change notifications and re-post as AEAudioPasteboardChangedNotification
        [nc addObserverForName:UIPasteboardChangedNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            [[NSNotificationCenter defaultCenter] postNotificationName:AEAudioPasteboardChangedNotification object:nil];
        }];
    });
}

+ (NSDictionary *)infoForGeneralPasteboardItem {

    // Get pasteboard item
    const wave_header_t *header;
    const wave_chunk_t *dataChunk;
    NSArray <NSData *> * blocks = [self getPasteboardBlocksWithHeader:&header dataChunk:&dataChunk];
    if ( !blocks ) {
        return nil;
    }
    
    UInt32 channelCount = CFSwapInt16LittleToHost(header->fmt_chunk.NumChannels);
    UInt32 bytesPerSample = CFSwapInt16LittleToHost(header->fmt_chunk.BitsPerSample) / 8;
    UInt32 frames = CFSwapInt32LittleToHost(dataChunk->Size) / (bytesPerSample * channelCount);
    double sampleRate = CFSwapInt32LittleToHost(header->fmt_chunk.SampleRate);
    double duration = (double)frames / sampleRate;
    size_t size = 0;
    for ( NSData * block in blocks ) {
        size += block.length;
    }
    
    return @{
        AEAudioPasteboardInfoNumberOfChannelsKey: @(channelCount),
        AEAudioPasteboardInfoLengthInFramesKey: @(frames),
        AEAudioPasteboardInfoDurationInSecondsKey: @(duration),
        AEAudioPasteboardInfoSampleRateKey: @(sampleRate),
        AEAudioPasteboardInfoSizeInBytesKey: @(size)
    };
}

+ (void)pasteToFileAtPath:(NSString *)path fileType:(AEAudioFileType)fileType sampleRate:(double)sampleRate
             channelCount:(int)channelCount completionBlock:(void (^)(NSError * errorOrNil))completionBlock {
    
    // Get reader
    AEAudioPasteboardReader * reader = [AEAudioPasteboardReader readerForGeneralPasteboardItem];
    if ( !reader ) {
        completionBlock([NSError errorWithDomain:AEAudioPasteboardErrorDomain code:AEAudioPasteboardErrorCodeNoItem
                                        userInfo:nil]);
        return;
    }
    
    if ( !sampleRate ) {
        sampleRate = reader.originalFormat.mSampleRate;
    }
    if ( !channelCount ) {
        channelCount = reader.originalFormat.mChannelsPerFrame;
    }
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        
        // Create audio file and configure for format
        NSError * error = nil;
        ExtAudioFileRef audioFile =
            AEExtAudioFileCreate([NSURL fileURLWithPath:path], fileType, sampleRate, channelCount, &error);
        if ( !audioFile ) {
            dispatch_async(dispatch_get_main_queue(), ^{ completionBlock(error); });
            return;
        }
        
        AudioStreamBasicDescription clientFormat;
        UInt32 size = sizeof(clientFormat);
        AECheckOSStatus(ExtAudioFileGetProperty(audioFile, kExtAudioFileProperty_ClientDataFormat,  &size, &clientFormat),
                        "ExtAudioFileGetProperty(kExtAudioFileProperty_ClientDataFormat)");
        reader.clientFormat = clientFormat;
        
        // Write out data
        const int processBlockFrames = 4096;
        AudioBufferList * buffer = AEAudioBufferListCreateWithFormat(clientFormat, processBlockFrames);
        while ( 1 ) {
            UInt32 frames = processBlockFrames;
            [reader readIntoBuffer:buffer length:&frames];
            if ( frames == 0 ) {
                break;
            }
            
            if ( !AECheckOSStatus(ExtAudioFileWrite(audioFile, frames, buffer), "ExtAudioFileWrite") ) {
                break;
            }
        }
        AEAudioBufferListFree(buffer);
        ExtAudioFileDispose(audioFile);
        
        dispatch_async(dispatch_get_main_queue(), ^{ completionBlock(nil); });
    });
}

+ (void)copyFromFileAtPath:(NSString *)path completionBlock:(void (^)(NSError * errorOrNil))completionBlock {
    
    // Open audio file
    NSError * error = nil;
    AudioStreamBasicDescription fileAudioDescription;
    UInt64 fileLength;
    ExtAudioFileRef audioFile =
    AEExtAudioFileOpen([NSURL fileURLWithPath:path], &fileAudioDescription, &fileLength, &error);
    if ( !audioFile ) {
        completionBlock(error);
        return;
    }

    // Perform read & copy
    __block UInt32 remainingFrames = (UInt32)fileLength;
    [self copyUsingGenerator:^(AudioBufferList *buffer, UInt32 *ioFrames, BOOL *finished) {
        *ioFrames = MIN(*ioFrames, remainingFrames);
        ExtAudioFileRead(audioFile, ioFrames, buffer);
        remainingFrames -= *ioFrames;
        if ( remainingFrames == 0 ) {
            *finished = YES;
        }
    } audioDescription:fileAudioDescription completionBlock:^(NSError *errorOrNil) {
        ExtAudioFileDispose(audioFile);
        completionBlock(errorOrNil);
    }];
}

+ (void)copyUsingGenerator:(AEAudioPasteboardGeneratorBlock)generator
          audioDescription:(AudioStreamBasicDescription)sourceAudioDescription
           completionBlock:(void (^)(NSError * errorOrNil))completionBlock {
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        
        NSMutableData * audioData = [NSMutableData data];
        
        // Setup buffers and converter
        const UInt32 processBlockFrames = 4096;
        AudioStreamBasicDescription targetAudioDescription =
            [self pasteboardAudioDescriptionWithChannels:sourceAudioDescription.mChannelsPerFrame sampleRate:kSampleRate];
        AudioBufferList * targetBuffer = AEAudioBufferListCreateWithFormat(targetAudioDescription, processBlockFrames);
        
        AudioConverterRef converter;
        OSStatus status = AudioConverterNew(&sourceAudioDescription, &targetAudioDescription, &converter);
        if ( !AECheckOSStatus(status, "AudioConverterNew") ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock([NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil]);
            });
            return;
        }
        
        AudioBufferList * sourceBuffer = AEAudioBufferListCreateWithFormat(sourceAudioDescription, processBlockFrames);
        
        // Add enough space for wave header
        [audioData increaseLengthBy:sizeof(wave_header_plus_data_t)];
        
        // Process audio
        BOOL finished = NO;
        UInt32 frameCount = 0;
        while ( !finished ) {
            UInt32 block = processBlockFrames;
            AEAudioBufferListSetLengthWithFormat(targetBuffer, targetAudioDescription, block);
            input_proc_data_t data = { generator, sourceBuffer, sourceAudioDescription };
            status = AudioConverterFillComplexBuffer(converter, AEAudioPasteboardFillComplexBufferInputProc,
                                                     &data, &block, targetBuffer, NULL);
            if ( status != noErr ) {
                break;
            }
            
            [audioData appendBytes:targetBuffer->mBuffers[0].mData length:block * targetAudioDescription.mBytesPerFrame];
            frameCount += block;
            
            if ( data.finished ) {
                break;
            }
        }
        
        AEAudioBufferListFree(sourceBuffer);
        AEAudioBufferListFree(targetBuffer);
        
        if ( !AECheckOSStatus(status, "AudioConverterFillComplexBuffer") ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock([NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil]);
            });
            return;
        }
        
        // Populate wave header
        wave_header_plus_data_t * header = audioData.mutableBytes;
        AEAudioPasteboardPopulateWaveHeaderFields(header, targetAudioDescription.mChannelsPerFrame, frameCount);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Assign to clipboard
            [[UIPasteboard generalPasteboard] setData:audioData forPasteboardType:(NSString *)kUTTypeAudio];
            
            completionBlock(nil);
        });
    });
}

#pragma mark - Helpers

+ (NSArray <NSData *> *)getPasteboardBlocksWithHeader:(const wave_header_t **)header dataChunk:(const wave_chunk_t **)dataChunk {
    UIPasteboard * generalPasteboard = [UIPasteboard generalPasteboard];
    NSIndexSet * itemSet = [generalPasteboard itemSetWithPasteboardTypes:@[(NSString *)kUTTypeAudio]];
    if ( itemSet.count == 0 ) {
        return nil;
    }
    
    // Parse audio item
    NSArray <NSData *> * blocks = [generalPasteboard dataForPasteboardType:(NSString*)kUTTypeAudio inItemSet:itemSet];
    if ( !blocks || ![self findHeader:header dataChunk:dataChunk inData:blocks.firstObject] ) {
        return nil;
    }
    
    return blocks;
}

+ (AudioStreamBasicDescription)pasteboardAudioDescriptionWithChannels:(int)channels sampleRate:(double)sampleRate {
    AudioStreamBasicDescription audioDescription = {};
    audioDescription.mFormatID          = kAudioFormatLinearPCM;
    audioDescription.mFormatFlags       = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian;
    audioDescription.mChannelsPerFrame  = channels;
    audioDescription.mBytesPerPacket    = sizeof(SInt16)*audioDescription.mChannelsPerFrame;
    audioDescription.mFramesPerPacket   = 1;
    audioDescription.mBytesPerFrame     = sizeof(SInt16)*audioDescription.mChannelsPerFrame;
    audioDescription.mBitsPerChannel    = 8 * sizeof(SInt16);
    audioDescription.mSampleRate        = sampleRate;
    return audioDescription;
}

static OSStatus AEAudioPasteboardFillComplexBufferInputProc(AudioConverterRef inAudioConverter,
                                                            UInt32 * ioNumberDataPackets,
                                                            AudioBufferList * ioData,
                                                            AudioStreamPacketDescription ** outDataPacketDescription,
                                                            void * inUserData) {
    input_proc_data_t * data = (input_proc_data_t *)inUserData;
    data->finished = NO;
    AEAudioBufferListSetLengthWithFormat(data->sourceBuffer, data->sourceFormat, *ioNumberDataPackets);
    data->generator(data->sourceBuffer, ioNumberDataPackets, &data->finished);
    AEAudioBufferListSetLengthWithFormat(data->sourceBuffer, data->sourceFormat, *ioNumberDataPackets);
    memcpy(ioData, data->sourceBuffer, AEAudioBufferListGetStructSize(data->sourceBuffer));
    return noErr;
}

#pragma mark - WAVE format helpers

//! Determine whether a wave header is valid
static BOOL AEAudioPasteboardWaveDataIsValid(const wave_header_t * header) {
    return ( strncmp(header->riff_chunk.ID, "RIFF", 4)==0 
            && strncmp(header->riff_chunk.Format, "WAVE", 4)==0 
            && strncmp(header->fmt_chunk.ID, "fmt ", 4)==0 
            && CFSwapInt16LittleToHost(header->fmt_chunk.AudioFormat) == kWaveAudioFormatPCM 
            && CFSwapInt32LittleToHost(header->fmt_chunk.SampleRate) == kSampleRate 
            && CFSwapInt16LittleToHost(header->fmt_chunk.BitsPerSample) == kBitsPerSample );
}

//! Determine whether a fourCC value is valid
static BOOL AEAudioPasteboardFourCCIsValid(const char * fourCC) {
    for ( int i=0; i<4; i++ ) {
        if ( !((fourCC[i] >= 'a' && fourCC[i] <= 'z') || (fourCC[i] >= 'A' && fourCC[i] <= 'Z') || fourCC[i] == ' ') ) {
            return NO;
        }
    }
    return YES;
}

//! Find data chunk located after wave_header_t, before endOfFile
static const wave_chunk_t * AEAudioPasteboardWaveDataFindDataChunk(const wave_header_t * header, const void * endOfFile) {
    wave_chunk_t *chunk = (wave_chunk_t*)(header+1);
    while ( (void*)(chunk+1) <= endOfFile ) {
        if ( !AEAudioPasteboardFourCCIsValid(chunk->ID) ) {
            // Correct for incorrectly-aligned blocks from naughty programs
            if ( AEAudioPasteboardFourCCIsValid(((wave_chunk_t*)(((char*)chunk)+1))->ID) )
                chunk = (wave_chunk_t*)(((char*)chunk)+1);
            else if ( AEAudioPasteboardFourCCIsValid(((wave_chunk_t*)(((char*)chunk)-1))->ID) )
                chunk = (wave_chunk_t*)(((char*)chunk)-1);
        }
        
        if ( strncmp(chunk->ID, "data", 4) == 0 ) break;
        chunk = (wave_chunk_t*)(((char*)chunk) + sizeof(wave_chunk_t) + CFSwapInt32LittleToHost(chunk->Size));
    }
    if ( (void*)chunk >= endOfFile ) return NULL;
    
    return chunk;
}

//! Fill in headers with the given details
static void AEAudioPasteboardPopulateWaveHeaderFields(wave_header_plus_data_t *header, int channels, int lengthInFrames) {
    memcpy(header->riff_chunk.ID, "RIFF", 4);
    header->riff_chunk.Size = CFSwapInt32HostToLittle((lengthInFrames * sizeof(SInt16) * channels) + sizeof(wave_fmt_chunk_t)
                                                      + sizeof(wave_chunk_t) + sizeof(header->riff_chunk.Format));
    memcpy(header->riff_chunk.Format, "WAVE", 4);
    
    memcpy(header->fmt_chunk.ID, "fmt ", 4);
    header->fmt_chunk.Size = CFSwapInt32HostToLittle(sizeof(wave_fmt_chunk_t) - sizeof(header->fmt_chunk.ID)
                                                     - sizeof(header->fmt_chunk.Size));
    header->fmt_chunk.AudioFormat = CFSwapInt16HostToLittle(kWaveAudioFormatPCM);
    header->fmt_chunk.NumChannels = CFSwapInt16HostToLittle(channels);
    header->fmt_chunk.SampleRate = CFSwapInt32HostToLittle(kSampleRate);
    header->fmt_chunk.ByteRate = CFSwapInt32HostToLittle(kSampleRate * sizeof(SInt16) * channels);
    header->fmt_chunk.BlockAlign = CFSwapInt16HostToLittle(sizeof(SInt16) * channels);
    header->fmt_chunk.BitsPerSample = CFSwapInt16HostToLittle(sizeof(SInt16) * 8);
    
    memcpy(header->data_chunk.ID, "data", 4);
    header->data_chunk.Size = CFSwapInt32HostToLittle(lengthInFrames * sizeof(SInt16) * channels);
}

//! Find the header and data chunk in the data
+ (BOOL)findHeader:(const wave_header_t **)outHeader dataChunk:(const wave_chunk_t **)outDataChunk inData:(NSData *)data {
    if ( data.length < sizeof(wave_header_t)+sizeof(wave_chunk_t)
            || !AEAudioPasteboardWaveDataIsValid((const wave_header_t*)data.bytes) ) {
        return NO;
    }
    
    const wave_chunk_t * dataChunk =
        AEAudioPasteboardWaveDataFindDataChunk((const wave_header_t*)data.bytes, ((const char*)data.bytes + data.length));
    
    if ( !dataChunk ) {
        return NO;
    }
    
    *outHeader = (const wave_header_t*)data.bytes;
    *outDataChunk = dataChunk;
    return YES;
}

@end

#pragma mark - Reader

@interface AEAudioPasteboardReader () {
    AudioConverterRef _converter;
    size_t _index;
    size_t _offset;
}
@property (nonatomic) NSArray <NSData *> * blocks;
@end

@implementation AEAudioPasteboardReader

+ (instancetype)readerForGeneralPasteboardItem {
    return [AEAudioPasteboardReader new];
}

- (instancetype)init {
    if ( !(self = [super init]) ) return nil;
    
    _clientFormat = AEAudioDescription;
    [self reset];
    
    if ( !self.blocks ) {
        return nil;
    }
    
    return self;
}

- (void)dealloc {
    if ( _converter ) {
        AudioConverterDispose(_converter);
    }
}

- (void)setClientFormat:(AudioStreamBasicDescription)clientFormat {
    if ( !memcmp(&clientFormat, &_clientFormat, sizeof(clientFormat)) ) return;
    
    _clientFormat = clientFormat;
    
    if ( _converter ) {
        AudioConverterDispose(_converter);
        _converter = NULL;
    }
}

- (void)readIntoBuffer:(AudioBufferList *)buffer length:(UInt32 *)ioFrames {
    
    if ( _index == _blocks.count || !_blocks.count ) {
        *ioFrames = 0;
        return;
    }
    
    if ( !_converter ) {
        if ( !AECheckOSStatus(AudioConverterNew(&_originalFormat, &_clientFormat, &_converter), "AudioConverterNew") ) {
            *ioFrames = 0;
            return;
        }
    }
    
    AEAudioBufferListSetLengthWithFormat(buffer, _clientFormat, *ioFrames);
    OSStatus result = AudioConverterFillComplexBuffer(_converter, AEAudioPasteboardReaderInputProc, (__bridge void *)self,
                                                      ioFrames, buffer, NULL);
    if ( result != kFinishedStatus && !AECheckOSStatus(result, "AudioConverterFillComplexBuffer") ) {
        *ioFrames = 0;
    }
}

- (void)reset {
    if ( _converter ) {
        AudioConverterReset(_converter);
    }
    
    _index = 0;
    _offset = 0;
    
    // Get pasteboard item
    const wave_header_t *header;
    const wave_chunk_t *dataChunk;
    self.blocks = [AEAudioPasteboard getPasteboardBlocksWithHeader:&header dataChunk:&dataChunk];
    if ( !self.blocks ) {
        return;
    }
    
    _offset = (char*)dataChunk + sizeof(wave_chunk_t) - (char*)self.blocks.firstObject.bytes;
    
    _originalFormat =
        [AEAudioPasteboard pasteboardAudioDescriptionWithChannels:CFSwapInt16LittleToHost(header->fmt_chunk.NumChannels)
                                                       sampleRate:CFSwapInt32LittleToHost(header->fmt_chunk.SampleRate)];
}

static OSStatus AEAudioPasteboardReaderInputProc(AudioConverterRef inAudioConverter,
                                                 UInt32 * ioNumberDataPackets,
                                                 AudioBufferList * ioData,
                                                 AudioStreamPacketDescription ** outDataPacketDescription,
                                                 void * inUserData) {
    
    AEAudioPasteboardReader * THIS = (__bridge AEAudioPasteboardReader *)inUserData;
    
    if ( THIS->_index == THIS->_blocks.count ) {
        return kFinishedStatus;
    }
    
    NSData * block = THIS->_blocks[THIS->_index];
    size_t remainingBytes = block.length - THIS->_offset;
    size_t bufferBytes = MIN(*ioNumberDataPackets * THIS->_originalFormat.mBytesPerFrame, remainingBytes);
    
    *ioNumberDataPackets = (UInt32)bufferBytes / THIS->_originalFormat.mBytesPerFrame;
    
    ioData->mBuffers[0].mData = (void *)block.bytes + THIS->_offset;
    ioData->mBuffers[0].mDataByteSize = (UInt32)bufferBytes;
    
    if ( bufferBytes == remainingBytes ) {
        THIS->_offset = 0;
        THIS->_index++;
    } else {
        THIS->_offset += bufferBytes;
    }
    
    return noErr;
}

@end
