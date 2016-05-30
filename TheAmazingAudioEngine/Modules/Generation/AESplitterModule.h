//
//  AESplitterModule.h
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 30/05/2016.
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
 * Splitter module
 *
 *  This generator module wraps another generator, and allows you to safely run
 *  it multiple times in the same render cycle by buffering the first run, and
 *  returning the buffered audio for the first and subsequent runs. This is useful 
 *  for situations where you are drawing input from the same module at multiple
 *  points throughout your audio renderer.
 */
@interface AESplitterModule : AEModule

/*!
 * Initializer
 *
 * @param renderer The renderer
 * @param module A generator module with which to generate audio
 */
- (instancetype)initWithRenderer:(AERenderer *)renderer module:(AEModule *)module;

//! The module
@property (nonatomic, strong, readonly) AEModule * module;

//! The number of channels that will be generated (default 2).
//! You should not change this value while the module is in use.
@property (nonatomic) int numberOfChannels;

@end

#ifdef __cplusplus
}
#endif