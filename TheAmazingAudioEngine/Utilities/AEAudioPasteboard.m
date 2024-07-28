//
//  AEAudioPasteboard.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 23/08/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import "AEAudioPasteboard.h"
#import "AEUtilities.h"
#import "AEAudioBufferListUtilities.h"
#import <AVFoundation/AVFoundation.h>

#if TARGET_OS_IPHONE
#import <MobileCoreServices/MobileCoreServices.h>
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

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
    UInt32 sourceBufferLength;
    AudioStreamBasicDescription sourceFormat;
    BOOL finished;
} input_proc_data_t;

#pragma mark -

@implementation AEAudioPasteboard

+ (void)load {
#if TARGET_OS_IPHONE
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // UIPasteboard does not send its change notification when an app is in the background. So we need to
        // take note of the change count when we resign active, and compare when we resume foreground status again.
        __block NSInteger lastPasteboardChange;
        NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
        [nc addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:nil usingBlock:^(NSNotification * note) {
            lastPasteboardChange = UIPasteboard.generalPasteboard.changeCount;
        }];
        [nc addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:nil usingBlock:^(NSNotification * note) {
            if ( UIPasteboard.generalPasteboard.changeCount != lastPasteboardChange ) {
                [[NSNotificationCenter defaultCenter] postNotificationName:AEAudioPasteboardChangedNotification object:nil];
            }
        }];
        
        // Watch UIPasteboard change notifications and re-post as AEAudioPasteboardChangedNotification
        [nc addObserverForName:UIPasteboardChangedNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            [[NSNotificationCenter defaultCenter] postNotificationName:AEAudioPasteboardChangedNotification object:nil];
        }];
    });
#else
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // NSPasteboard does not send change notifications by default. We need to poll for changes.
        __block NSInteger lastChangeCount = [[NSPasteboard generalPasteboard] changeCount];
        NSTimer * pasteboardPollingTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
            NSInteger changeCount = [[NSPasteboard generalPasteboard] changeCount];
            if ( changeCount != lastChangeCount ) {
                lastChangeCount = changeCount;
                [[NSNotificationCenter defaultCenter] postNotificationName:AEAudioPasteboardChangedNotification object:nil];
            }
        }];
        pasteboardPollingTimer.tolerance = 1.0;
        [[NSRunLoop mainRunLoop] addTimer:pasteboardPollingTimer forMode:NSRunLoopCommonModes];
    });
#endif
}

+ (BOOL)hasAudioOnPasteboard {
#if TARGET_OS_IPHONE
    UIPasteboard * pasteboard = UIPasteboard.generalPasteboard;
    return [pasteboard containsPasteboardTypes:[self audioUTTypes]] || [self hasFilesOfTypes:[self audioUTTypes]];
#else
    NSPasteboard * pasteboard = NSPasteboard.generalPasteboard;
    return [pasteboard canReadItemWithDataConformingToTypes:[self audioUTTypes]] || [self hasFilesOfTypes:[self audioUTTypes]];
#endif
}

+ (BOOL)hasFilesOfTypes:(NSArray<NSString *> *)types {
#if TARGET_OS_IPHONE
    if ( ![UIPasteboard.generalPasteboard containsPasteboardTypes:@[(NSString *)kUTTypeFileURL]] ) {
        return NO;
    }
    NSArray *items = UIPasteboard.generalPasteboard.items;
#else
    if ( ![NSPasteboard.generalPasteboard canReadItemWithDataConformingToTypes:@[(NSString *)kUTTypeFileURL]] ) {
        return NO;
    }
    NSArray *items = [NSPasteboard.generalPasteboard pasteboardItems];
#endif
    
    for ( id item in items ) {
        NSURL *fileURL = nil;
#if TARGET_OS_IPHONE
        fileURL = [NSURL URLWithString:[[NSString alloc] initWithData:item[(NSString *)kUTTypeFileURL] encoding:NSUTF8StringEncoding]];
#else
        fileURL = [NSURL URLWithString:[item stringForType:(NSString *)kUTTypeFileURL]];
#endif
        if ( fileURL && [self isFileURL:fileURL ofTypes:types] ) {
            return YES;
        }
    }
    
    return NO;
}

+ (BOOL)isFileURL:(NSURL *)url ofTypes:(NSArray<NSString *> *)types {
    NSError *error = nil;
    NSString *fileType = nil;
    [url getResourceValue:&fileType forKey:NSURLTypeIdentifierKey error:&error];

    if ( error != nil ) {
        return NO;
    }

    for ( NSString *type in types ) {
        if ( UTTypeConformsTo((__bridge CFStringRef)fileType, (__bridge CFStringRef)type) ) {
            return YES;
        }
    }

    return NO;
}

