//
//  AEAudioPasteboard.h
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 23/08/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import "AETypes.h"

extern NSString * const AEAudioPasteboardInfoNumberOfChannelsKey; //!< Number of audio channels
extern NSString * const AEAudioPasteboardInfoLengthInFramesKey; //!< Length of audio, in frames
extern NSString * const AEAudioPasteboardInfoDurationInSecondsKey; //!< Duration of audio, in seconds
extern NSString * const AEAudioPasteboardInfoSampleRateKey; //!< Sample rate of audio, in Hz
extern NSString * const AEAudioPasteboardInfoSizeInBytesKey; //!< Size of audio, in bytes

/*!
 * Notification called upon change of pasteboard contents
 * 
 *  Note: Due to limitations of the UIPasteboard, this notification will not be called while the app is in the background.
 *  Instead, it will be called once the app enters the foreground again.
 */
extern NSString * const AEAudioPasteboardChangedNotification;

extern NSString * const AEAudioPasteboardErrorDomain;

enum {
    AEAudioPasteboardErrorCodeNoItem,
};

/*!
 * Generator block, used when copying audio
 *
 * @param buffer The buffer to write to
 * @param ioFrames On input, number of frames to write; on output, number of frames written
 * @param finished When all audio has been generated, set this to YES to finish the operation
 */
typedef void (^AEAudioPasteboardGeneratorBlock)(AudioBufferList * buffer, UInt32 * ioFrames, BOOL * finished);

@class AEAudioPasteboardReader;

/*!
 * Audio Pasteboard interface
 *
 *  This class manages importing from and exporting to the general audio pasteboard.
 */
@interface AEAudioPasteboard : NSObject

/*!
 * Get info about the current pasteboard item
 *
 *  Returns a dictionary of items (keyed by the AEAudioPasteboardInfo keys), or nil if there's no audio on the pasteboard
 */
+ (NSDictionary *)infoForGeneralPasteboardItem;

/*!
 * Paste the pasteboard contents to a file
 *
 *  This method asynchronously writes the pasteboard contents to a file of the given type, rate and channel count.
 *
 * @param path The target file path
 * @param fileType The type of the file to create
 * @param sampleRate The target sample rate, or 0 to use the sample rate of the pasteboard audio
 * @param channelCount The target channel count, or 0 to use the channel count of the pasteboard audio
 * @param completionBlock Block to call upon completion, or failure
 */
+ (void)pasteToFileAtPath:(NSString *)path fileType:(AEAudioFileType)fileType sampleRate:(double)sampleRate
             channelCount:(int)channelCount completionBlock:(void (^)(NSError * errorOrNil))completionBlock;

/*!
 * Copy to the pasteboard from a file
 *
 *  This method asynchronously writes the contents of an audio file to the pasteboard.
 *
 * @param path The path of the source audio file; all Core Audio-supported formats accepted
 * @param completionBlock Block to call upon completion, or failure
 */
+ (void)copyFromFileAtPath:(NSString *)path completionBlock:(void (^)(NSError * errorOrNil))completionBlock;

/*!
 * Copy to the pasteboard using a generator block
 *
 *  Use this method to write to the pasteboard using audio generated dynamically using the given block.
 *
 * @param generator The generator block
 * @param audioDescription The audio description describing the audio produced by the generator block
 * @param completionBlock Block to call upon completion, or failure
 */
+ (void)copyUsingGenerator:(AEAudioPasteboardGeneratorBlock)generator
          audioDescription:(AudioStreamBasicDescription)audioDescription
           completionBlock:(void (^)(NSError * errorOrNil))completionBlock;

@end

/*!
 * Audio Pasteboard reader
 *
 *  Use this method to incrementally read the contents of the audio pasteboard
 */
@interface AEAudioPasteboardReader : NSObject

/*!
 * Create an instance for reading
 */
+ (instancetype)readerForGeneralPasteboardItem;

/*!
 * Read the next piece of audio into the given buffer
 *
 *  When the reader reaches the end of the audio on the pasteboard, ioFrames will contain
 *  a value less than the requested number of frames, or zero on the next call.
 *
 * @param buffer The buffer to write to
 * @param ioFrames On input, the number of frames to write; on output, number of frames written
 */
- (void)readIntoBuffer:(AudioBufferList *)buffer length:(UInt32 *)ioFrames;

/*!
 * Reset the reader to the beginning of the clipboard contents
 */
- (void)reset;

//! The client format to use for reading
@property (nonatomic) AudioStreamBasicDescription clientFormat;

//! The original format of the clipboard audio
@property (nonatomic, readonly) AudioStreamBasicDescription originalFormat;

@end
