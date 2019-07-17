//
//  AEBlockModule.h
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 15/7/19.
//  Copyright © 2019 A Tasty Pixel. All rights reserved.
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
#import <AudioToolbox/AudioToolbox.h>
#import "AERenderer.h"
    
/*!
 * Process block
 *
 *  Block version of AEModuleProcessFunc (see this for details).
 *
 * @param context The rendering context
 */
typedef void (^AEModuleProcessBlock)(const AERenderContext * _Nonnull context);

/*!
 * Active test block
 *
 *  Block version of AEModuleIsActiveFunc (see this for details).
 */
typedef BOOL (^AEModuleIsActiveBlock)(void);

/*!
 * Block module
 *
 *  A module that uses blocks for processing, rather than function pointers, making it
 *  easier to use in certain cases.
 */
@interface AEBlockModule : AEModule

/*!
 * Initializer
 *
 * @param renderer The renderer.
 */
- (instancetype _Nullable)initWithRenderer:(AERenderer * _Nullable)renderer processBlock:(AEModuleProcessBlock _Nullable)processBlock NS_DESIGNATED_INITIALIZER;

- (instancetype _Nullable)initWithRenderer:(AERenderer * _Nullable)renderer NS_UNAVAILABLE;

//! Block for processing
@property (nonatomic, copy, nullable) AEModuleProcessBlock processBlock;

//! Block to determine whether module is currently active, or can be skipped during processing
@property (nonatomic, copy, nullable) AEModuleIsActiveBlock isActiveBlock;

//! Block to call when changing sample rate
@property (nonatomic, copy, nullable) void (^sampleRateChangedBlock)(double newSampleRate);

//! Block to call when changing renderer's channel count
@property (nonatomic, copy, nullable) void (^rendererChannelCountChangedBlock)(int newChannelCount);

@end


#ifdef __cplusplus
}
#endif
