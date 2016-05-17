//
//  AEAudioBufferListUtilitiesTests.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 17/05/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "AEAudioBufferListUtilities.h"
#import "AEDSPUtilities.h"

@interface AEAudioBufferListUtilitiesTests : XCTestCase

@end

@implementation AEAudioBufferListUtilitiesTests

- (void)testManipulation {
    AudioBufferList * initialAbl = AEAudioBufferListCreate(256);
    [self assignBufferValues:initialAbl];
    int channels;
    XCTAssertEqual(AEAudioBufferListGetLength(initialAbl, &channels), 256);
    XCTAssertEqual(channels, 2);
    
    AudioBufferList * copiedAbl = AEAudioBufferListCopy(initialAbl);
    XCTAssertTrue([self verifyBufferValues:copiedAbl]);
    XCTAssertEqual(AEAudioBufferListGetLength(copiedAbl, &channels), 256);
    XCTAssertEqual(channels, 2);
    AEAudioBufferListSetLength(copiedAbl, 128);
    XCTAssertEqual(copiedAbl->mBuffers[0].mDataByteSize, 128 * AEAudioDescription.mBytesPerFrame);
    
    AudioBufferList * newAbl = AEAudioBufferListCreate(256);
    AEAudioBufferListCopyContents(newAbl, initialAbl, 0, 0, 256);
    XCTAssertTrue([self verifyBufferValues:newAbl]);
    
    AEAudioBufferListSilence(newAbl, 0, 256);
    AEAudioBufferListCopyContents(newAbl, initialAbl, 128, 0, 0);
    
    XCTAssertTrue(([self verifyBufferValues:newAbl comparisonBlock:^float (int index) {
        return index < 128 ? 0.0 : ((float*)initialAbl->mBuffers[0].mData)[index-128];
    }]));
    
    AEAudioBufferListCopyContents(newAbl, initialAbl, 64, 64, 64);
    XCTAssertTrue(([self verifyBufferValues:newAbl comparisonBlock:^float (int index) {
        return index < 64 ? 0.0 :
            index < 128 ? ((float*)initialAbl->mBuffers[0].mData)[index]
            : ((float*)initialAbl->mBuffers[0].mData)[index-128];
    }]));
    
    AEAudioBufferListCopyOnStack(stackCopy, initialAbl, 128);
    XCTAssertEqual(stackCopy->mBuffers[0].mData, initialAbl->mBuffers[0].mData + sizeof(float) * (128));
    XCTAssertEqual(stackCopy->mBuffers[0].mDataByteSize, 128 * AEAudioDescription.mBytesPerFrame);
    
    AEAudioBufferListOffset(stackCopy, 32);
    XCTAssertEqual(stackCopy->mBuffers[0].mData, initialAbl->mBuffers[0].mData + sizeof(float) * (128+32));
    XCTAssertEqual(stackCopy->mBuffers[0].mDataByteSize, 96 * AEAudioDescription.mBytesPerFrame);
    
    AEAudioBufferListCopyOnStackWithChannelSubset(subsetCopy, initialAbl, AEChannelSetMake(1, 1));
    XCTAssertEqual(subsetCopy->mNumberBuffers, 1);
    XCTAssertEqual(subsetCopy->mBuffers[0].mData, initialAbl->mBuffers[1].mData);
    
    
    AEAudioBufferListFree(copiedAbl);
    AEAudioBufferListFree(newAbl);
    AEAudioBufferListFree(initialAbl);
}

