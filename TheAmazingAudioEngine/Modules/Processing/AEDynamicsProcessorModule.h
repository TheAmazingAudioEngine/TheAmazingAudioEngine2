//
//  AEDynamicsProcessorModule.h
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

@interface AEDynamicsProcessorModule : AEAudioUnitModule

- (instancetype _Nullable)initWithRenderer:(AERenderer * _Nullable)renderer;

//! range is from -40dB to 20dB. Default is -20dB.
@property (nonatomic) double threshold;

//! range is from 0.1dB to 40dB. Default is 5dB.
@property (nonatomic) double headRoom;

//! range is from 1 to 50 (rate). Default is 2.
@property (nonatomic) double expansionRatio;

// Value is in dB.
@property (nonatomic) double expansionThreshold;

//! range is from 0.0001 to 0.2. Default is 0.001.
@property (nonatomic) double attackTime;

//! range is from 0.01 to 3. Default is 0.05.
@property (nonatomic) double releaseTime;

//! range is from -40dB to 40dB. Default is 0dB.
@property (nonatomic) double masterGain;

@property (nonatomic, readonly) double compressionAmount;
@property (nonatomic, readonly) double inputAmplitude;
@property (nonatomic, readonly) double outputAmplitude;

@end

#ifdef __cplusplus
}
#endif
