//
//  AEDSPUtilitiesTests.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 15/05/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "AEDSPUtilities.h"
#import <Accelerate/Accelerate.h>

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

#define alen(a) (sizeof(a)/sizeof(a[0]))

- (void)testFFTConvolutionSmall {
    float a[] = {1, 5, 3, 2, 4, 6, 7, 5, 4, 4, 6, 4, 3, 6, 4, 2};
    float b[] = {4, 6, 7, 5, 1};
    float expected[] = {75, 82, 105, 126, 129, 116, 108, 105, 102, 104, 99, 93, 73, 40, 14, 2};
    float output[alen(expected)];

    AEDSPFFTConvolution * conv = AEDSPFFTConvolutionInit(alen(a)+alen(b));
    AEDSPFFTConvolutionExecute(conv, a, alen(a), b, alen(b), output, alen(output), AEDSPFFTConvolutionOperation_Convolution);

    for ( int i=0; i<alen(expected); i++ ) {
        XCTAssertEqualWithAccuracy(output[i], expected[i], 1.0e-4);
    }
    
    AEDSPFFTConvolutionDealloc(conv);
}

- (void)testFFTConvolutionSmallFull {
    float a[] = {1, 5, 3, 2, 4, 6, 7, 5, 4, 4, 6, 4, 3, 6, 4, 2};
    float b[] = {4, 6, 7, 5, 1};
    float expected[] = {4, 26, 49, 66, 75, 82, 105, 126, 129, 116, 108, 105, 102, 104, 99, 93, 73, 40, 14, 2};
    float output[alen(expected)];

    AEDSPFFTConvolution * conv = AEDSPFFTConvolutionInit(alen(a)+alen(b));
    AEDSPFFTConvolutionExecute(conv, a, alen(a), b, alen(b), output, alen(output), AEDSPFFTConvolutionOperation_ConvolutionFull);

    for ( int i=0; i<alen(expected); i++ ) {
        XCTAssertEqualWithAccuracy(output[i], expected[i], 1.0e-4);
    }
    
    AEDSPFFTConvolutionDealloc(conv);
}

- (void)testFFTConvolutionLarge {
    float a[3*64];
    for ( int i=0; i<alen(a); i++ ) a[i] = i%5;
    float b[] = { 1, 2, 3, 2, 1, 2, 3, 2 };
    float expected[] = {22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31};
    float output[alen(expected)];
    
    AEDSPFFTConvolution * conv = AEDSPFFTConvolutionInit(64);
    AEDSPFFTConvolutionExecute(conv, a, alen(a), b, alen(b), output, alen(output), AEDSPFFTConvolutionOperation_Convolution);
    
    for ( int i=0; i<alen(expected); i++ ) {
        XCTAssertEqualWithAccuracy(output[i], expected[i], 1.0e-4);
    }
    
    float c[54];
    for ( int i=0; i<alen(c); i++ ) c[i] = i%7;
    float expected2[] = {297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 295, 312, 310, 288, 280, 250, 271, 280, 276, 258, 225, 236, 235, 235, 228, 213, 214, 210, 200, 183, 172, 184, 198, 178, 158, 137, 139, 157, 148, 146, 115, 114, 122, 103, 105, 85, 102, 100, 78, 70, 40, 61, 70, 66, 48, 15, 26, 25, 25, 18, 3, 4};
    
    float output2[alen(expected2)];
    AEDSPFFTConvolutionExecute(conv, a, alen(a), c, alen(c), output2, alen(output2), AEDSPFFTConvolutionOperation_Convolution);
    
    for ( int i=0; i<alen(expected2); i++ ) {
        XCTAssertEqualWithAccuracy(output2[i], expected2[i], 1.0e-4);
    }
    
    AEDSPFFTConvolutionDealloc(conv);
}

