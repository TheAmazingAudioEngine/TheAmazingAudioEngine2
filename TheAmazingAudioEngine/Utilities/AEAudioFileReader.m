//
//  AEAudioFileReader.m
//  The Amazing Audio Engine
//
//  Created by Michael Tyson on 17/04/2012.
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

#import "AEAudioFileReader.h"
#import "AEUtilities.h"
#import "AEAudioBufferListUtilities.h"

static const UInt32 kDefaultReadSize = 4096;
static const UInt32 kMaxAudioFileReadSize = 16384;

@interface AEAudioFileReader ()
@property (nonatomic, strong) NSURL *url;
@property (nonatomic) AudioStreamBasicDescription targetAudioDescription;
@property (nonatomic, copy) AEAudioFileReaderLoadBlock loadBlock;
@property (nonatomic, copy) AEAudioFileReaderIncrementalReadBlock readBlock;
@property (nonatomic, copy) AEAudioFileReaderCompletionBlock readCompletionBlock;
@property (nonatomic) UInt32 readBlockSize;
@property (nonatomic) BOOL cancelled;
@end

@implementation AEAudioFileReader

+ (BOOL)infoForFileAtURL:(NSURL*)url audioDescription:(AudioStreamBasicDescription*)audioDescription
                  length:(UInt32*)lengthInFrames error:(NSError**)error {
    
    if ( audioDescription ) memset(audioDescription, 0, sizeof(AudioStreamBasicDescription));
    
    ExtAudioFileRef audioFile;
    OSStatus status;
    
    // Open file
    status = ExtAudioFileOpenURL((__bridge CFURLRef)url, &audioFile);
    if ( !AECheckOSStatus(status, "ExtAudioFileOpenURL") ) {
        if ( error ) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status 
                                              userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Couldn't open the audio file", @"")}];
        return NO;
    }
        
    if ( audioDescription ) {
        // Get data format
        UInt32 size = sizeof(AudioStreamBasicDescription);
        status = ExtAudioFileGetProperty(audioFile, kExtAudioFileProperty_FileDataFormat, &size, audioDescription);
        if ( !AECheckOSStatus(status, "ExtAudioFileGetProperty") ) {
            if ( error ) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status 
                                                  userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Couldn't read the audio file", @"")}];
            return NO;
        }
    }    
    
    if ( lengthInFrames ) {
        // Get length
        UInt64 fileLengthInFrames = 0;
        UInt32 size = sizeof(fileLengthInFrames);
        status = ExtAudioFileGetProperty(audioFile, kExtAudioFileProperty_FileLengthFrames, &size, &fileLengthInFrames);
        if ( !AECheckOSStatus(status, "ExtAudioFileGetProperty(kExtAudioFileProperty_FileLengthFrames)") ) {
            ExtAudioFileDispose(audioFile);
            if ( error ) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status 
                                                  userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Couldn't read the audio file", @"")}];
            return NO;
        }
        *lengthInFrames = (UInt32)fileLengthInFrames;
    }
    
    ExtAudioFileDispose(audioFile);
    
    return YES;
}

+ (instancetype)loadFileAtURL:(NSURL *)url targetAudioDescription:(AudioStreamBasicDescription)targetAudioDescription
              completionBlock:(AEAudioFileReaderLoadBlock _Nonnull)block {
    AEAudioFileReader * reader = [AEAudioFileReader new];
    reader.url = url;
    reader.targetAudioDescription = targetAudioDescription;
    reader.loadBlock = block;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        [reader read];
    });
    return reader;
}

+ (instancetype)readFileAtURL:(NSURL *)url
       targetAudioDescription:(AudioStreamBasicDescription)targetAudioDescription
                    readBlock:(AEAudioFileReaderIncrementalReadBlock)readblock
              completionBlock:(AEAudioFileReaderCompletionBlock)completionBlock {

    return [self readFileAtURL:url targetAudioDescription:targetAudioDescription readBlock:readblock
               completionBlock:completionBlock blockSize:kDefaultReadSize];
}

+ (instancetype)readFileAtURL:(NSURL *)url
       targetAudioDescription:(AudioStreamBasicDescription)targetAudioDescription
                    readBlock:(AEAudioFileReaderIncrementalReadBlock)readblock
              completionBlock:(AEAudioFileReaderCompletionBlock)completionBlock
                    blockSize:(UInt32)blockSize {
    AEAudioFileReader * reader = [AEAudioFileReader new];
    reader.url = url;
    reader.targetAudioDescription = targetAudioDescription;
    reader.readBlock = readblock;
    reader.readCompletionBlock = completionBlock;
    reader.readBlockSize = blockSize;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        [reader read];
    });
    return reader;
}

- (void)cancel {
    self.cancelled = YES;
}

