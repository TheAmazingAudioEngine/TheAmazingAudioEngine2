//
//  AEAggregatorModule.h
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 7/05/2016.
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

/*!
 * Aggregator module
 *
 *  This module provides a convenient way to aggregate multiple generator modules
 *  together, with facilities for applying volume and balance per-generator module.
 *
 *  You should use this with generator modules only - that is, modules that push
 *  a buffer onto the stack when they are processed.
 */
@interface AEAggregatorModule : AEModule

/*!
 * Initializer
 */
- (instancetype _Nullable)initWithRenderer:(AERenderer * _Nullable)renderer;

/*!
 * Add a module
 *
 * @param module A generator module
 */
- (void)addModule:(AEModule * _Nonnull)module;

/*!
 * Add a module, with mix parameters
 *
 * @param module A generator module
 * @param volume The module's initial volume (power ratio)
 * @param balance The module's initial balance (0 for center)
 */
- (void)addModule:(AEModule * _Nonnull)module volume:(float)volume balance:(float)balance;

/*!
 * Remove a module
 *
 * @param module The module to remove
 */
- (void)removeModule:(AEModule * _Nonnull)module;

/*!
 * Set mixing parameters for a module
 *
 * @param volume The module's volume (power ratio)
 * @param balance The module's balance (0 for center)
 * @param module A module
 */
- (void)setVolume:(float)volume balance:(float)balance forModule:(AEModule * _Nonnull)module;

/*!
 * Get mixing parameters for a module
 *
 * @param volume On output, the module's volume (power ratio)
 * @param balance On output, the module's balance (0 for center)
 * @param module A module
 */
- (void)getVolume:(float * _Nonnull)volume balance:(float * _Nonnull)balance forModule:(AEModule * _Nonnull)module;


//! The generator modules to aggregate
@property (nonatomic, strong) NSArray *  _Nonnull modules;

//! The number of channels to use (2 by default)
@property (nonatomic) int numberOfChannels;

@end

#ifdef __cplusplus
}
#endif