- (void)testFFTConvolutionLargeFull {
    float a[3*64];
    for ( int i=0; i<alen(a); i++ ) a[i] = i%5;
    float b[] = { 1, 2, 3, 2, 1, 2, 3, 2 };
    float expected[] = {0, 1, 4, 10, 18, 22, 23, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 22, 28, 39, 40, 31, 20, 21, 23, 19, 10, 3, 2};
    float output[alen(expected)];
    
    AEDSPFFTConvolution * conv = AEDSPFFTConvolutionInit(64);
    AEDSPFFTConvolutionExecute(conv, a, alen(a), b, alen(b), output, alen(output), AEDSPFFTConvolutionOperation_ConvolutionFull);
    
    for ( int i=0; i<alen(expected); i++ ) {
         XCTAssertEqualWithAccuracy(output[i], expected[i], 1.0e-5);
    }
    
    float c[54];
    for ( int i=0; i<alen(c); i++ ) c[i] = i%7;
    float expected2[] = {0, 0, 1, 4, 10, 20, 30, 41, 47, 49, 48, 40, 61, 77, 89, 91, 79, 89, 87, 109, 121, 119, 132, 126, 137, 131, 139, 162, 166, 180, 170, 167, 172, 186, 210, 210, 210, 211, 214, 220, 230, 240, 251, 257, 259, 258, 250, 271, 287, 299, 301, 289, 299, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 295, 312, 310, 288, 280, 250, 271, 280, 276, 258, 225, 236, 235, 235, 228, 213, 214, 210, 200, 183, 172, 184, 198, 178, 158, 137, 139, 157, 148, 146, 115, 114, 122, 103, 105, 85, 102, 100, 78, 70, 40, 61, 70, 66, 48, 15, 26, 25, 25, 18, 3, 4};
    
    float output2[alen(expected2)];
    AEDSPFFTConvolutionExecute(conv, a, alen(a), c, alen(c), output2, alen(output2), AEDSPFFTConvolutionOperation_ConvolutionFull);
    
    for ( int i=0; i<alen(expected2); i++ ) {
        XCTAssertEqualWithAccuracy(output2[i], expected2[i], 1.0e-4);
    }
    
    AEDSPFFTConvolutionDealloc(conv);
}

- (void)testFFTConvolutionContinuous {
    float a[3*64];
    for ( int i=0; i<alen(a); i++ ) a[i] = i%5;
    float b[54];
    for ( int i=0; i<alen(b); i++ ) b[i] = i%7;
    float expected[] = {0, 0, 1, 4, 10, 20, 30, 41, 47, 49, 48, 40, 61, 77, 89, 91, 79, 89, 87, 109, 121, 119, 132, 126, 137, 131, 139, 162, 166, 180, 170, 167, 172, 186, 210, 210, 210, 211, 214, 220, 230, 240, 251, 257, 259, 258, 250, 271, 287, 299, 301, 289, 299, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 297, 319, 326, 313, 315, 295, 312, 310, 288, 280, 250, 271, 280, 276, 258, 225, 236, 235, 235, 228, 213, 214, 210, 200, 183, 172, 184, 198, 178, 158, 137, 139, 157, 148, 146, 115, 114, 122, 103, 105, 85, 102, 100, 78, 70, 40, 61, 70, 66, 48, 15, 26, 25, 25, 18, 3, 4};
    float output[alen(a)];
    
    AEDSPFFTConvolution * conv = AEDSPFFTConvolutionInit(64);
    AEDSPFFTConvolutionPrepareContinuous(conv, b, alen(b), AEDSPFFTConvolutionOperation_ConvolutionFull);
    
    for ( int i=0; i<alen(output); ) {
        int block = MIN(19, (int)alen(output)-i);
        AEDSPFFTConvolutionExecuteContinuous(conv, a+i, block, output+i, block);
        for ( int j=i; j<i+block; j++ ) {
            XCTAssertEqualWithAccuracy(output[i], expected[i], 1.0e-4);
        }
        i += block;
    }
    
    for ( int i=0; i<alen(output); i++ ) {
        XCTAssertEqualWithAccuracy(output[i], expected[i], 1.0e-4);
    }
    
    AEDSPFFTConvolutionDealloc(conv);
}

