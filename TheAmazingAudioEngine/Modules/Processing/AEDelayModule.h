//
//  AEDelayModule.h
//  The Amazing Audio Engine
//
//  Created by Jeremy Flores on 4/25/13.
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

@interface AEDelayModule : AEAudioUnitModule

- (instancetype _Nullable)initWithRenderer:(AERenderer * _Nullable)renderer;

//! range is from 0 to 100 (percentage). Default is 50.
@property (nonatomic) double wetDryMix;

//! range is from 0 to 2 seconds. Default is 1 second.
@property (nonatomic) double delayTime;

//! range is from -100 to 100. default is 50.
@property (nonatomic) double feedback;

//! range is from 10 to ($SAMPLERATE/2). Default is 15000.
@property (nonatomic) double lopassCutoff;

@end

#ifdef __cplusplus
}
#endif