//
//  AEBufferStackTests.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 31/03/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "AEBufferStack.h"
#import "AETypes.h"
#import "AEAudioBufferListUtilities.h"

@interface AEBufferStackTests : XCTestCase

@end

@implementation AEBufferStackTests

- (void)testPushPopRemove {
    AEBufferStack * stack = AEBufferStackNew(10);
    
    UInt32 frames = 1024;
    AEBufferStackSetFrameCount(stack, frames);
    
    AudioTimeStamp timestamp = { .mFlags = kAudioTimeStampSampleTimeValid, .mSampleTime = 1000 };
    AEBufferStackSetTimeStamp(stack, &timestamp);
    
    // Push a buffer, verify
    const AudioBufferList * item1 = AEBufferStackPush(stack, 1);
    XCTAssertNotEqual(item1, NULL);
    XCTAssertEqual(item1->mNumberBuffers, 2);
    XCTAssertEqual(item1->mBuffers[0].mDataByteSize, frames * AEAudioDescription.mBytesPerFrame);
    XCTAssertEqual(item1->mBuffers[1].mDataByteSize, frames * AEAudioDescription.mBytesPerFrame);
    XCTAssertEqual(item1, AEBufferStackGet(stack, 0));
    XCTAssertEqual(memcmp(&timestamp, AEBufferStackGetTimeStampForBuffer(stack, 0), sizeof(AudioTimeStamp)), 0);
    XCTAssertEqual(AEBufferStackCount(stack), 1);
    
    // Make note of the mData pointers, and set some values
    float * data1[2] = {item1->mBuffers[0].mData, item1->mBuffers[1].mData};
    data1[0][0] = 1.0;
    data1[1][0] = 2.0;
    
    // Push a mono buffer, verify
    const AudioBufferList * item2 = AEBufferStackPushWithChannels(stack, 1, 1);
    XCTAssertEqual(item2->mNumberBuffers, 1);
    XCTAssertEqual(item2->mBuffers[0].mDataByteSize, frames * AEAudioDescription.mBytesPerFrame);
    XCTAssertEqual(item2, AEBufferStackGet(stack, 0));
    XCTAssertEqual(item1, AEBufferStackGet(stack, 1));
    XCTAssertEqual(AEBufferStackCount(stack), 2);
    
    // Make note of mData pointer, set value
    float * data2 = item2->mBuffers[0].mData;
    data2[0] = 3.0;
    
    // Pop the mono buffer
    AEBufferStackPop(stack, 1);
    XCTAssertEqual(AEBufferStackCount(stack), 1);
    
    // Push a new stereo buffer - the buffer pointer itself should be identical
    const AudioBufferList * item2b = AEBufferStackPushWithChannels(stack, 1, 2);
    XCTAssertEqual(item2b, item2);
    XCTAssertEqual(item2b->mNumberBuffers, 2);
    XCTAssertEqual(item2b->mBuffers[0].mDataByteSize, frames * AEAudioDescription.mBytesPerFrame);
    XCTAssertEqual(item2b->mBuffers[1].mDataByteSize, frames * AEAudioDescription.mBytesPerFrame);
    XCTAssertEqual(item2b, AEBufferStackGet(stack, 0));
    XCTAssertEqual(item1, AEBufferStackGet(stack, 1));
    XCTAssertEqual(AEBufferStackCount(stack), 2);
    
    // Note the mData pointers - the first channel should be identical, and the value we set should be there still
    float * data2b = item2b->mBuffers[0].mData;
    XCTAssertEqual(data2b, data2);
    XCTAssertEqual(data2b[0], data2[0]);
    
    // Push 3 buffers at once, and verify
    const AudioBufferList * item3 = AEBufferStackPush(stack, 3);
    XCTAssertNotEqual(item3, NULL);
    XCTAssertEqual(AEBufferStackCount(stack), 5);
    
    // Take note of the mData pointers of the first buffer pushed
    float * data3[2] = {item3->mBuffers[0].mData, item3->mBuffers[1].mData};
    
    // Note the top two buffers, and verify that the next 3 are the ones we expected
    const AudioBufferList * item4 = AEBufferStackGet(stack, 1);
    const AudioBufferList * item5 = AEBufferStackGet(stack, 0);
    XCTAssertEqual(AEBufferStackGet(stack, 2), item3);
    XCTAssertEqual(AEBufferStackGet(stack, 3), item2);
    XCTAssertEqual(AEBufferStackGet(stack, 4), item1);
    
    // Remove a buffer from the middle ('item3')
    AEBufferStackRemove(stack, 2);
    
    // Verify stack contents
    XCTAssertEqual(AEBufferStackGet(stack, 0), item5);
    XCTAssertEqual(AEBufferStackGet(stack, 1), item4);
    XCTAssertEqual(AEBufferStackGet(stack, 2), item2);
    XCTAssertEqual(AEBufferStackGet(stack, 3), item1);
    XCTAssertEqual(AEBufferStackGet(stack, 4), NULL);
    XCTAssertEqual(AEBufferStackCount(stack), 4);
    
    // Push a buffer - it should be identical to item3
    const AudioBufferList * item3b = AEBufferStackPush(stack, 1);
    XCTAssertEqual(item3b, item3);
    float * data3b[2] = {item3b->mBuffers[0].mData, item3b->mBuffers[1].mData};
    XCTAssertEqual(data3b[0], data3[0]);
    XCTAssertEqual(data3b[1], data3[1]);
    XCTAssertEqual(AEBufferStackCount(stack), 5);
    
    // Remove another buffer from the middle ('item4')
    AEBufferStackRemove(stack, 2);
    
    // Verify stack contents
    XCTAssertEqual(AEBufferStackGet(stack, 0), item3);
    XCTAssertEqual(AEBufferStackGet(stack, 1), item5);
    XCTAssertEqual(AEBufferStackGet(stack, 2), item2);
    XCTAssertEqual(AEBufferStackGet(stack, 3), item1);
    XCTAssertEqual(AEBufferStackGet(stack, 4), NULL);
    XCTAssertEqual(AEBufferStackCount(stack), 4);
    
    // Swap top two items
    AEBufferStackSwap(stack);
    
    // Verify stack contents
    XCTAssertEqual(AEBufferStackGet(stack, 0), item5);
    XCTAssertEqual(AEBufferStackGet(stack, 1), item3);
    XCTAssertEqual(AEBufferStackGet(stack, 2), item2);
    XCTAssertEqual(AEBufferStackGet(stack, 3), item1);
    XCTAssertEqual(AEBufferStackGet(stack, 4), NULL);
    XCTAssertEqual(AEBufferStackCount(stack), 4);
    
    // Push an external buffer
    AudioBufferList * external
        = AEAudioBufferListCreateWithFormat(AEAudioDescriptionWithChannelsAndRate(2, 0), frames);
    const AudioBufferList * externalPushed = AEBufferStackPushExternal(stack, external);
    
    // Verify
    XCTAssertEqual(AEBufferStackGet(stack, 0)->mBuffers[0].mData, external->mBuffers[0].mData);
    XCTAssertEqual(AEBufferStackGet(stack, 0)->mBuffers[1].mData, external->mBuffers[1].mData);
    
    // Swap
    AEBufferStackSwap(stack);
    
    // Verify
    XCTAssertEqual(AEBufferStackGet(stack, 0), item5);
    XCTAssertEqual(AEBufferStackGet(stack, 1), externalPushed);
    XCTAssertEqual(AEBufferStackGet(stack, 1)->mBuffers[0].mData, external->mBuffers[0].mData);
    XCTAssertEqual(AEBufferStackGet(stack, 1)->mBuffers[1].mData, external->mBuffers[1].mData);
    
    // Pop 4 items at once
    AEBufferStackPop(stack, 4);
    
    // Verify stack contents
    XCTAssertEqual(AEBufferStackCount(stack), 1);
    XCTAssertEqual(AEBufferStackGet(stack, 0), item1);
    XCTAssertEqual(AEBufferStackGet(stack, 1), NULL);
    
    AEBufferStackFree(stack);
    AEAudioBufferListFree(external);
}

