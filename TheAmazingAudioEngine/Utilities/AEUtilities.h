//
//  AEUtilities.h
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 23/03/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
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
#import "AETypes.h"

/*!
 * Create an AudioComponentDescription structure
 *
 * @param manufacturer  The audio component manufacturer (e.g. kAudioUnitManufacturer_Apple)
 * @param type          The type (e.g. kAudioUnitType_Generator)
 * @param subtype       The subtype (e.g. kAudioUnitSubType_AudioFilePlayer)
 * @returns An AudioComponentDescription structure with the given attributes
 */
AudioComponentDescription AEAudioComponentDescriptionMake(OSType manufacturer, OSType type, OSType subtype);

/*!
 * Compare two AudioComponentDescriptions
 *
 * @param a First AudioComponentDescription
 * @param b Second AudioComponentDescription
 */
BOOL AEAudioComponentDescriptionsEqual(AudioComponentDescription a, AudioComponentDescription b);

/*!
 * Convert a 14-character string to an AudioComponentDescription
 */
AudioComponentDescription AEStringToAudioComponentDescription(NSString * _Nonnull string);

/*!
 * Convert an AudioComponentDescription to a 14-character string
 */
NSString * _Nonnull AEAudioComponentDescriptionToString(AudioComponentDescription audioComponentDescription);

/*!
 * Convert a string to a four-CC type
 */
OSType AEStringToOSType(NSString * _Nonnull string);

/*!
 * Convert a four-CC type to a 4-character string
 */
NSString * _Nonnull AEOSTypeToString(OSType number);

/*!
 * Rate limit an operation
 *
 *  This can be used to prevent spamming error messages to the console
 *  when something goes wrong.
 */
BOOL AERateLimit(void);

/*!
 * An error occurred within AECheckOSStatus
 *
 *  Create a symbolic breakpoint with this function name to break on errors.
 */
void AEError(OSStatus result, const char * _Nonnull operation, const char * _Nonnull file, int line, va_list args);

/*!
 * Check an OSStatus condition
 *
 * @param result The result
 * @param operation A description of the operation, for logging purposes
 */
#define AECheckOSStatus(result, operation, ...) (_AECheckOSStatus((result), strrchr(__FILE__, '/')+1, __LINE__, (operation), ##__VA_ARGS__))
static inline BOOL _AECheckOSStatus(OSStatus result, const char * _Nonnull file, int line, const char * _Nonnull operation, ...) {
    if ( result != noErr ) {
        va_list args;
        va_start(args, operation);
        AEError(result, operation, file, line, args);
        va_end(args);
        return NO;
    }
    return YES;
}

/*!
 * Initialize an ExtAudioFileRef for writing to a file
 *
 *  This provides a simple way to create an audio file writer, initialised appropriately for the
 *  given file type. To begin recording asynchronously, you should use `ExtAudioFileWriteAsync(audioFile, 0, NULL);`
 *  to prime asynchronous recording. For writing on the main thread, use `ExtAudioFileWrite`.
 *
 *  Finish writing and close the file by using `ExtAudioFileDispose` once you are done.
 *
 *  Use this function only on the main thread.
 *
 * @param url URL to the file to write to
 * @param fileType The type of the file to write
 * @param sampleRate Sample rate to use for input & output
 * @param channelCount Number of channels for input & output
 * @param error If not NULL, the error on output
 * @return The initialized ExtAudioFileRef, or NULL on error
 */
ExtAudioFileRef _Nullable AEExtAudioFileCreate(NSURL * _Nonnull url, AEAudioFileType fileType, double sampleRate,
                                               int channelCount, NSError * _Nullable * _Nullable error);

    
/*!
 * Open an audio file for reading
 * 
 *  This utility creates a new reader instance, and returns the reader, the client format AudioStreamBasicDescription
 *  used for reading, and the total length in frames, both usually useful for operating on files.
 *
 *  It will be configured to use the standard AEAudioDescription format, with the channel count and sample rate
 *  determined by the file format - this configured format is returned via the outAudioDescription parameter.
 *  Use kExtAudioFileProperty_ClientDataFormat to change this if required.
 *
 * @param url URL to the file to read from
 * @param outAudioDescription On output, the AEAudioDescription-derived stream format for reading (the client format)
 * @param outLengthInFrames On output, the total length in frames
 * @param error If not NULL, the error on output
 * @return The initialized ExtAudioFileRef, or NULL on error
 */
ExtAudioFileRef _Nullable AEExtAudioFileOpen(NSURL * _Nonnull url, AudioStreamBasicDescription * _Nullable outAudioDescription,
                                             UInt64 * _Nullable outLengthInFrames, NSError * _Nullable * _Nullable error);


/*!
 * Lookup info about an audio file
 *
 * @param url URL to the file to inspect
 * @param outAudioDescription The file audio description
 * @param outLengthInFrames On output, the total length in frames
 * @param error If not NULL, the error on output
 * @return YES on success, NO on failure
 */
BOOL AEExtAudioFileInspect(NSURL * _Nonnull url, AudioStreamBasicDescription * _Nullable outAudioDescription,
                           UInt64 * _Nullable outLengthInFrames, NSError * _Nullable * _Nullable error);

#ifdef __cplusplus
}
#endif
