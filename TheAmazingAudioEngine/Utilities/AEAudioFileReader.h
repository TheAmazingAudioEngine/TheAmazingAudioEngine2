//
//  AEAudioFileReader.h
//  TheAmazingAudioEngine
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

#ifdef __cplusplus
extern "C" {
#endif

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

/*!
 * Load block
 *
 * @param audio Audio buffer list containing the fully-loaded audio. You are responsible for
 *  deallocating this buffer. If an error occurred, this will be NULL.
 * @param length The length of the audio, in frames
 * @param error The error, if one occurred
 */
typedef void (^AEAudioFileReaderLoadBlock)(AudioBufferList * _Nullable audio,
                                           UInt32 length,
                                           NSError * _Nullable error);

/*!
 * Incremental read block
 *
 * @param audio Audio buffer list containing a small amount of loaded audio
 * @param length The length of the buffer list
 */
typedef void (^AEAudioFileReaderIncrementalReadBlock)(const AudioBufferList * _Nonnull audio, UInt32 length);

/*!
 * Completion block
 *
 * @param error If an error occurred, the error; otherwise NULL
 */
typedef void (^AEAudioFileReaderCompletionBlock)(NSError * _Nullable error);

@class AEAudioFileReader;

/*!
 * Audio file reader
 *
 *  This class is used to load an audio file. It can be used to either load an audio
 *  file completely into memory in a single operation, or to incrementally read pieces of
 *  the file.
 *
 *  Loading is done on a background thread.
 *
 *  Note that for live playback, you should use AEAudioFilePlayerModule.
 */
@interface AEAudioFileReader : NSObject

/*!
 * Get info for a file
 *
 * @param url               URL to the file
 * @param audioDescription  On output, if not NULL, will be filled with the file's audio description
 * @param lengthInFrames    On output, if not NULL, will indicated the file length in frames
 * @param error             If not NULL, and an error occurs, this contains the error that occurred
 * @return YES if file info was loaded successfully
 */
+ (BOOL)infoForFileAtURL:(NSURL * _Nonnull)url
        audioDescription:(AudioStreamBasicDescription * _Nullable)audioDescription
                  length:(UInt32 * _Nullable)lengthInFrames
                   error:(NSError * _Nullable * _Nullable)error;

/*!
 * Load a file into memory all at once
 *
 *  Will load the entire file into memory in a background thread, then call
 *  the completion block on the main thread when finished.
 *
 *  Note that this is not suitable for large audio files, as the entire file
 *  will be loaded into memory.
 *
 * @param url URL to the file to load
 * @param targetAudioDescription The audio description for the loaded audio (e.g. AEAudioDescription)
 * @param block Block to call when load has finished
 */
+ (instancetype _Nonnull)loadFileAtURL:(NSURL * _Nonnull)url
                targetAudioDescription:(AudioStreamBasicDescription)targetAudioDescription
                       completionBlock:(AEAudioFileReaderLoadBlock _Nonnull)block;

/*!
 * Read file incrementally, with a read block
 *
 *  Will load the file incrementally, calling the reader block with fixed-size 
 *  pieces of audio.
 *
 * @param url URL to the file to load
 * @param targetAudioDescription The audio description for the loaded audio (e.g. AEAudioDescription)
 * @param readBlock Block to call for each segment of the file; will be called on a background thread
 * @param completionBlock Block to call on main thread when read operation has completed, or an error occurs
 */
+ (instancetype _Nonnull)readFileAtURL:(NSURL * _Nonnull)url
                targetAudioDescription:(AudioStreamBasicDescription)targetAudioDescription
                             readBlock:(AEAudioFileReaderIncrementalReadBlock _Nullable)readblock
                       completionBlock:(AEAudioFileReaderCompletionBlock _Nonnull)completionBlock;

/*!
 * Read file incrementally, with a read block and block size
 *
 *  Will load the file incrementally, calling the reader block with fixed-size
 *  pieces of audio that match the block size.
 *
 * @param url URL to the file to load
 * @param targetAudioDescription The audio description for the loaded audio (e.g. AEAudioDescription)
 * @param readBlock Block to call for each segment of the file; will be called on a background thread
 * @param completionBlock Block to call on main thread when read operation has completed, or an error occurs
 * @param blockSize The size of blocks to receive
 */
+ (instancetype _Nonnull)readFileAtURL:(NSURL * _Nonnull)url
                targetAudioDescription:(AudioStreamBasicDescription)targetAudioDescription
                             readBlock:(AEAudioFileReaderIncrementalReadBlock _Nullable)readblock
                       completionBlock:(AEAudioFileReaderCompletionBlock _Nonnull)completionBlock
                             blockSize:(UInt32)blockSize;


/*!
 * Cancel a load operation
 */
- (void)cancel;

@end

#ifdef __cplusplus
}
#endif
