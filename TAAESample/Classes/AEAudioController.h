//
//  AEAudioController.h
//  TAAESample
//
//  Created by Michael Tyson on 24/03/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//
// Strictly for educational purposes only. No part of TAAESample is to be distributed
// in any form other than as source code within the TAAE2 repository.

#import <Foundation/Foundation.h>
#import <TheAmazingAudioEngine/TheAmazingAudioEngine.h>

@interface AEAudioController : NSObject
- (BOOL)start:(NSError * _Nullable * _Nullable)error;
- (void)stop;

- (BOOL)beginRecordingAtTime:(AEHostTicks)time error:(NSError * _Nullable * _Nullable)error;
- (void)stopRecordingAtTime:(AEHostTicks)time completionBlock:(void(^ _Nullable)())block;

- (void)playRecordingWithCompletionBlock:(void(^ _Nullable)())block;
- (void)stopPlayingRecording;

- (AEHostTicks)nextSyncTimeForPlayer:(AEAudioFilePlayerModule * _Nonnull)player;

@property (nonatomic, strong, readonly) AEVarispeedModule * _Nonnull varispeed;
@property (nonatomic, strong, readonly) AEAudioFilePlayerModule * _Nonnull drums;
@property (nonatomic, strong, readonly) AEAudioFilePlayerModule * _Nonnull bass;
@property (nonatomic, strong, readonly) AEAudioFilePlayerModule * _Nonnull piano;
@property (nonatomic, strong, readonly) AEAudioFilePlayerModule * _Nonnull sample1;
@property (nonatomic, strong, readonly) AEAudioFilePlayerModule * _Nonnull sample2;
@property (nonatomic, strong, readonly) AEAudioFilePlayerModule * _Nonnull sample3;
@property (nonatomic, strong, readonly) AEAudioFilePlayerModule * _Nonnull sweep;
@property (nonatomic, strong, readonly) AEAudioFilePlayerModule * _Nonnull hit;
@property (nonatomic) double bandpassCenterFrequency;
@property (nonatomic) double bandpassWetDry;
@property (nonatomic) double balanceSweepRate;
@property (nonatomic, readonly) BOOL recording;
@property (nonatomic, readonly) NSURL * _Nonnull recordingPath;
@property (nonatomic, readonly) BOOL playingRecording;
@property (nonatomic) BOOL inputEnabled;
@end
