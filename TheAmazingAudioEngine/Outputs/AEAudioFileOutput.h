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
    
extern const AEHostTicks AEAudioFileOutputInitialHostTicksValue; //!< Initial host ticks value for time zero

@class AERenderer;

/*!
 * Completion block
 *
 * @param error The error, if one occurred while writing
 */
typedef void (^AEAudioFileOutputCompletionBlock)(NSError * _Nullable error);

/*
 * Condition block
 *
 *  For use with @link AEAudioFileOutput::runUntilCondition:completionBlock: runUntilCondition:completionBlock: @endlink
 *
 * @returns Whether to stop (YES) or continue (NO)
 */
typedef BOOL (^AEAudioFileOutputConditionBlock)(void);

/*!
 * File output
 *
 *  This class implements an offline (i.e. faster-than-realtime) render to file.
 *  It can be used in place of AEAudioUnitOutput, for instance, and will write
 *  to disk rather than sending audio to the device output.
 *
 *  It can also be used in multi-track mode, outputting each stereo channel pair
 *  to a different audio file.
 *
 *  Note that because this class runs the render loop as fast as it can write
 *  to disk, it isn't suitable for render loops that receive live audio.
 */
@interface AEAudioFileOutput : NSObject

/*!
 * Look up file extension for a given type
 */
+ (NSString * _Nonnull)fileExtensionForType:(AEAudioFileType)type;

/*!
 * Initializer
 *
 * @param renderer Renderer to use to drive processing
 * @param path Path to the file (or folder, if channelCount > 2) to write to
 * @param type The type of the file to write
 * @param sampleRate Sample rate to use
 * @param channelCount Number of channels. If more than two, each stereo pair is output to a different file
 * @param multitrack Whether to output each stereo pair to a different file
 * @param error If not NULL, the error on output
 */
- (instancetype _Nullable)initWithRenderer:(AERenderer * _Nonnull)renderer
                                      path:(NSString * _Nonnull)path
                                      type:(AEAudioFileType)type
                                sampleRate:(double)sampleRate
                              channelCount:(int)channelCount
                                multitrack:(BOOL)multitrack
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

//! Whether to extend recording until silence reached, to capture effect tails (default NO)
@property (nonatomic) BOOL extendRecordingUntilSilence;

//! The sample rate
@property (nonatomic, readonly) double sampleRate;

//! The channel count
@property (nonatomic, readonly) int numberOfChannels;

//! The path of the output file
@property (nonatomic, strong, readonly) NSString * _Nonnull path;

//! The number of frames recorded so far
@property (nonatomic, readonly) UInt64 numberOfFramesRecorded;

@end

    
#ifdef __cplusplus
}
#endif
