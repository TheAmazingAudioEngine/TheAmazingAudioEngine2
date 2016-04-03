//
//  AEPeakLimiterModule.m
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

#import "AEPeakLimiterModule.h"

@implementation AEPeakLimiterModule

- (instancetype)initWithRenderer:(AERenderer *)renderer {
    return [super initWithRenderer:renderer componentDescription:(AudioComponentDescription) {
        kAudioUnitType_Effect, kAudioUnitSubType_PeakLimiter, kAudioUnitManufacturer_Apple
    }];
}

#pragma mark - Getters

- (double)attackTime {
    return [self getParameterValueForId:kLimiterParam_AttackTime];
}

- (double)decayTime {
    return [self getParameterValueForId:kLimiterParam_DecayTime];
}

- (double)preGain {
    return [self getParameterValueForId:kLimiterParam_PreGain];
}


#pragma mark - Setters

- (void)setAttackTime:(double)attackTime {
    [self setParameterValue: attackTime
                      forId: kLimiterParam_AttackTime];
}

- (void)setDecayTime:(double)decayTime {
    [self setParameterValue: decayTime
                      forId: kLimiterParam_DecayTime];
}

- (void)setPreGain:(double)preGain {
    [self setParameterValue: preGain
                      forId: kLimiterParam_PreGain];
}

@end