static inline float valueForChannelOfBuffer(int channel, int buffer) {
    return channel + 10*(buffer+1);
}

- (void)testMix {
    AEBufferStack * stack = AEBufferStackNewWithOptions(6, 4, 11);
    
    UInt32 frames = 128;
    AEBufferStackSetFrameCount(stack, frames);
    
    AudioBufferList * external
        = AEAudioBufferListCreateWithFormat(AEAudioDescriptionWithChannelsAndRate(2, 0), frames);
    
    // Push a bunch of buffers, with varying channel counts
    AEBufferStackPushWithChannels(stack, 1, 1);
    AEBufferStackPushWithChannels(stack, 1, 2);
    AEBufferStackPushWithChannels(stack, 1, 4);
    AEBufferStackPushWithChannels(stack, 1, 1);
    AEBufferStackPushExternal(stack, external);
    AEBufferStackPushWithChannels(stack, 1, 1);
    
    // Verify channel counts for each buffer
    XCTAssertEqual(AEBufferStackGet(stack, 5)->mNumberBuffers, 1);
    XCTAssertEqual(AEBufferStackGet(stack, 4)->mNumberBuffers, 2);
    XCTAssertEqual(AEBufferStackGet(stack, 3)->mNumberBuffers, 4);
    XCTAssertEqual(AEBufferStackGet(stack, 2)->mNumberBuffers, 1);
    XCTAssertEqual(AEBufferStackGet(stack, 1)->mNumberBuffers, 2);
    XCTAssertEqual(AEBufferStackGet(stack, 0)->mNumberBuffers, 1);
    
    [self seedBufferValues:stack];
    
    // Mix top two buffers (mono + stereo = stereo)
    const AudioBufferList * abl = AEBufferStackMixWithGain(stack, 2, (float[]){3.0, 5.0});
    XCTAssertEqual(abl->mNumberBuffers, 2);
    BOOL matching = YES;
    for ( int i=0; i<frames && matching; i++ ) {
        for ( int j=0; j<abl->mNumberBuffers; j++ ) {
            float value = ((float*)abl->mBuffers[j].mData)[i];
            float expected =
                (valueForChannelOfBuffer(0, 0) * 3.0) +
                (valueForChannelOfBuffer(j, 1) * 5.0);
            if ( value != expected ) {
                XCTAssertEqual(value, expected);
                matching = NO;
                break;
            }
        }
    }
    
    // Mix next two (stereo + mono = stereo)
    abl = AEBufferStackMixWithGain(stack, 2, (float[]){1.0, 7.0});
    XCTAssertEqual(abl->mNumberBuffers, 2);
    matching = YES;
    for ( int i=0; i<frames && matching; i++ ) {
        for ( int j=0; j<abl->mNumberBuffers; j++ ) {
            float value = ((float*)abl->mBuffers[j].mData)[i];
            float expected =
                (valueForChannelOfBuffer(0, 0) * 3.0) +
                (valueForChannelOfBuffer(j, 1) * 5.0) +
                (valueForChannelOfBuffer(0, 2) * 7.0);
            if ( value != expected ) {
                XCTAssertEqual(value, expected);
                matching = NO;
                break;
            }
        }
    }
    
    // Mix next two (stereo + 4 chan = 4 chan)
    abl = AEBufferStackMixWithGain(stack, 2, (float[]){1.0, 11.0});
    XCTAssertEqual(abl->mNumberBuffers, 4);
    matching = YES;
    for ( int i=0; i<frames && matching; i++ ) {
        for ( int j=0; j<abl->mNumberBuffers; j++ ) {
            float value = ((float*)abl->mBuffers[j].mData)[i];
            float expected =
                (j < 2 ?
                    ((valueForChannelOfBuffer(0, 0) * 3.0) +
                     (valueForChannelOfBuffer(j, 1) * 5.0) +
                     (valueForChannelOfBuffer(0, 2) * 7.0)) : 0) +
                (valueForChannelOfBuffer(j, 3) * 11.0);
            if ( value != expected ) {
                XCTAssertEqual(value, expected);
                matching = NO;
                break;
            }
        }
    }
    
    // Mix next two (4 chan + stereo = 4 chan)
    abl = AEBufferStackMixWithGain(stack, 2, (float[]){1.0, 13.0});
    XCTAssertEqual(abl->mNumberBuffers, 4);
    matching = YES;
    for ( int i=0; i<frames && matching; i++ ) {
        for ( int j=0; j<abl->mNumberBuffers; j++ ) {
            float value = ((float*)abl->mBuffers[j].mData)[i];
            float expected =
            (j < 2 ?
             ((valueForChannelOfBuffer(0, 0) * 3.0) +
              (valueForChannelOfBuffer(j, 1) * 5.0) +
              (valueForChannelOfBuffer(0, 2) * 7.0) +
              (valueForChannelOfBuffer(j, 4) * 13.0)) : 0) +
            (valueForChannelOfBuffer(j, 3) * 11.0);
            if ( value != expected ) {
                XCTAssertEqual(value, expected);
                matching = NO;
                break;
            }
        }
    }
    
    // Mix last two (4 chan + mono = 4 chan; no doubling to stereo)
    abl = AEBufferStackMixWithGain(stack, 2, (float[]){1.0, 17.0});
    XCTAssertEqual(abl->mNumberBuffers, 4);
    matching = YES;
    for ( int i=0; i<frames && matching; i++ ) {
        for ( int j=0; j<abl->mNumberBuffers; j++ ) {
            float value = ((float*)abl->mBuffers[j].mData)[i];
            float expected =
            (j < 2 ?
             ((valueForChannelOfBuffer(0, 0) * 3.0) +
              (valueForChannelOfBuffer(j, 1) * 5.0) +
              (valueForChannelOfBuffer(0, 2) * 7.0) +
              (valueForChannelOfBuffer(j, 4) * 13.0)) : 0) +
            (valueForChannelOfBuffer(j, 3) * 11.0) +
            (j < 1 ?
             (valueForChannelOfBuffer(0, 5) * 17.0) : 0);
            if ( value != expected ) {
                XCTAssertEqual(value, expected);
                matching = NO;
                break;
            }
        }
    }
    
    AEBufferStackFree(stack);
    AEAudioBufferListFree(external);
}

