//
//  AEAudioFileReaderTests.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 22/05/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "AEAudioFileReader.h"
#import "AEUtilities.h"
#import "AEAudioBufferListUtilities.h"
#import "AEAudioFileOutput.h"
#import "AEOscillatorModule.h"
#import "AEDSPUtilities.h"
#import "AERenderer.h"

static const NSTimeInterval kTestFileLength = 0.5;

@interface AEAudioFileReaderTests : XCTestCase
@property (nonatomic, strong, readonly) NSURL * fileURL;
@end

@implementation AEAudioFileReaderTests
@dynamic fileURL;

- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtURL:[self fileURL] error:NULL];
}

- (void)testWriting {
    NSError * error = [self createTestFile];
    XCTAssertNil(error);
    
    AudioStreamBasicDescription asbd;
    UInt32 length;
    BOOL result = [AEAudioFileReader infoForFileAtURL:self.fileURL
                                     audioDescription:&asbd length:&length error:NULL];
    XCTAssertTrue(result);
    
    XCTAssertEqualWithAccuracy(asbd.mSampleRate, 44100.0, DBL_EPSILON);
    XCTAssertEqual(asbd.mChannelsPerFrame, 1);
    XCTAssertEqual(length, kTestFileLength * 44100.0);
}

- (void)testLoad {
    [self createTestFile];
    
    __block AudioBufferList * buffer = NULL;
    __block UInt32 bufferLength = 0;
    [AEAudioFileReader loadFileAtURL:self.fileURL
              targetAudioDescription:AEAudioDescription
                     completionBlock:^(AudioBufferList * _Nullable audio, UInt32 length, NSError * _Nullable error) {
        bufferLength = length;
        buffer = audio;
    }];
    
    while ( !buffer ) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    
    XCTAssert(buffer != NULL);
    XCTAssertEqual(bufferLength / 44100.0, kTestFileLength);
    
    if ( buffer ) {
        NSString * error = nil;
        BOOL match = YES;
        float position = 0;
        for ( UInt32 frame = 0; frame < bufferLength; frame++ ) {
            double sample = AEDSPGenerateOscillator(440.0/44100.0, &position) - 0.5;
            if ( fabs(sample - ((float*)buffer->mBuffers[0].mData)[frame]) > 1.0e-3 ) {
                error = [NSString stringWithFormat:@"frame %d, %f != %f",
                         (int)frame, ((float*)buffer->mBuffers[0].mData)[frame], sample];
                match = NO;
                break;
            }
        }
        XCTAssertTrue(match, @"%@", error);
        AEAudioBufferListFree(buffer);
    }
}

- (void)testRead {
    [self createTestFile];
    
    __block BOOL done = NO;
    __block float position = 0;
    __block UInt32 framesSeen = 0;
    __weak AEAudioFileReader * reader =
    [AEAudioFileReader readFileAtURL:self.fileURL
              targetAudioDescription:AEAudioDescription
                           readBlock:^(const AudioBufferList * buffer, UInt32 length) {
                               XCTAssertEqual(length, MIN(512, (kTestFileLength*44100.0)-framesSeen));
                               NSString * error = nil;
                               BOOL match = YES;
                               for ( UInt32 frame = 0; frame < length; frame++ ) {
                                   double sample = AEDSPGenerateOscillator(440.0/44100.0, &position) - 0.5;
                                   if ( fabs(sample - ((float*)buffer->mBuffers[0].mData)[frame]) > 1.0e-3 ) {
                                       error = [NSString stringWithFormat:@"frame %d, %f != %f",
                                                (int)frame, ((float*)buffer->mBuffers[0].mData)[frame], sample];
                                       match = NO;
                                       break;
                                   }
                               }
                               framesSeen += length;
                               XCTAssertTrue(match, @"%@", error);
                               if ( !match ) {
                                   [reader cancel];
                               }
                           } completionBlock:^(NSError * _Nullable error) {
                               XCTAssertNil(error);
                               done = YES;
                           } blockSize:512];
    
    while ( !done ) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    
    XCTAssertEqual(framesSeen, kTestFileLength * 44100.0);
}

#pragma mark -

- (NSURL *)fileURL {
    return [NSURL fileURLWithPath:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"AEAudioFileReaderTests.aiff"]];
}

- (NSError *)createTestFile {
    AERenderer * renderer = [AERenderer new];
    AEAudioFileOutput * output = [[AEAudioFileOutput alloc] initWithRenderer:renderer URL:self.fileURL type:AEAudioFileTypeAIFFInt16 sampleRate:44100.0 channelCount:1 error:NULL];
    AEOscillatorModule * osc = [[AEOscillatorModule alloc] initWithRenderer:renderer];
    osc.frequency = 440.0;
    renderer.block = ^(const AERenderContext * context) {
        AEModuleProcess(osc, context);
        AERenderContextOutput(context, 1);
    };
    
    __block BOOL done = NO;
    __block NSError * error = nil;
    [output runForDuration:kTestFileLength completionBlock:^(NSError * e){
        done = YES;
        error = e;
    }];
    while ( !done ) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    [output finishWriting];
    return error;
}

@end
