//
//  AENewTimePitchModuleTests.m
//  TheAmazingAudioEngine
//
//  Created by Mark Anderson on 9/24/16.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "AENewTimePitchModule.h"
#import "AEManagedValue.h"
#import "AEAudioBufferListUtilities.h"

@interface AENewTimePitchModuleTests : XCTestCase

@end

@implementation AENewTimePitchModuleTests

- (void)testDefaultParameterValues {
    AERenderer * renderer = [AERenderer new];
    AERenderer * subrenderer = [AERenderer new];
    
    AENewTimePitchModule * timePitchModule = [[AENewTimePitchModule alloc] initWithRenderer:renderer subrenderer:subrenderer];

    XCTAssertEqual(timePitchModule.pitch, 0.0);
    XCTAssertEqual(timePitchModule.rate, 1.0);
    XCTAssertEqual(timePitchModule.overlap, 8.0);
    XCTAssertEqual(timePitchModule.enablePeakLocking, YES);
}

- (void)testParameterValueManipulation {
    AERenderer * renderer = [AERenderer new];
    AERenderer * subrenderer = [AERenderer new];

    AENewTimePitchModule * timePitchModule = [[AENewTimePitchModule alloc] initWithRenderer:renderer subrenderer:subrenderer];

    AEManagedValue * timePitchValue = [AEManagedValue new];
    timePitchValue.objectValue = timePitchModule;

    double pitchChange = -2400.0;
    double rateChange = 1.0/32.0;
    double overlapChange = 32.0;
    double enablePeakLockingChange = NO;

    renderer.block = ^(const AERenderContext * context) {
        __unsafe_unretained AENewTimePitchModule * timePitch
        = (__bridge AENewTimePitchModule *)AEManagedValueGetValue(timePitchValue);

        timePitch.pitch = pitchChange;
        timePitch.rate = rateChange;
        timePitch.overlap = overlapChange;
        timePitch.enablePeakLocking = enablePeakLockingChange;
    };

    UInt32 frames = 1;
    AudioBufferList * abl = AEAudioBufferListCreate(frames);
    AudioTimeStamp timestamp = { .mFlags = kAudioTimeStampSampleTimeValid, .mSampleTime = 0 };

    AERendererRun(renderer, abl, frames, &timestamp);

    XCTAssertEqual(timePitchModule.pitch, pitchChange);
    XCTAssertEqual(timePitchModule.rate, rateChange);
    XCTAssertEqual(timePitchModule.overlap, overlapChange);
    XCTAssertEqual(timePitchModule.enablePeakLocking, enablePeakLockingChange);
}

@end
