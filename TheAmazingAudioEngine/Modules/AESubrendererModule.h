//
//  AESubrendererModule.h
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 23/04/2016.
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
 * Subrenderer module
 *
 *  This module allows you to run a separate renderer. This can be useful for encapsulating
 *  complex rendering behaviour.
 *
 *  The subrenderer's sample rate will track the owning renderer's sample rate, and
 */
@interface AESubrendererModule : AEModule

/*!
 * Initializer
 *
 * @param renderer Owning renderer
 * @param subrenderer Sub-renderer to use to provide input
 */
- (instancetype _Nullable)initWithRenderer:(AERenderer * _Nullable)renderer
                               subrenderer:(AERenderer * _Nullable)subrenderer;


//! The sub-renderer. You may change this value at any time; assignment is thread-safe.
@property (nonatomic, strong) AERenderer * _Nullable subrenderer;

//! The number of channels to use, or zero to track the owning renderer's channel count. Default is 2 (stereo)
@property (nonatomic) int numberOfOutputChannels;

@end

#ifdef __cplusplus
}
#endif