- (void)read {
    ExtAudioFileRef audioFile;
    OSStatus status;
    
    // Open file
    status = ExtAudioFileOpenURL((__bridge CFURLRef)_url, &audioFile);
    if ( !AECheckOSStatus(status, "ExtAudioFileOpenURL") ) {
        [self reportError:[NSError errorWithDomain:NSOSStatusErrorDomain code:status
                           userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Couldn't open the audio file", @"")}]];
        return;
    }
    
    // Get file data format
    AudioStreamBasicDescription fileAudioDescription;
    UInt32 size = sizeof(fileAudioDescription);
    status = ExtAudioFileGetProperty(audioFile, kExtAudioFileProperty_FileDataFormat, &size, &fileAudioDescription);
    if ( !AECheckOSStatus(status, "ExtAudioFileGetProperty(kExtAudioFileProperty_FileDataFormat)") ) {
        ExtAudioFileDispose(audioFile);
        [self reportError:[NSError errorWithDomain:NSOSStatusErrorDomain code:status
                            userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Couldn't read the audio file", @"")}]];
        return;
    }
    
    // Apply client format
    if ( _targetAudioDescription.mSampleRate < DBL_EPSILON ) {
        _targetAudioDescription.mSampleRate = fileAudioDescription.mSampleRate;
    }
    
    status = ExtAudioFileSetProperty(audioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(_targetAudioDescription), &_targetAudioDescription);
    if ( !AECheckOSStatus(status, "ExtAudioFileSetProperty(kExtAudioFileProperty_ClientDataFormat)") ) {
        ExtAudioFileDispose(audioFile);
        int fourCC = CFSwapInt32HostToBig(status);
        [self reportError:[NSError errorWithDomain:NSOSStatusErrorDomain code:status
                            userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:
                              NSLocalizedString(@"Couldn't convert the audio file (error %d/%4.4s)", @""),
                                status, (char*)&fourCC]}]];
        return;
    }
    
    if ( _targetAudioDescription.mChannelsPerFrame > fileAudioDescription.mChannelsPerFrame ) {
        // More channels in target format than file format - set up a map to duplicate channel
        SInt32 channelMap[8];
        AudioConverterRef converter;
        AECheckOSStatus(ExtAudioFileGetProperty(audioFile, kExtAudioFileProperty_AudioConverter, &size, &converter),
                    "ExtAudioFileGetProperty(kExtAudioFileProperty_AudioConverter)");
        for ( int outChannel=0, inChannel=0; outChannel < _targetAudioDescription.mChannelsPerFrame; outChannel++ ) {
            channelMap[outChannel] = inChannel;
            if ( inChannel+1 < fileAudioDescription.mChannelsPerFrame ) inChannel++;
        }
        AECheckOSStatus(AudioConverterSetProperty(converter, kAudioConverterChannelMap, sizeof(SInt32)*_targetAudioDescription.mChannelsPerFrame, channelMap),
                    "AudioConverterSetProperty(kAudioConverterChannelMap)");
        CFArrayRef config = NULL;
        AECheckOSStatus(ExtAudioFileSetProperty(audioFile, kExtAudioFileProperty_ConverterConfig, sizeof(CFArrayRef), &config),
                    "ExtAudioFileSetProperty(kExtAudioFileProperty_ConverterConfig)");
    }
    
    // Determine length in frames (in original file's sample rate)
    UInt64 fileLengthInFrames;
    size = sizeof(fileLengthInFrames);
    status = ExtAudioFileGetProperty(audioFile, kExtAudioFileProperty_FileLengthFrames, &size, &fileLengthInFrames);
    if ( !AECheckOSStatus(status, "ExtAudioFileGetProperty(kExtAudioFileProperty_FileLengthFrames)") ) {
        ExtAudioFileDispose(audioFile);
        [self reportError:[NSError errorWithDomain:NSOSStatusErrorDomain code:status
                            userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Couldn't read the audio file", @"")}]];
        return;
    }
    
    // Calculate the true length in frames, given the original and target sample rates
    fileLengthInFrames = ceil(fileLengthInFrames * (_targetAudioDescription.mSampleRate / fileAudioDescription.mSampleRate));
    
    // Prepare buffer
    AudioBufferList *bufferList = AEAudioBufferListCreateWithFormat(_targetAudioDescription,
                                    _readBlock ? _readBlockSize : (UInt32)fileLengthInFrames);
    if ( !bufferList ) {
        ExtAudioFileDispose(audioFile);
        [self reportError:[NSError errorWithDomain:NSPOSIXErrorDomain code:ENOMEM
                            userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Not enough memory to open file", @"")}]];
        return;
    }
    
    // Perform read in multiple small chunks (otherwise ExtAudioFileRead crashes when performing sample rate conversion)
    UInt32 readFrames = 0;
    AEAudioBufferListCopyOnStack(scratchBufferList, bufferList, 0);
    while ( readFrames < fileLengthInFrames && !_cancelled ) {
        UInt32 blockSize = MIN(_readBlock ? _readBlockSize : kMaxAudioFileReadSize, (UInt32)fileLengthInFrames - readFrames);
        AEAudioBufferListAssignWithFormat(scratchBufferList, bufferList, _targetAudioDescription,
                                          _readBlock ? 0 : readFrames, blockSize);
        
        // Perform read
        status = ExtAudioFileRead(audioFile, &blockSize, scratchBufferList);
        
        if ( status != noErr ) {
            ExtAudioFileDispose(audioFile);
            AEAudioBufferListFree(bufferList);
            int fourCC = CFSwapInt32HostToBig(status);
            [self reportError:[NSError errorWithDomain:NSOSStatusErrorDomain code:status
                               userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:
                                NSLocalizedString(@"Couldn't read the audio file (error %d/%4.4s)", @""),
                                  status, (char*)&fourCC]}]];
            return;
        }
        
        if ( blockSize == 0 ) {
            // Termination condition
            break;
        }
        
        if ( _readBlock ) {
            _readBlock(bufferList, blockSize);
        }
        
        readFrames += blockSize;
    }
    
    if ( _readBlock || _cancelled ) {
        AEAudioBufferListFree(bufferList);
        bufferList = NULL;
    }
    
    // Clean up        
    ExtAudioFileDispose(audioFile);
    
    // Call completion blocks
    if ( !_cancelled ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( _cancelled ) {
                if ( _loadBlock ) {
                    AEAudioBufferListFree(bufferList);
                }
                return;
            }
            
            if ( _loadBlock ) {
                _loadBlock(bufferList, readFrames, NULL);
            } else {
                _readCompletionBlock(NULL);
            }
        });
    }
}

- (void)reportError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( _loadBlock ) {
            _loadBlock(NULL, 0, error);
        } else {
            _readCompletionBlock(error);
        }
    });
}

@end
