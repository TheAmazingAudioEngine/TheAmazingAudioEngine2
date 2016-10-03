//
//  AEDSPUtilitiesTests.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 15/05/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "AEDSPUtilities.h"

static const UInt32 kFrames = 256;
static const float kOscillatorRate = 440.0/44100.0;
static const float kErrorTolerance = 1.0e-6;

typedef struct {
    float channels[2];
} StereoPair;

static StereoPair StereoPairMake(float l, float r) { return (StereoPair) {{l,r}}; };
static StereoPair StereoPairMakeMono(float sample) { return (StereoPair) {{sample,sample}}; };


@interface AEDSPUtilitiesTests : XCTestCase
@end

@implementation AEDSPUtilitiesTests

- (void)testGain {
    AudioBufferList * abl = [self bufferWithChannels:2];
    AEDSPApplyGain(abl, 0.5, kFrames);
    
    __block float position = 0;
    NSString * message = nil;
    BOOL matches = [self compareBuffer:abl against:^StereoPair(int index) {
        return StereoPairMakeMono(AEDSPGenerateOscillator(kOscillatorRate, &position) * 0.5f);
    } message:&message];
    
    XCTAssertTrue(matches, @"%@", message);
    
    AEAudioBufferListFree(abl);
}

- (void)testRamp {
    AudioBufferList * abl = [self bufferWithChannels:2];
    float start = 1.0;
    AEDSPApplyRamp(abl, &start, -1.0/kFrames, kFrames);
    
    __block float position = 0;
    NSString * message = nil;
    BOOL matches = [self compareBuffer:abl against:^StereoPair(int index) {
        float gain = (1.0f-((float)index/kFrames));
        return StereoPairMakeMono(AEDSPGenerateOscillator(kOscillatorRate, &position) * gain);
    } message:&message];
    
    XCTAssertTrue(matches, @"%@", message);
    
    AEAudioBufferListFree(abl);
}

- (void)testEqualPowerRamp {
    AudioBufferList * abl = [self bufferWithChannels:2];
    float start = 1.0;
    AEDSPApplyEqualPowerRamp(abl, &start, -1.0/kFrames, kFrames, NULL);
    
    __block float position = 0;
    NSString * message = nil;
    BOOL matches = [self compareBuffer:abl against:^StereoPair(int index) {
        float gain = (1.0f-((float)index/kFrames));
        return StereoPairMakeMono(AEDSPGenerateOscillator(kOscillatorRate, &position) * sin(gain * M_PI_2));
    } message:&message];
    
    XCTAssertTrue(matches, @"%@", message);
    
    AEAudioBufferListFree(abl);
}

- (void)testGainSmoothed {
    AudioBufferList * abl = [self bufferWithChannels:2];
    float currentGain = 1.0;
    AEDSPApplyGainSmoothed(abl, 0.0, &currentGain, kFrames);
    
    XCTAssertEqual(currentGain, 0.0);
    
    __block float position = 0;
    NSString * message = nil;
    BOOL matches = [self compareBuffer:abl against:^StereoPair(int index) {
        float gain = index < 128 ? (1.0f-((float)index/128)) : 0.0f;
        return StereoPairMakeMono(AEDSPGenerateOscillator(kOscillatorRate, &position) * gain);
    } message:&message];
    
    XCTAssertTrue(matches, @"%@", message);
    
    AEAudioBufferListFree(abl);
}

- (void)testGainSmoothedMono {
    AudioBufferList * abl = [self bufferWithChannels:1];
    float currentGain = 1.0;
    AEDSPApplyGainSmoothedMono(abl->mBuffers[0].mData, 0.0, &currentGain, kFrames);
    
    XCTAssertEqual(currentGain, 0.0);
    
    __block float position = 0;
    NSString * message = nil;
    BOOL matches = [self compareBuffer:abl against:^StereoPair(int index) {
        float gain = index < 128 ? (1.0f-((float)index/128)) : 0.0f;
        return StereoPairMakeMono(AEDSPGenerateOscillator(kOscillatorRate, &position) * gain);
    } message:&message];
    
    XCTAssertTrue(matches, @"%@", message);
    
    AEAudioBufferListFree(abl);
}

- (void)testVolumeAndBalance {
    AudioBufferList * abl = [self bufferWithChannels:2];
    float currentVolume = 1.0;
    float currentBalance = 0.0;
    AEDSPApplyVolumeAndBalance(abl, 0.5, &currentVolume, -1.0, &currentBalance, kFrames);
    
    XCTAssertEqual(currentVolume, 0.5f);
    XCTAssertEqual(currentBalance, -1.0f);
    
    __block float position = 0;
    NSString * message = nil;
    BOOL matches = [self compareBuffer:abl against:^StereoPair(int index) {
        float sample = AEDSPGenerateOscillator(kOscillatorRate, &position);
        return StereoPairMake(sample * (index < 64 ? (0.5f*(1.0f-((float)index/64)))+0.5f : 0.5f),
                              sample * (index < 128 ? (1.0f-((float)index/128)) : 0.0f));
    } message:&message];
    
    XCTAssertTrue(matches, @"%@", message);
    
    AEAudioBufferListFree(abl);
}

