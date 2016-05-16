//
//  AEAudioUnitInputModule.h
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 25/03/2016.
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

#import "AEModule.h"
#import "AETime.h"

/*!
 * Audio input module
 *
 *  This module receives audio input from the system audio hardware, and pushes
 *  a buffer onto the stack containing the received audio. The pushed buffer has
 *  the same channel count as the currently-attached audio hardware, accessible
 *  via the "numberOfInputChannels" property.
 *
 *  It's recommended that you do not create an instance of this class directly; instead,
 *  use the instance returned from AEAudioUnitOutput's 
 *  @link AEAudioUnitOutput::inputModule inputModule @endlink property, which uses the
 *  same underlying audio unit instance as the output.
 */
@interface AEAudioUnitInputModule : AEModule

/*!
 * Start the audio unit
 *
 *  You need to start the audio unit to be able to begin getting audio input.
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
 * @param module The module instance
 * @return The audio 
 */
AudioUnit _Nullable AEAudioUnitInputModuleGetAudioUnit(__unsafe_unretained AEAudioUnitInputModule * _Nonnull module);

/*!
 * Get the last received input timestamp
 *
 *  This gives access to the most recent AudioTimeStamp associated with input audio. Use this to perform synchronization.
 *
 * @param module The module instance
 * @return The most recent audio timestamp
 */
AudioTimeStamp AEAudioUnitInputModuleGetInputTimestamp(__unsafe_unretained AEAudioUnitInputModule * _Nonnull module);

#if TARGET_OS_IPHONE

/*!
 * Get the input latency
 *
 *  This function returns the hardware input latency, in seconds. If you have disabled latency compensation,
 *  and timing is important in your app, then you should factor this value into your timing calculations.
 *
 * @param module The module instance
 * @return The current input latency
 */
AESeconds AEAudioUnitInputModuleGetInputLatency(__unsafe_unretained AEAudioUnitInputModule * _Nonnull module);

#endif

@property (nonatomic, readonly) AudioUnit _Nonnull audioUnit; //!< The audio unit
@property (nonatomic, readonly) BOOL running; //!< Whether unit is currently active
@property (nonatomic, readonly) int numberOfInputChannels; //!< The current number of input channels (key-value observable)

#if TARGET_OS_IPHONE
@property (nonatomic) BOOL latencyCompensation; //!< Whether to automatically perform latency compensation (default YES)
#endif

@end

    
#ifdef __cplusplus
}
#endif