- (void)testFFTCorrelationSmall {
    float a[] = {1, 5, 3, 2, 4, 6, 7, 5, 4, 4, 6, 4, 3, 6, 4, 2};
    float b[] = {4, 6, 7, 5, 1};
    
    float expected[] = { 69, 78, 89, 114, 130, 125, 112, 106, 105, 101, 103, 98 };
    
    AEDSPFFTConvolution * conv = AEDSPFFTConvolutionInit(alen(a)+alen(b));
    
    float output[alen(expected)];
    AEDSPFFTConvolutionExecute(conv, a, alen(a), b, alen(b), output, alen(output), AEDSPFFTConvolutionOperation_Correlation);
    
    float output2[alen(a)-alen(b)+1];
    vDSP_conv(a, 1, b, 1, output2, 1, alen(output2), alen(b));
    
    for ( int i=0; i<alen(expected); i++ ) {
        XCTAssertEqualWithAccuracy(output[i], expected[i], 1.0e-4);
    }
    
    AEDSPFFTConvolutionDealloc(conv);
}

- (void)testFFTCorrelationLarge {
    AEDSPFFTConvolution * conv = AEDSPFFTConvolutionInit(64);
    float a[3*64];
    for ( int i=0; i<alen(a); i++ ) a[i] = i%5;
    float b[] = {1, 2, 6, 3, 1, 4, 1};
    float expected[] = { 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 39, 33, 14, 10, 2, 1 };
    float output[alen(expected)];
    
    AEDSPFFTConvolutionExecute(conv, a, alen(a), b, alen(b), output, alen(output), AEDSPFFTConvolutionOperation_Correlation);
    
    for ( int i=0; i<alen(expected); i++ ) {
        XCTAssertEqualWithAccuracy(output[i], expected[i], 1.0e-5);
    }

    AEDSPFFTConvolutionDealloc(conv);
}

- (void)testFFTCorrelationLargeFull {
    AEDSPFFTConvolution * conv = AEDSPFFTConvolutionInit(64);
    float a[3*64];
    for ( int i=0; i<alen(a); i++ ) a[i] = i%5;
    float b[] = {1, 2, 6, 3, 1, 4, 1};
    float expected[] = { 0, 1, 6, 12, 21, 31, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 41, 44, 32, 35, 28, 39, 33, 14, 10, 2, 1 };
    float output[alen(expected)];
    
    AEDSPFFTConvolutionExecute(conv, a, alen(a), b, alen(b), output, alen(output), AEDSPFFTConvolutionOperation_CorrelationFull);
    
    for ( int i=0; i<alen(expected); i++ ) {
        XCTAssertEqualWithAccuracy(output[i], expected[i], 1.0e-5);
    }

    AEDSPFFTConvolutionDealloc(conv);
}

- (void)testFFTConvolutionContinuousVsMonolithic {
    float a[6523];
    for ( int i=0; i<alen(a); i++ ) {
        a[i] = random()/(float)RAND_MAX;
    }
    float b[50];
    for ( int i=0; i<alen(b); i++ ) {
        b[i] = random()/(float)RAND_MAX;
    }
    
    float o1[alen(a)];
    float o2[alen(a)];
    
    AEDSPFFTConvolution * conv = AEDSPFFTConvolutionInit(64);
    AEDSPFFTConvolutionExecute(conv, a, alen(a), b, alen(b), o1, alen(o1), AEDSPFFTConvolutionOperation_ConvolutionFull);
    
    AEDSPFFTConvolutionPrepareContinuous(conv, b, alen(b), AEDSPFFTConvolutionOperation_ConvolutionFull);
    for ( int i=0; i<alen(o2); ) {
        int block = (int)MIN(alen(o2)-i, 12);
        AEDSPFFTConvolutionExecuteContinuous(conv, a+i, block, o2+i, block);
        for ( int j=i; j<i+block; j++ ) {
            XCTAssertEqualWithAccuracy(o1[i], o2[i], 1.0e-5);
        }
        i += block;
    }
    
    AEDSPFFTConvolutionDealloc(conv);
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
