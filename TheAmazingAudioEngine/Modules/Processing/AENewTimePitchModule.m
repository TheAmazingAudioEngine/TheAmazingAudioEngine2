//
//  AENewTimePitchModule.m
//  The Amazing Audio Engine
//
//  Created by Jeremy Flores on 4/27/13.
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

#import "AENewTimePitchModule.h"

@implementation AENewTimePitchModule

- (instancetype)initWithRenderer:(AERenderer *)renderer subrenderer:(AERenderer *)subrenderer {
    return [super initWithRenderer:renderer componentDescription:(AudioComponentDescription) {
        kAudioUnitType_FormatConverter, kAudioUnitSubType_NewTimePitch, kAudioUnitManufacturer_Apple
    } subrenderer:subrenderer];
}

#pragma mark - Getters

- (double)rate {
    return [self getParameterValueForId:kNewTimePitchParam_Rate];
}

- (double)pitch {
    return [self getParameterValueForId:kNewTimePitchParam_Pitch];
}

- (double)overlap {
    return [self getParameterValueForId:kNewTimePitchParam_Overlap];
}

- (BOOL)enablePeakLocking {
    return [self getParameterValueForId:kNewTimePitchParam_EnablePeakLocking];
}


#pragma mark - Setters

- (void)setRate:(double)rate {
    [self setParameterValue: rate
                      forId: kNewTimePitchParam_Rate];
}

- (void)setPitch:(double)pitch {
    [self setParameterValue: pitch
                      forId: kNewTimePitchParam_Pitch];
}

- (void)setOverlap:(double)overlap {
    [self setParameterValue: overlap
                      forId: kNewTimePitchParam_Overlap];
}

- (void)setEnablePeakLocking:(BOOL)enablePeakLocking {
    [self setParameterValue: enablePeakLocking
                      forId: kNewTimePitchParam_EnablePeakLocking];
}

@end
