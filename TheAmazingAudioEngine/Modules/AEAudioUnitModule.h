//
//  AEAudioUnitModule.h
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
@import AudioToolbox;

/*!
 * Audio unit module
 *
 *  This module provides an interface to Audio Units, both generator and effect types.
 *
 *  For generator Audio Units, this module will push one buffer onto the stack during
 *  processing. For effect units, it will pop and and push one (i.e. process in place).
 */
@interface AEAudioUnitModule : AEModule

/*!
 * Default initializer
 *
 *  Use this initializer for all audio unit types beside format converters (such as the varispeed
 *  and time/pitch units).
 *
 * @param renderer The renderer
 * @param audioComponentDescription The structure identifying the audio unit to instantiate
 */
- (instancetype _Nullable)initWithRenderer:(AERenderer * _Nullable)renderer
                      componentDescription:(AudioComponentDescription)audioComponentDescription;


/*!
 * Sub-renderer initializer
 *
 *  Use this initializer for format converter audio units, such as the varispeed and time/pitch
 *  units. As these audio units draw input at a different rate to output production, you must provide
 *  a sub-renderer which will be used to produce input frames as needed.
 *
 * @param renderer Owning renderer
 * @param audioComponentDescription The structure identifying the audio unit to instantiate
 * @param subrenderer Sub-renderer to use to provide input, or nil for default initializer behaviour
 */
- (instancetype _Nullable)initWithRenderer:(AERenderer * _Nullable)renderer
                      componentDescription:(AudioComponentDescription)audioComponentDescription
                               subrenderer:(AERenderer * _Nullable)subrenderer;

/*!
 * Get an audio unit parameter
 *
 * @param parameterId The audio unit parameter identifier
 * @return The value of the parameter
 */
- (double)getParameterValueForId:(AudioUnitParameterID)parameterId;

/*!
 * Set an audio unit parameter
 *
 *  Note: Parameters set via this method will be automatically assigned again if the
 *  audio unit is recreated due to removal from the audio controller, an audio controller
 *  reload, or a media server error.
 *
 * @param value The value of the parameter to set
 * @param parameterId The audio unit parameter identifier
 */
- (void)setParameterValue:(double)value forId:(AudioUnitParameterID)parameterId;

/*!
 * Setup audio unit
 *
 *  This method is for use by subclasses only
 */
- (BOOL)setup;

/*!
 * Initialize audio unit
 *
 *  This method is for use by subclasses only
 */
- (void)initialize;

/*!
 * Cleanup audio unit
 *
 *  This method is for use by subclasses only
 */
- (void)teardown;

/*!
 * Get access to audio unit
 *
 *  Available for realtime thread usage
 *
 * @param module The module
 * @return The audio unit
 */
AudioUnit _Nonnull AEAudioUnitModuleGetAudioUnit(__unsafe_unretained AEAudioUnitModule * _Nonnull module);

//! The component description
@property (nonatomic, readonly) AudioComponentDescription componentDescription;

//! The audio unit
@property (nonatomic, readonly) AudioUnit _Nonnull audioUnit;

//! Whether the audio unit processes input (and thus will process buffers in place, rather than pushing new buffers)
@property (nonatomic, readonly) BOOL hasInput;

//! Wet/dry amount, for use with effect audio unit types. 0.0-1.0; 0.0 bypasses the effect entirely.
@property (nonatomic) double wetDry;

//! Sub-renderer, for use with format converter audio unit types, such as the varispeed and time/pitch units.
//  You may change this value at any time; assignment is thread-safe.
@property (nonatomic, strong) AERenderer * _Nullable subrenderer;

@end

#ifdef __cplusplus
}
#endif
