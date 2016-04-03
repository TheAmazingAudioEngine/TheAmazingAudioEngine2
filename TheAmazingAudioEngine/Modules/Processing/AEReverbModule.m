//
//  AEReverbModule.m
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

#import "AEReverbModule.h"

@implementation AEReverbModule

- (instancetype)initWithRenderer:(AERenderer *)renderer {
    return [super initWithRenderer:renderer componentDescription:(AudioComponentDescription) {
        kAudioUnitType_Effect, kAudioUnitSubType_Reverb2, kAudioUnitManufacturer_Apple
    }];
}

#pragma mark - Getters

- (double)dryWetMix {
    return [self getParameterValueForId:kReverb2Param_DryWetMix];
}

- (double)gain {
    return [self getParameterValueForId:kReverb2Param_Gain];
}

- (double)minDelayTime {
    return [self getParameterValueForId:kReverb2Param_MinDelayTime];
}

- (double)maxDelayTime {
    return [self getParameterValueForId:kReverb2Param_MaxDelayTime];
}

- (double)decayTimeAt0Hz {
    return [self getParameterValueForId:kReverb2Param_DecayTimeAt0Hz];
}

- (double)decayTimeAtNyquist {
    return [self getParameterValueForId:kReverb2Param_DecayTimeAtNyquist];
}

- (double)randomizeReflections {
    return [self getParameterValueForId:kReverb2Param_RandomizeReflections];
}

#pragma mark - Setters

- (void)setDryWetMix:(double)dryWetMix {
    [self setParameterValue: dryWetMix
                      forId: kReverb2Param_DryWetMix];
}

- (void)setGain:(double)gain {
    [self setParameterValue: gain
                      forId: kReverb2Param_Gain];
}

- (void)setMinDelayTime:(double)minDelayTime {
    [self setParameterValue: minDelayTime
                      forId: kReverb2Param_MinDelayTime];
}

- (void)setMaxDelayTime:(double)maxDelayTime {
    [self setParameterValue: maxDelayTime
                      forId: kReverb2Param_MaxDelayTime];
}

- (void)setDecayTimeAt0Hz:(double)decayTimeAt0Hz {
    [self setParameterValue: decayTimeAt0Hz
                      forId: kReverb2Param_DecayTimeAt0Hz];
}

- (void)setDecayTimeAtNyquist:(double)decayTimeAtNyquist {
    [self setParameterValue: decayTimeAtNyquist
                      forId: kReverb2Param_DecayTimeAtNyquist];
}

- (void)setRandomizeReflections:(double)randomizeReflections {
    [self setParameterValue: randomizeReflections
                      forId: kReverb2Param_RandomizeReflections];
}

@end