+ (void)loadInfoForAudioPasteboardItemWithCompletionBlock:(void (^)(NSDictionary *))block {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSData * data = [self dataForAudioOnPasteboard];
        if ( !data ) {
            dispatch_async(dispatch_get_main_queue(), ^{ block(nil); });
            return;
        }
        
        AudioFileID audioFile;
        ExtAudioFileRef extAudioFile = [self extAudioFileForData:data forWriting:NO audioFile:&audioFile];
        if ( !extAudioFile ) {
            dispatch_async(dispatch_get_main_queue(), ^{ block(nil); });
            return;
        }
        
        AudioStreamBasicDescription audioDescription;
        UInt32 size = sizeof(audioDescription);
        ExtAudioFileGetProperty(extAudioFile, kExtAudioFileProperty_FileDataFormat, &size, &audioDescription);
        
        SInt64 length;
        size = sizeof(length);
        ExtAudioFileGetProperty(extAudioFile, kExtAudioFileProperty_FileLengthFrames, &size, &length);
        
        ExtAudioFileDispose(extAudioFile);
        AudioFileClose(audioFile);
        
        if ( length == 0 ) {
            dispatch_async(dispatch_get_main_queue(), ^{ block(nil); });
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{ block(@{
            AEAudioPasteboardInfoNumberOfChannelsKey: @(audioDescription.mChannelsPerFrame),
            AEAudioPasteboardInfoLengthInFramesKey: @(length),
            AEAudioPasteboardInfoDurationInSecondsKey: @(length / audioDescription.mSampleRate),
            AEAudioPasteboardInfoSampleRateKey: @(audioDescription.mSampleRate),
            AEAudioPasteboardInfoSizeInBytesKey: @(data.length)
        }); });
    });
}

+ (void)pasteToFileAtPath:(NSString *)path fileType:(AEAudioFileType)fileType sampleRate:(double)sampleRate
             channelCount:(int)channelCount completionBlock:(void (^)(NSError * errorOrNil))completionBlock {
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        
        // Get reader
        AEAudioPasteboardReader * reader = [AEAudioPasteboardReader readerForAudioPasteboardItem];
        if ( !reader ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock([NSError errorWithDomain:AEAudioPasteboardErrorDomain code:AEAudioPasteboardErrorCodeNoItem
                                                userInfo:nil]);
            });
            return;
        }
        
        // Create audio file and configure for format
        NSError * error = nil;
        ExtAudioFileRef audioFile =
            AEExtAudioFileCreate([NSURL fileURLWithPath:path], fileType,
                                 sampleRate ? sampleRate : reader.originalFormat.mSampleRate,
                                 channelCount ? channelCount : reader.originalFormat.mChannelsPerFrame, &error);
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
        if ( remainingFrames == 0 || *ioFrames == 0 ) {
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
        OSStatus status = noErr;
        
        AudioFileID audioFile;
        ExtAudioFileRef extAudioFile = [self extAudioFileForData:audioData forWriting:YES audioFile:&audioFile];
        
        status = ExtAudioFileSetProperty(extAudioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(sourceAudioDescription), &sourceAudioDescription);
        if ( !AECheckOSStatus(status, "ExtAudioFileSetProperty") ) {
            ExtAudioFileDispose(extAudioFile);
            AudioFileClose(audioFile);
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock([NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil]);
            });
        }
        
        // Setup buffers
        const UInt32 processBlockFrames = 4096;
        AudioBufferList * buffer = AEAudioBufferListCreateWithFormat(sourceAudioDescription, processBlockFrames);
        
        // Process audio
        BOOL finished = NO;
        while ( !finished ) {
            UInt32 block = processBlockFrames;
            AEAudioBufferListSetLengthWithFormat(buffer, sourceAudioDescription, block);
            generator(buffer, &block, &finished);
            AEAudioBufferListSetLengthWithFormat(buffer, sourceAudioDescription, block);
            status = ExtAudioFileWrite(extAudioFile, block, buffer);
            if ( !AECheckOSStatus(status, "ExtAudioFileWrite") ) {
                break;
            }
        }
        
        ExtAudioFileDispose(extAudioFile);
        AudioFileClose(audioFile);
        AEAudioBufferListFree(buffer);
        
        if ( !AECheckOSStatus(status, "AudioConverterFillComplexBuffer") ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock([NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil]);
            });
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Assign to clipboard
#if TARGET_OS_IPHONE
            [UIPasteboard.generalPasteboard setData:audioData forPasteboardType:(NSString *)kUTTypeAudio];
#else
            [NSPasteboard.generalPasteboard declareTypes:@[(NSString *)kUTTypeAudio] owner:nil];
            [NSPasteboard.generalPasteboard setData:audioData forType:(NSString *)kUTTypeAudio];