- (void)testOtherFormats {
    int channels;
    
    // Noninterleaved int 16
    AudioStreamBasicDescription nonInterleavedInt16 = {
        .mFormatID          = kAudioFormatLinearPCM,
        .mFormatFlags       = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsNonInterleaved,
        .mChannelsPerFrame  = 2,
        .mBytesPerPacket    = sizeof(SInt16),
        .mFramesPerPacket   = 1,
        .mBytesPerFrame     = sizeof(SInt16),
        .mBitsPerChannel    = 8 * sizeof(SInt16),
        .mSampleRate        = 44100.0,
    };
    AudioBufferList * nonInterleavedInt16Abl = AEAudioBufferListCreateWithFormat(nonInterleavedInt16, 256);
    XCTAssertEqual(nonInterleavedInt16Abl->mNumberBuffers, 2);
    XCTAssertEqual(nonInterleavedInt16Abl->mBuffers[0].mDataByteSize, 256 * sizeof(SInt16));
    XCTAssertEqual(nonInterleavedInt16Abl->mBuffers[1].mDataByteSize, 256 * sizeof(SInt16));
    XCTAssertEqual(AEAudioBufferListGetLengthWithFormat(nonInterleavedInt16Abl, nonInterleavedInt16, &channels), 256);
    XCTAssertEqual(channels, 2);
    AEAudioBufferListSetLengthWithFormat(nonInterleavedInt16Abl, nonInterleavedInt16, 128);
    XCTAssertEqual(nonInterleavedInt16Abl->mBuffers[0].mDataByteSize, 128 * sizeof(SInt16));
    XCTAssertEqual(nonInterleavedInt16Abl->mBuffers[1].mDataByteSize, 128 * sizeof(SInt16));
    XCTAssertEqual(AEAudioBufferListGetLengthWithFormat(nonInterleavedInt16Abl, nonInterleavedInt16, &channels), 128);
    AEAudioBufferListCopyOnStackWithByteOffset(nonInterleavedInt16AblStack, nonInterleavedInt16Abl, 32 * sizeof(SInt16));
    XCTAssertEqual(nonInterleavedInt16AblStack->mBuffers[0].mData, nonInterleavedInt16Abl->mBuffers[0].mData + 32 * sizeof(SInt16));
    XCTAssertEqual(nonInterleavedInt16AblStack->mBuffers[1].mData, nonInterleavedInt16Abl->mBuffers[1].mData + 32 * sizeof(SInt16));
    XCTAssertEqual(nonInterleavedInt16AblStack->mBuffers[0].mDataByteSize, (128-32) * sizeof(SInt16));
    XCTAssertEqual(nonInterleavedInt16AblStack->mBuffers[1].mDataByteSize, (128-32) * sizeof(SInt16));
    AEAudioBufferListOffsetWithFormat(nonInterleavedInt16AblStack, nonInterleavedInt16, 32);
    XCTAssertEqual(nonInterleavedInt16AblStack->mBuffers[0].mData, nonInterleavedInt16Abl->mBuffers[0].mData + 64 * sizeof(SInt16));
    XCTAssertEqual(nonInterleavedInt16AblStack->mBuffers[1].mData, nonInterleavedInt16Abl->mBuffers[1].mData + 64 * sizeof(SInt16));
    XCTAssertEqual(nonInterleavedInt16AblStack->mBuffers[0].mDataByteSize, (128-64) * sizeof(SInt16));
    XCTAssertEqual(nonInterleavedInt16AblStack->mBuffers[1].mDataByteSize, (128-64) * sizeof(SInt16));
    XCTAssertEqual(AEAudioBufferListGetStructSize(nonInterleavedInt16Abl), sizeof(AudioBufferList)+sizeof(AudioBuffer));
    
    // Interleaved int 16
    AudioStreamBasicDescription interleavedInt16 = {
        .mFormatID          = kAudioFormatLinearPCM,
        .mFormatFlags       = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian,
        .mChannelsPerFrame  = 2,
        .mBytesPerPacket    = sizeof(SInt16)*2,
        .mFramesPerPacket   = 1,
        .mBytesPerFrame     = sizeof(SInt16)*2,
        .mBitsPerChannel    = 8 * sizeof(SInt16),
        .mSampleRate        = 44100.0,
    };
    AudioBufferList * interleavedInt16Abl = AEAudioBufferListCreateWithFormat(interleavedInt16, 256);
    XCTAssertEqual(interleavedInt16Abl->mNumberBuffers, 1);
    XCTAssertEqual(interleavedInt16Abl->mBuffers[0].mDataByteSize, 256 * 2 * sizeof(SInt16));
    XCTAssertEqual(AEAudioBufferListGetLengthWithFormat(interleavedInt16Abl, interleavedInt16, &channels), 256);
    XCTAssertEqual(channels, 2);
    AEAudioBufferListSetLengthWithFormat(interleavedInt16Abl, interleavedInt16, 128);
    XCTAssertEqual(interleavedInt16Abl->mBuffers[0].mDataByteSize, 128 * 2 * sizeof(SInt16));
    XCTAssertEqual(AEAudioBufferListGetLengthWithFormat(interleavedInt16Abl, interleavedInt16, &channels), 128);
    AEAudioBufferListCopyOnStackWithByteOffset(interleavedInt16AblStack, interleavedInt16Abl, 32 * 2 * sizeof(SInt16));
    XCTAssertEqual(interleavedInt16AblStack->mBuffers[0].mData, interleavedInt16Abl->mBuffers[0].mData + 32 * 2 * sizeof(SInt16));
    XCTAssertEqual(interleavedInt16AblStack->mBuffers[0].mDataByteSize, (128-32) * 2 * sizeof(SInt16));
    AEAudioBufferListOffsetWithFormat(interleavedInt16AblStack, interleavedInt16, 32);
    XCTAssertEqual(interleavedInt16AblStack->mBuffers[0].mData, interleavedInt16Abl->mBuffers[0].mData + 64 * 2 * sizeof(SInt16));
    XCTAssertEqual(interleavedInt16AblStack->mBuffers[0].mDataByteSize, (128-64) * 2 * sizeof(SInt16));
    XCTAssertEqual(AEAudioBufferListGetStructSize(interleavedInt16Abl), sizeof(AudioBufferList));
    
    AEAudioBufferListFree(interleavedInt16Abl);
    AEAudioBufferListFree(nonInterleavedInt16Abl);
}

#pragma mark -

- (void)assignBufferValues:(AudioBufferList *)buffer {
    float position = 0;
    for ( int i=0; i<buffer->mBuffers[0].mDataByteSize / AEAudioDescription.mBytesPerFrame; i++ ) {
        float sample = AEDSPGenerateOscillator(440.0/44100.0, &position);
        for ( int j=0; j<buffer->mNumberBuffers; j++ ) {
            ((float*)buffer->mBuffers[j].mData)[i] = sample;
        }
    }
}

- (BOOL)verifyBufferValues:(AudioBufferList *)buffer {
    __block float position = 0;
    return [self verifyBufferValues:buffer comparisonBlock:^float(int index) {
        return AEDSPGenerateOscillator(440.0/44100.0, &position);
    }];
}

- (BOOL)verifyBufferValues:(AudioBufferList *)buffer comparisonBlock:(float(^)(int index))block {
    for ( int i=0; i<buffer->mBuffers[0].mDataByteSize / AEAudioDescription.mBytesPerFrame; i++ ) {
        float sample = block(i);
        for ( int j=0; j<buffer->mNumberBuffers; j++ ) {
            if ( fabsf(((float*)buffer->mBuffers[j].mData)[i] - sample) > 1.0e-6 ) {
                return NO;
            }
        }
    }
    return YES;
}

@end
