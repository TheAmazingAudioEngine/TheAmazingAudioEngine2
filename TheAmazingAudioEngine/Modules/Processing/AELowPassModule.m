//
//  AELowPassModule.m
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

#import "AELowPassModule.h"

@implementation AELowPassModule

- (instancetype)initWithRenderer:(AERenderer *)renderer {
    return [super initWithRenderer:renderer componentDescription:(AudioComponentDescription) {
        kAudioUnitType_Effect, kAudioUnitSubType_LowPassFilter, kAudioUnitManufacturer_Apple
    }];
}

#pragma mark - Getters

- (double)cutoffFrequency {
    return [self getParameterValueForId:kLowPassParam_CutoffFrequency];
}

- (double)resonance {
    return [self getParameterValueForId:kLowPassParam_Resonance];
}


#pragma mark - Setters

- (void)setCutoffFrequency:(double)cutoffFrequency {
    [self setParameterValue: cutoffFrequency
                      forId: kLowPassParam_CutoffFrequency];
}

- (void)setResonance:(double)resonance {
    [self setParameterValue: resonance
                      forId: kLowPassParam_Resonance];
}

@end