#endif
            
            completionBlock(nil);
        });
    });
}

#pragma mark - Helpers

+ (NSArray <NSString *> *)audioUTTypes {
    return @[(NSString *)kUTTypeAudio, AVFileTypeWAVE, AVFileTypeAIFC, AVFileTypeAIFF, AVFileTypeAppleM4A, AVFileTypeAC3, AVFileTypeMPEGLayer3, AVFileTypeCoreAudioFormat];
}

+ (NSData *)dataForAudioOnPasteboard {
    NSArray * supportedTypes = [self audioUTTypes];

#if TARGET_OS_IPHONE
    UIPasteboard * pasteboard = UIPasteboard.generalPasteboard;
    if ( [pasteboard containsPasteboardTypes:supportedTypes] ) {
        for ( NSString * type in supportedTypes ) {
            NSIndexSet * itemSet = [pasteboard itemSetWithPasteboardTypes:@[type]];
            if ( itemSet.count > 0 ) {
                NSArray <NSData *> * dataArray = [pasteboard dataForPasteboardType:type inItemSet:itemSet];
                if ( dataArray.count == 1 ) {
                    return dataArray.firstObject;
                } else if ( dataArray.count > 1 ) {
                    NSMutableData * data = [NSMutableData data];
                    for ( NSData * block in dataArray ) {
                        [data appendData:block];
                    }
                    return data;
                }
            }
        }
    }
    
    if ( ![pasteboard containsPasteboardTypes:@[(NSString *)kUTTypeFileURL]] ) {
        return NULL;
    }
    
    NSArray *items = UIPasteboard.generalPasteboard.items;
#else
    NSPasteboard * pasteboard = NSPasteboard.generalPasteboard;
    if ( [pasteboard canReadItemWithDataConformingToTypes:supportedTypes] ) {
        for ( NSString * type in supportedTypes ) {
            NSData * data = [pasteboard dataForType:type];
            if ( data ) {
                return data;
            }
        }
    }
    if ( ![pasteboard canReadItemWithDataConformingToTypes:@[(NSString *)kUTTypeFileURL]] ) {
        return NULL;
    }
    
    NSArray *items = [NSPasteboard.generalPasteboard pasteboardItems];
#endif
    
    // Handle file URLs
    for ( id item in items ) {
        NSURL *fileURL = nil;
#if TARGET_OS_IPHONE
        NSString *urlString = [[NSString alloc] initWithData:item[(NSString *)kUTTypeFileURL] encoding:NSUTF8StringEncoding];
#else
        NSString *urlString = [item stringForType:(NSString *)kUTTypeFileURL];
#endif
        if ( urlString ) {
            fileURL = [NSURL URLWithString:urlString];
        }
        if ( fileURL && [self isFileURL:fileURL ofTypes:supportedTypes] ) {
            return [NSData dataWithContentsOfURL:fileURL];
        }
    }

    return NULL;
}

+ (ExtAudioFileRef)extAudioFileForData:(NSData *)data forWriting:(BOOL)write audioFile:(AudioFileID *)outAudioFile {
    *outAudioFile = NULL;
    
    if ( !data ) {
        return NULL;
    }
    
    AudioFileID audioFile = NULL;
    if ( write ) {
        AudioStreamBasicDescription audioDescription= {
            .mFormatID          = kAudioFormatLinearPCM,
            .mFormatFlags       = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian,
            .mChannelsPerFrame  = 2,
            .mBytesPerPacket    = 2 * sizeof(SInt16),
            .mFramesPerPacket   = 1,
            .mBytesPerFrame     = 2 * sizeof(SInt16),
            .mBitsPerChannel    = 8 * sizeof(SInt16),
            .mSampleRate        = 44100.0,
        };
        if ( !AECheckOSStatus(
                AudioFileInitializeWithCallbacks((__bridge void *)data,
                                                 AEAudioPasteboardRead,
                                                 AEAudioPasteboardWrite,
                                                 AEAudioPasteboardGetSize,
                                                 AEAudioPasteboardSetSize,
                                                 kAudioFileWAVEType,
                                                 &audioDescription,
                                                 0,
                                                 &audioFile), "AudioFileInitializeWithCallbacks") ) {
            return NULL;
        }
    } else {
        OSStatus status =
            AudioFileOpenWithCallbacks((__bridge void *)data, AEAudioPasteboardRead, NULL,
                                       AEAudioPasteboardGetSize, NULL, 0, &audioFile);
        if ( status == kAudioFileStreamError_UnsupportedFileType ) {
            status = AudioFileOpenWithCallbacks((__bridge void *)data, AEAudioPasteboardRead, NULL,
                                                AEAudioPasteboardGetSize, NULL, kAudioFileWAVEType, &audioFile);
        }
        
        if ( !AECheckOSStatus(status, "AudioFileOpenWithCallbacks") ) {
            return NULL;
        }
    }
    
    ExtAudioFileRef extAudioFile;
    if ( !AECheckOSStatus(ExtAudioFileWrapAudioFileID(audioFile, write, &extAudioFile), "ExtAudioFileWrapAudioFileID") ) {
        AudioFileClose(audioFile);
        return NULL;
    }
    
    *outAudioFile = audioFile;
    
    return extAudioFile;
}

