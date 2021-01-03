//
//  AEMeteringModule.h
//  TheAmazingAudioEngine
//
//  Created by Leo Thiessen on 2016-04-14.
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

typedef struct {
    float average;
    float peak;
} AEMeteringChannelLevels;

typedef struct {
    int maxChannel;
    AEMeteringChannelLevels * _Nullable channels;
} AEMeteringLevels;

@interface AEMeteringModule : AEModule

/*! Initialize with 2 channels. */
- (instancetype _Nullable)initWithRenderer:(AERenderer * _Nullable)renderer;

/*! Initialize with 1-n number of channels. */
- (instancetype _Nullable)initWithRenderer:(AERenderer * _Nullable)renderer maxChannel:(int)maxChannel;

/*! Obtain average & peak levels, per channel, since the last access to this property. */
@property (nonatomic, readonly) AEMeteringLevels * _Nonnull levels;

@end