- (void)testMixStereo {
    AudioBufferList * abl1 = [self bufferWithChannels:2];
    AudioBufferList * abl2 = [self bufferWithChannels:2];
    AEDSPMix(abl1, abl2, 0.5, 1.0, NO, kFrames, abl2);
    
    __block float position = 0;
    NSString * message = nil;
    BOOL matches = [self compareBuffer:abl2 against:^StereoPair(int index) {
        float sample = AEDSPGenerateOscillator(kOscillatorRate, &position);
        return StereoPairMakeMono(sample * 1.5);
    } message:&message];
    
    XCTAssertTrue(matches, @"%@", message);
    
    AEAudioBufferListFree(abl1);
    AEAudioBufferListFree(abl2);
    
    
    
    abl1 = [self bufferWithChannels:2];
    abl2 = [self bufferWithChannels:2];
    AEDSPMix(abl1, abl2, 1, 0.5, NO, kFrames, abl2);
    
    position = 0;
    matches = [self compareBuffer:abl2 against:^StereoPair(int index) {
        float sample = AEDSPGenerateOscillator(kOscillatorRate, &position);
        return StereoPairMakeMono(sample * 1.5);
    } message:&message];
    
    XCTAssertTrue(matches, @"%@", message);
    
    AEAudioBufferListFree(abl1);
    AEAudioBufferListFree(abl2);
}

- (void)testMixMonoToStereo {
    AudioBufferList * abl1 = [self bufferWithChannels:1];
    AudioBufferList * abl2 = [self bufferWithChannels:2];
    AEDSPMix(abl1, abl2, 0.5, 1.0, YES, kFrames, abl2);
    
    __block float position = 0;
    NSString * message = nil;
    BOOL matches = [self compareBuffer:abl2 against:^StereoPair(int index) {
        float sample = AEDSPGenerateOscillator(kOscillatorRate, &position);
        return StereoPairMakeMono(sample * 1.5);
    } message:&message];
    
    XCTAssertTrue(matches, @"%@", message);
    
    AEAudioBufferListFree(abl1);
    AEAudioBufferListFree(abl2);
}

- (void)testMixStereoToMono {
    AudioBufferList * abl1 = [self bufferWithChannels:2];
    AudioBufferList * abl2 = [self bufferWithChannels:1];
    AEDSPMix(abl1, abl2, 0.5, 1.0, YES, kFrames, abl2);
    
    __block float position = 0;
    NSString * message = nil;
    BOOL matches = [self compareBuffer:abl2 against:^StereoPair(int index) {
        float sample = AEDSPGenerateOscillator(kOscillatorRate, &position);
        return StereoPairMakeMono(sample * 2.0);
    } message:&message];
    
    XCTAssertTrue(matches, @"%@", message);
    
    AEAudioBufferListFree(abl1);
    AEAudioBufferListFree(abl2);
}

- (void)testMixMono {
    AudioBufferList * abl1 = [self bufferWithChannels:1];
    AudioBufferList * abl2 = [self bufferWithChannels:1];
    AEDSPMixMono(abl1->mBuffers[0].mData, abl2->mBuffers[0].mData, 0.5, 1, kFrames, abl2->mBuffers[0].mData);
    
    __block float position = 0;
    NSString * message = nil;
    BOOL matches = [self compareBuffer:abl2 against:^StereoPair(int index) {
        float sample = AEDSPGenerateOscillator(kOscillatorRate, &position);
        return StereoPairMakeMono(sample * 1.5);
    } message:&message];
    
    XCTAssertTrue(matches, @"%@", message);
    
    AEAudioBufferListFree(abl1);
    AEAudioBufferListFree(abl2);
    
    
    
    abl1 = [self bufferWithChannels:1];
    abl2 = [self bufferWithChannels:1];
    AEDSPMixMono(abl1->mBuffers[0].mData, abl2->mBuffers[0].mData, 1, 0.5, kFrames, abl2->mBuffers[0].mData);
    
    position = 0;
    matches = [self compareBuffer:abl2 against:^StereoPair(int index) {
        float sample = AEDSPGenerateOscillator(kOscillatorRate, &position);
        return StereoPairMakeMono(sample * 1.5);
    } message:&message];
    
    XCTAssertTrue(matches, @"%@", message);
    
    AEAudioBufferListFree(abl1);
    AEAudioBufferListFree(abl2);
}

#pragma mark - Helpers

- (AudioBufferList *)bufferWithChannels:(int)channels {
    AudioBufferList * abl =
        AEAudioBufferListCreateWithFormat(AEAudioDescriptionWithChannelsAndRate(channels, 44100.0), kFrames);
    float position = 0;
    for ( int i=0; i<kFrames; i++ ) {
        float sample = AEDSPGenerateOscillator(kOscillatorRate, &position);
        for ( int j=0; j<abl->mNumberBuffers; j++ ) {
            ((float*)abl->mBuffers[j].mData)[i] = sample;
        }
    }
    return abl;
}

- (BOOL)compareBuffer:(AudioBufferList *)abl against:(StereoPair(^)(int index))sampleBlock message:(NSString **)message {
    for ( int i=0; i<kFrames; i++ ) {
        StereoPair expected = sampleBlock(i);
        for ( int j=0; j<abl->mNumberBuffers; j++ ) {
            float sample = ((float*)abl->mBuffers[j].mData)[i];
            if ( fabsf(sample - expected.channels[j]) > kErrorTolerance ) {
                *message = [NSString stringWithFormat:@"sample %d channel %d, %f != %f", i, j, sample, expected.channels[j]];
                return NO;
            }
        }
    }
    return YES;
}

@end