static OSStatus AEAudioPasteboardRead(void * inClientData, SInt64 inPosition, UInt32 requestCount, void * buffer, UInt32 * actualCount) {
    NSData * data = (__bridge NSData *)inClientData;
    *actualCount = MIN(requestCount, (UInt32)(data.length - inPosition));
    [data getBytes:buffer range:NSMakeRange((NSUInteger)inPosition, *actualCount)];
    return noErr;
}

static OSStatus AEAudioPasteboardWrite(void * inClientData, SInt64 inPosition, UInt32 requestCount, const void * buffer, UInt32 * actualCount) {
    NSMutableData * data = (__bridge NSMutableData *)inClientData;
    if ( data.length < inPosition+requestCount ) {
        [data setLength:(NSUInteger)inPosition+requestCount];
    }
    [data replaceBytesInRange:NSMakeRange((NSUInteger)inPosition, requestCount) withBytes:buffer length:requestCount];
    *actualCount = requestCount;
    return noErr;
}

static SInt64 AEAudioPasteboardGetSize(void * inClientData) {
    NSData * data = (__bridge NSData *)inClientData;
    return data.length;
}

static OSStatus AEAudioPasteboardSetSize(void * inClientData, SInt64 inSize) {
    NSMutableData * data = (__bridge NSMutableData *)inClientData;
    [data setLength:(NSUInteger)inSize];
    return noErr;
}

@end

#pragma mark - Reader

@interface AEAudioPasteboardReader ()
@property (nonatomic, strong) NSData * data;
@property (nonatomic) AudioFileID audioFile;
@property (nonatomic) ExtAudioFileRef extAudioFile;
@end

@implementation AEAudioPasteboardReader

+ (instancetype)readerForAudioPasteboardItem {
    return [AEAudioPasteboardReader new];
}

- (instancetype)init {
    if ( !(self = [super init]) ) return nil;
    
    _clientFormat = AEAudioDescription;
    [self reset];
    
    if ( !self.data ) {
        return nil;
    }
    
    return self;
}

- (void)dealloc {
    if ( self.extAudioFile ) {
        ExtAudioFileDispose(self.extAudioFile);
        AudioFileClose(self.audioFile);
    }
}

- (void)setClientFormat:(AudioStreamBasicDescription)clientFormat {
    if ( !memcmp(&clientFormat, &_clientFormat, sizeof(clientFormat)) ) return;
    
    _clientFormat = clientFormat;
    
    if ( self.extAudioFile ) {
        AECheckOSStatus(ExtAudioFileSetProperty(self.extAudioFile, kExtAudioFileProperty_ClientDataFormat,  sizeof(_clientFormat), &_clientFormat),
                        "ExtAudioFileSetProperty(kExtAudioFileProperty_ClientDataFormat)");
    }
}

- (OSStatus)readIntoBuffer:(AudioBufferList *)buffer length:(UInt32 *)ioFrames {
    AEAudioBufferListSetLengthWithFormat(buffer, _clientFormat, *ioFrames);
    return ExtAudioFileRead(self.extAudioFile, ioFrames, buffer);
}

- (void)reset {
    if ( self.extAudioFile ) {
        ExtAudioFileDispose(self.extAudioFile);
        AudioFileClose(self.audioFile);
    }
    
    self.data = [AEAudioPasteboard dataForAudioOnPasteboard];
    if ( !self.data ) {
        return;
    }
    
    self.extAudioFile = [AEAudioPasteboard extAudioFileForData:self.data forWriting:NO audioFile:&_audioFile];
    if ( !self.extAudioFile ) {
        return;
    }
    
    AECheckOSStatus(ExtAudioFileSetProperty(self.extAudioFile, kExtAudioFileProperty_ClientDataFormat,  sizeof(_clientFormat), &_clientFormat),
                    "ExtAudioFileSetProperty(kExtAudioFileProperty_ClientDataFormat)");
    
    UInt32 size = sizeof(_originalFormat);
    AECheckOSStatus(ExtAudioFileGetProperty(self.extAudioFile, kExtAudioFileProperty_FileDataFormat,  &size, &_originalFormat),
                    "ExtAudioFileGetProperty(kExtAudioFileProperty_FileDataFormat)");
}

@end
