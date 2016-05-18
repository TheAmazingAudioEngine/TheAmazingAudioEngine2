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
 * Rate limit an operation
 *
 *  This can be used to prevent spamming error messages to the console
 *  when something goes wrong.
 */
BOOL AERateLimit(void);

/*!
 * Check an OSStatus condition
 *
 * @param result The result
 * @param operation A description of the operation, for logging purposes
 */
#define AECheckOSStatus(result,operation) (_AECheckOSStatus((result),(operation),strrchr(__FILE__, '/')+1,__LINE__))
static inline BOOL _AECheckOSStatus(OSStatus result, const char * _Nonnull operation, const char * _Nonnull file, int line) {
    if ( result != noErr ) {
        if ( AERateLimit() ) {
            int fourCC = CFSwapInt32HostToBig(result);
            if ( isascii(((char*)&fourCC)[0]) && isascii(((char*)&fourCC)[1]) && isascii(((char*)&fourCC)[2]) ) {
                NSLog(@"%s:%d: %s: '%4.4s' (%d)", file, line, operation, (char*)&fourCC, (int)result);
            } else {
                NSLog(@"%s:%d: %s: %d", file, line, operation, (int)result);
            }
        }
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
ExtAudioFileRef _Nullable AEExtAudioFileRefCreate(NSURL * _Nonnull url, AEAudioFileType fileType, double sampleRate,
                                                  int channelCount, NSError * _Nullable * _Nullable error);

#ifdef __cplusplus
}
#endif
