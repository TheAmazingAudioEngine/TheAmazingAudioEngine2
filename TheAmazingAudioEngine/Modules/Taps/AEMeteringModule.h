//
//  AEMeteringModule.h
//  TheAmazingAudioEngine
//
//  Created on 4/06/2016.
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
 * Stereo Audio Metering Module
 *
 *  This module calculates the average and peak power for channels 0 and 1 (left/right).
 *  After processing, it leaves the buffer stack intact.
 */
@interface AEMeteringModule : AEModule

/*!
 * Default initializer
 *
 * @param renderer The renderer
 */
- (instancetype _Nullable)initWithRenderer:(AERenderer * _Nonnull)renderer;

@property (nonatomic, readonly) double avgPowerLeft;
@property (nonatomic, readonly) double avgPowerRight;
@property (nonatomic, readonly) double peakPowerLeft;
@property (nonatomic, readonly) double peakPowerRight;

@end

#ifdef __cplusplus
}
#endif
