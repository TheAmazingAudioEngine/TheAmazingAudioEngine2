//
//  AEIOAudioUnit.h
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 4/04/2016.
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

/*!
 * Render block
 *
 *  For output-enabled AEIOAudioUnit instances, you must provide a block of this type
 *  to the @link AEIOAudioUnit::renderBlock renderBlock @endlink property.
 *
 * @param ioData The audio buffer list to fill
 * @param frames The number of frames
 * @param timestamp The corresponding timestamp
 */
typedef void (^AEIOAudioUnitRenderBlock)(AudioBufferList * _Nonnull ioData,
                                         UInt32 frames,
                                         const AudioTimeStamp * _Nonnull timestamp);

/*!
 * Stream update notification
 *
 *  This is broadcast when the stream format updates (sample rate/channel count).
 *  If sample rate has changed for an output-enabled unit, this block will be performed between
 *  stopping the unit and starting it again.
 */
extern NSString * const _Nonnull AEIOAudioUnitDidUpdateStreamFormatNotification;

/*!
 * Audio unit interface
 *
 *  This class manages an input/output/input-output audio unit. To use it, create an instance,
 *  set the properties, then call setup: to initialize, and start: to begin processing.
 *
 *  Typically, you do not use this class directly; instead, use AEAudioUnitOutput and/or
 *  AEAudioUnitInputModule to provide an interface with the audio hardware.
 *
 *  Important note: an audio unit with both input and output enabled is only possible on iOS. On
 *  the Mac, you must create two separate audio units.
 */
@interface AEIOAudioUnit : NSObject

/*!
 * Setup the audio unit
 *
 *  Call this after configuring the instance to initialize it, prior to calling start:.
 *
 * @param error If an error occured and this is not nil, it will be set to the error on output
 * @return YES on success, NO on failure
 */
- (BOOL)setup:(NSError * __autoreleasing _Nullable * _Nullable)error;

/*!
 * Start the audio unit
 *
 * @param error If an error occured and this is not nil, it will be set to the error on output
 * @return YES on success, NO on failure
 */
- (BOOL)start:(NSError * __autoreleasing _Nullable * _Nullable)error;

/*!
 * Stop the audio unit
 */
- (void)stop;

/*!
 * Get access to audio unit
 *
 *  Available for realtime thread usage
 *
 * @param unit The unit instance
 * @return The audio unit
 */
AudioUnit _Nullable AEIOAudioUnitGetAudioUnit(__unsafe_unretained AEIOAudioUnit * _Nonnull unit);

/*!
 * Render the input
 *
 *  For use with input-enabled instance, this fills the provided AudioBufferList with audio
 *  from the input.
 *
 * @param unit The unit instance
 * @param buffer The audio buffer list
 * @param frames Number of frames
 */
OSStatus AEIOAudioUnitRenderInput(__unsafe_unretained AEIOAudioUnit * _Nonnull unit,
                                  const AudioBufferList * _Nonnull buffer, UInt32 frames);

/*!
 * Get the last received input timestamp
 *
 *  For use with input-enabled instances, this gives access to the most recent AudioTimeStamp
 *  associated with input audio. Use this to perform synchronization.
 *
 * @param unit The unit instance
 * @return The most recent audio timestamp
 */
AudioTimeStamp AEIOAudioUnitGetInputTimestamp(__unsafe_unretained AEIOAudioUnit * _Nonnull unit);

/*!
 * Get the current sample rate
 *
 *  The sample rate is normally obtained from the current render context, but this function allows
 *  access when the render context is not available
 *
 * @param unit The unit instance
 * @return The current sample rate
 */
double AEIOAudioUnitGetSampleRate(__unsafe_unretained AEIOAudioUnit * _Nonnull unit);

#if TARGET_OS_IPHONE

/*!
 * Get the input latency
 *
 *  This function returns the hardware input latency, in seconds. If you have disabled latency compensation,
 *  and timing is important in your app, then you should factor this value into your timing calculations.
 *
 * @param unit The unit instance
 * @return The current input latency
 */
AESeconds AEIOAudioUnitGetInputLatency(__unsafe_unretained AEIOAudioUnit * _Nonnull unit);

/*!
 * Get the output latency
 *
 *  This function returns the hardware output latency, in seconds. If you have disabled latency compensation,
 *  and timing is important in your app, then you should factor this value into your timing calculations.
 *
 * @param unit The unit instance
 * @return The current output latency
 */
AESeconds AEIOAudioUnitGetOutputLatency(__unsafe_unretained AEIOAudioUnit * _Nonnull unit);

#endif

//! The audio unit
@property (nonatomic, readonly) AudioUnit _Nullable audioUnit;

//! The sample rate at which to run, or zero to track the hardware sample rate
@property (nonatomic) double sampleRate;

//! The current sample rate in use
@property (nonatomic, readonly) double currentSampleRate;

//! Whether unit is currently active
@property (nonatomic, readonly) BOOL running;

//! Whether output is enabled
@property (nonatomic) BOOL outputEnabled;

//! The block to call when rendering output
@property (nonatomic, copy) AEIOAudioUnitRenderBlock _Nullable renderBlock;

//! The current number of output channels
@property (nonatomic, readonly) int numberOfOutputChannels;


//! Whether input is enabled
@property (nonatomic) BOOL inputEnabled;

//! The maximum number of input channels to support, or zero for unlimited
@property (nonatomic) int maximumInputChannels;

//! The current number of input channels in use
@property (nonatomic, readonly) int numberOfInputChannels;

#if TARGET_OS_IPHONE

//! Whether to automatically perform latency compensation (default YES)
@property (nonatomic) BOOL latencyCompensation;

#endif
@end

#ifdef __cplusplus
}
#endif
