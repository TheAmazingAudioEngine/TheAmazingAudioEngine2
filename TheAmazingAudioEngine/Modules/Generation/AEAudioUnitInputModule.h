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

#import "AEModule.h"

#ifdef __cplusplus
extern "C" {
#endif

extern NSString * const _Nonnull AEAudioUnitInputModuleError;

/*!
 * Audio input module
 *
 *  This module receives audio input from the system audio hardware, and pushes
 *  a buffer onto the stack containing the received audio. The pushed buffer has
 *  the same channel count as the currently-attached audio hardware, accessible
 *  via the "inputChannels" property.
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

@property (nonatomic, readonly) AudioUnit _Nonnull audioUnit; //!< The audio unit
@property (nonatomic, readonly) BOOL running; //!< Whether unit is currently active
@property (nonatomic, readonly) int inputChannels; //!< The current number of input channels (key-value observable)
@property (nonatomic) BOOL latencyCompensation; //!< Whether to automatically perform latency compensation (default YES)
@end

    
#ifdef __cplusplus
}
#endif
