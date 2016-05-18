//
//  AEAudioFileOutput.h
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 7/04/2016.
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
#import "AETime.h"
#import "AETypes.h"

@class AERenderer;

//! Completion block
typedef void (^AEAudioFileOutputCompletionBlock)();

//! Condition block, for use with
//! @link AEAudioFileOutput::runUntilCondition:completionBlock: runUntilCondition:completionBlock: @endlink
typedef BOOL (^AEAudioFileOutputConditionBlock)();

/*!
 * File output
 *
 *  This class implements an offline (i.e. faster-than-realtime) render to file.
 *  It can be used in place of AEAudioUnitOutput, for instance, and will write
 *  to disk rather than sending audio to the device output.
 *
 *  Note that because this class runs the render loop as fast as it can write
 *  to disk, it isn't suitable for render loops that receive live audio.
 */
@interface AEAudioFileOutput : NSObject

/*!
 * Initializer
 *
 * @param renderer Renderer to use to drive processing
 * @param url URL to the file to write to
 * @param type The type of the file to write
 * @param sampleRate Sample rate to use
 * @param channelCount Number of channels
 * @param error If not NULL, the error on output
 */
- (instancetype _Nullable)initWithRenderer:(AERenderer * _Nonnull)renderer
                                       URL:(NSURL * _Nonnull)url
                                      type:(AEAudioFileType)type
                                sampleRate:(double)sampleRate
                              channelCount:(int)channelCount
                                     error:(NSError * _Nullable * _Nullable)error;

/*!
 * Run offline rendering for a specified duration
 *
 *  You may perform multiple runs, prior to calling finishWriting.
 *  Rendering will occur on a secondary thread.
 *
 * @param duration Duration to run for, in seconds
 * @param completionBlock Block to perform on main thread when render has completed
 */
- (void)runForDuration:(AESeconds)duration completionBlock:(AEAudioFileOutputCompletionBlock _Nonnull)completionBlock;

/*!
 * Run offline rendering until a given condition
 *
 *  Rendering will continue, on a secondary thread, until the given block returns YES.
 *
 *  You may perform multiple runs, prior to calling finishWriting.
 *
 * @param conditionBlock Block to be called on the secondary rendering thread for each
 *  render cycle to determine whether recording should stop. Return YES to stop; NO to continue.
 * @param completionBlock Block to perform on main thread when render has completed
 */
- (void)runUntilCondition:(AEAudioFileOutputConditionBlock _Nonnull)conditionBlock
          completionBlock:(AEAudioFileOutputCompletionBlock _Nonnull)completionBlock;

/*!
 * Finish writing the file
 */
- (void)finishWriting;

//! The renderer. You may change this between runs, but not during a run.
@property (nonatomic, strong) AERenderer * _Nullable renderer;

//! The sample rate
@property (nonatomic, readonly) double sampleRate;

//! The channel count
@property (nonatomic, readonly) int numberOfChannels;

//! The URL of the output file
@property (nonatomic, strong, readonly) NSURL * _Nonnull fileURL;

//! The number of frames recorded so far
@property (nonatomic, readonly) UInt32 numberOfFramesRecorded;

@end

    
#ifdef __cplusplus
}
#endif
