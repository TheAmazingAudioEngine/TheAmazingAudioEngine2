//
//  AEAudioFileRecorderModule.h
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 1/04/2016.
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
    
#import "AEAudioUnitModule.h"
#import "AETime.h"
#import "AETypes.h"

//! Completion block
typedef void (^AEAudioFileRecorderModuleCompletionBlock)();

/*!
 * Audio file recorder
 *
 *  This module records the top buffer stack item to a file on disk.
 *  After processing, it leaves the buffer stack intact.
 */
@interface AEAudioFileRecorderModule : AEModule

/*!
 * Default initialiser
 *
 * @param renderer The renderer
 * @param url URL to the file to write to
 * @param type The type of the file to write
 * @param error If not NULL, the error on output
 */
- (instancetype _Nullable)initWithRenderer:(AERenderer * _Nullable)renderer
                                       URL:(NSURL * _Nonnull)url
                                      type:(AEAudioFileType)type
                                     error:(NSError * _Nullable * _Nullable)error;

/*!
 * Begin recording
 *
 * @param time Time to begin recording, or 0 for "now"
 */
- (void)beginRecordingAtTime:(AEHostTicks)time;

/*!
 * Stop recording
 *
 * @param time Time to end recording, or 0 for "now"
 * @param block Block to perform once recording has completed
 */
- (void)stopRecordingAtTime:(AEHostTicks)time completionBlock:(AEAudioFileRecorderModuleCompletionBlock _Nullable)block;

@property (nonatomic, readonly) BOOL recording; //!< Whether recording is in progress
@property (nonatomic, readonly) AESeconds recordedTime; //!< Current recording length, in seconds
@end
    
#ifdef __cplusplus
}
#endif