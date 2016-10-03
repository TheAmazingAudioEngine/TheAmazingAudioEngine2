//
//  AEVarispeedModule.h
//  The Amazing Audio Engine
//
//  Created by Jeremy Flores on 4/26/13.
//  Copyright (c) 2015 Dream Engine Interactive, Inc and A Tasty Pixel Pty Ltd. All rights reserved.
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
#import "AEAudioUnitModule.h"

@interface AEVarispeedModule : AEAudioUnitModule

- (instancetype _Nullable)initWithRenderer:(AERenderer * _Nullable)renderer subrenderer:(AERenderer * _Nonnull)subrenderer;

//! documented range is from 0.25 to 4.0, but empircal testing shows it to be 0.25 to 2.0. Default is 1.0.
@property (nonatomic) double playbackRate;

//! range is from -2400 to 2400. Default is 0.0.
@property (nonatomic) double playbackCents;

@end

#ifdef __cplusplus
}
#endif