- (void)testMixToOutput {
    AEBufferStack * stack = AEBufferStackNew(0);
    
    UInt32 frames = 128;
    AEBufferStackSetFrameCount(stack, frames);
    
    // Push a few buffers, with varying channel counts
    AEBufferStackPushWithChannels(stack, 1, 1);
    AEBufferStackPushWithChannels(stack, 1, 2);
    [self seedBufferValues:stack];
    
    // Mix both buffers to a mono output
    AudioBufferList * abl = AEAudioBufferListCreateWithFormat(AEAudioDescriptionWithChannelsAndRate(1, 0), frames);
    AEAudioBufferListSilence(abl, 0, frames);
    AEBufferStackMixToBufferList(stack, 0, abl);
    
    BOOL matching = YES;
    for ( int i=0; i<frames && matching; i++ ) {
        for ( int j=0; j<abl->mNumberBuffers; j++ ) {
            float value = ((float*)abl->mBuffers[j].mData)[i];
            float expected = valueForChannelOfBuffer(0, 1) +
                             valueForChannelOfBuffer(0, 0) +
                             valueForChannelOfBuffer(1, 0);
            if ( value != expected ) {
                XCTAssertEqual(value, expected);
                matching = NO;
                break;
            }
        }
    }
    
    // Mix both buffers to a stereo output
    abl = AEAudioBufferListCreateWithFormat(AEAudioDescriptionWithChannelsAndRate(2, 0), frames);
    AEAudioBufferListSilence(abl, 0, frames);
    AEBufferStackMixToBufferList(stack, 0, abl);
    
    matching = YES;
    for ( int i=0; i<frames && matching; i++ ) {
        for ( int j=0; j<abl->mNumberBuffers; j++ ) {
            float value = ((float*)abl->mBuffers[j].mData)[i];
            float expected = valueForChannelOfBuffer(0, 1) +
                             valueForChannelOfBuffer(j, 0);
            if ( value != expected ) {
                XCTAssertEqual(value, expected);
                matching = NO;
                break;
            }
        }
    }
    
    // Mix both buffers to 3rd channel of a 4 channel output
    abl = AEAudioBufferListCreateWithFormat(AEAudioDescriptionWithChannelsAndRate(4, 0), frames);
    AEAudioBufferListSilence(abl, 0, frames);
    AEBufferStackMixToBufferListChannels(stack, 0, AEChannelSetMake(2, 2), abl);
    
    matching = YES;
    for ( int i=0; i<frames && matching; i++ ) {
        for ( int j=0; j<abl->mNumberBuffers; j++ ) {
            float value = ((float*)abl->mBuffers[j].mData)[i];
            float expected = j == 2 ? valueForChannelOfBuffer(0, 1) +
                                      valueForChannelOfBuffer(0, 0) +
                                      valueForChannelOfBuffer(1, 0) : 0;
            if ( value != expected ) {
                XCTAssertEqual(value, expected);
                matching = NO;
                break;
            }
        }
    }
    
    // Mix both buffers to 3rd+4th channel of a 4 channel output
    abl = AEAudioBufferListCreateWithFormat(AEAudioDescriptionWithChannelsAndRate(4, 0), frames);
    AEAudioBufferListSilence(abl, 0, frames);
    AEBufferStackMixToBufferListChannels(stack, 0, AEChannelSetMake(2, 3), abl);
    
    matching = YES;
    for ( int i=0; i<frames && matching; i++ ) {
        for ( int j=0; j<abl->mNumberBuffers; j++ ) {
            float value = ((float*)abl->mBuffers[j].mData)[i];
            float expected = j == 2 ? valueForChannelOfBuffer(0, 1) +
                                      valueForChannelOfBuffer(0, 0)
                           : j == 3 ? valueForChannelOfBuffer(0, 1) +
                                      valueForChannelOfBuffer(1, 0) : 0;
            if ( value != expected ) {
                XCTAssertEqual(value, expected);
                matching = NO;
                break;
            }
        }
    }
    
    AEBufferStackFree(stack);
}

#pragma mark -

- (void)seedBufferValues:(AEBufferStack *)stack {
    // Seed values: channel k of buffer i has value 10*(i+1) + k
    UInt32 frames = AEBufferStackGetFrameCount(stack);
    for ( int i=0; i<AEBufferStackCount(stack); i++ ) {
        const AudioBufferList * abl = AEBufferStackGet(stack, i);
        for ( int j=0; j<frames; j++ ) {
            for ( int k=0; k<abl->mNumberBuffers; k++ ) {
                ((float*)abl->mBuffers[k].mData)[j] = valueForChannelOfBuffer(k, i);
            }
        }
    }
}

@end
