//
//  AEParametricEqModule.m
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

#import "AEParametricEqModule.h"

@implementation AEParametricEqModule

- (instancetype)initWithRenderer:(AERenderer *)renderer {
    return [super initWithRenderer:renderer componentDescription:(AudioComponentDescription) {
        kAudioUnitType_Effect, kAudioUnitSubType_ParametricEQ, kAudioUnitManufacturer_Apple
    }];
}

#pragma mark - Getters

- (double)centerFrequency {
    return [self getParameterValueForId:kParametricEQParam_CenterFreq];
}

- (double)qFactor {
    return [self getParameterValueForId:kParametricEQParam_Q];
}

- (double)gain {
    return [self getParameterValueForId:kParametricEQParam_Gain];
}


#pragma mark - Setters

- (void)setCenterFrequency:(double)centerFrequency {
    [self setParameterValue: centerFrequency
                      forId: kParametricEQParam_CenterFreq];
}

- (void)setQFactor:(double)qFactor {
    [self setParameterValue: qFactor
                      forId: kParametricEQParam_Q];
}

- (void)setGain:(double)gain {
    [self setParameterValue: gain
                      forId: kParametricEQParam_Gain];
}

@end
