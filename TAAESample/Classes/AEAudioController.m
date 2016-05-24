//
//  AEAudioController.m
//  TAAESample
//
//  Created by Michael Tyson on 24/03/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//
// Strictly for educational purposes only. No part of TAAESample is to be distributed
// in any form other than as source code within the TAAE2 repository.

#import "AEAudioController.h"
#import <AVFoundation/AVFoundation.h>

static const AESeconds kCountInThreshold = 0.2;
static const double kMicBandpassCenterFrequency = 2000.0;

@interface AEAudioController ()
@property (nonatomic, strong, readwrite) AEAudioUnitInputModule * input;
@property (nonatomic, strong, readwrite) AEAudioUnitOutput * output;
@property (nonatomic, strong, readwrite) AEVarispeedModule * varispeed;
@property (nonatomic, strong, readwrite) AEAudioFilePlayerModule * drums;
@property (nonatomic, strong, readwrite) AEAudioFilePlayerModule * bass;
@property (nonatomic, strong, readwrite) AEAudioFilePlayerModule * piano;
@property (nonatomic, strong, readwrite) AEAudioFilePlayerModule * sample1;
@property (nonatomic, strong, readwrite) AEAudioFilePlayerModule * sample2;
@property (nonatomic, strong, readwrite) AEAudioFilePlayerModule * sample3;
@property (nonatomic, strong, readwrite) AEAudioFilePlayerModule * sweep;
@property (nonatomic, strong, readwrite) AEAudioFilePlayerModule * hit;
@property (nonatomic, strong, readwrite) AEBandpassModule * bandpass;
@property (nonatomic, strong, readwrite) AEBandpassModule * micBandpass;
@property (nonatomic, readwrite) BOOL recording;
@property (nonatomic, readwrite) BOOL playingRecording;
@property (nonatomic, strong) AEManagedValue * recorderValue;
@property (nonatomic, strong) AEManagedValue * playerValue;
@property (nonatomic) BOOL playingThroughSpeaker;
@property (nonatomic, strong) id routeChangeObserverToken;
@property (nonatomic, strong) id audioInterruptionObserverToken;
@end

@implementation AEAudioController

#pragma mark - Life-cycle

- (instancetype)init {
    if ( !(self = [super init]) ) return nil;
    
    AERenderer * renderer = [AERenderer new];
    AERenderer * subrenderer = [AERenderer new];
    
    self.output = [[AEAudioUnitOutput alloc] initWithRenderer:renderer];
    
    NSMutableArray * players = [NSMutableArray array];
    
    // Setup loops
    NSURL * url = [[NSBundle mainBundle] URLForResource:@"amen" withExtension:@"m4a"];
    AEAudioFilePlayerModule * drums = [[AEAudioFilePlayerModule alloc] initWithRenderer:subrenderer URL:url error:NULL];
    drums.loop = YES;
    drums.microfadeFrames = 32; // Microfade a little, to avoid clicks when turning on/off in the middle
    self.drums = drums;
    [players addObject:drums];
    
    url = [[NSBundle mainBundle] URLForResource:@"bass" withExtension:@"m4a"];
    AEAudioFilePlayerModule * bass = [[AEAudioFilePlayerModule alloc] initWithRenderer:subrenderer URL:url error:NULL];
    bass.loop = YES;
    bass.microfadeFrames = 32;
    self.bass = bass;
    [players addObject:bass];
    
    url = [[NSBundle mainBundle] URLForResource:@"piano" withExtension:@"m4a"];
    AEAudioFilePlayerModule * piano = [[AEAudioFilePlayerModule alloc] initWithRenderer:subrenderer URL:url error:NULL];
    piano.loop = YES;
    piano.microfadeFrames = 32;
    self.piano = piano;
    [players addObject:piano];
    
    // Setup one-shots
    url = [[NSBundle mainBundle] URLForResource:@"sample1" withExtension:@"m4a"];
    AEAudioFilePlayerModule * oneshot = [[AEAudioFilePlayerModule alloc] initWithRenderer:subrenderer URL:url error:NULL];
    self.sample1 = oneshot;
    [players addObject:oneshot];
    
    url = [[NSBundle mainBundle] URLForResource:@"sample2" withExtension:@"m4a"];
    oneshot = [[AEAudioFilePlayerModule alloc] initWithRenderer:subrenderer URL:url error:NULL];
    self.sample2 = oneshot;
    [players addObject:oneshot];
    
    oneshot = [[AEAudioFilePlayerModule alloc] initWithRenderer:subrenderer URL:url error:NULL];
    oneshot.regionStartTime = 1.832;
    self.sample3 = oneshot;
    [players addObject:oneshot];
    
    url = [[NSBundle mainBundle] URLForResource:@"sweep" withExtension:@"m4a"];
    oneshot = [[AEAudioFilePlayerModule alloc] initWithRenderer:subrenderer URL:url error:NULL];
    self.sweep = oneshot;
    [players addObject:oneshot];
    
    url = [[NSBundle mainBundle] URLForResource:@"amen" withExtension:@"m4a"];
    oneshot = [[AEAudioFilePlayerModule alloc] initWithRenderer:subrenderer URL:url error:NULL];
    oneshot.regionDuration = drums.regionDuration / 32;
    oneshot.loop = YES;
    self.hit = oneshot;
    [players addObject:oneshot];
    
    // Create an aggregator module to run the players
    AEAggregatorModule * aggregator = [[AEAggregatorModule alloc] initWithRenderer:subrenderer];
    aggregator.modules = players;
    
    // Setup mic input (we'll draw from the output's IO audio unit, on iOS; on the Mac, this has its own IO unit).
    AEAudioUnitInputModule * input = self.output.inputModule;
    self.input = input;
    
    // Setup effects
    AEBandpassModule * bandpass = [[AEBandpassModule alloc] initWithRenderer:renderer];
    bandpass.wetDry = 0.0;
    self.bandpass = bandpass;
    __block float balanceLfo = 1.0;
    __block float currentBalalance = 0.0;
    
    AEDelayModule * micDelay = [[AEDelayModule alloc] initWithRenderer:renderer];
    micDelay.delayTime = drums.regionDuration / 32.0;
    AEBandpassModule * micBandpass = [[AEBandpassModule alloc] initWithRenderer:renderer];
    micBandpass.centerFrequency = kMicBandpassCenterFrequency;
    self.micBandpass = micBandpass;
    
    // Setup varispeed renderer. This is all performed on the audio thread, so the usual
    // rules apply: No holding locks, no memory allocation, no Objective-C/Swift code.
    AEVarispeedModule * varispeed = [[AEVarispeedModule alloc] initWithRenderer:renderer subrenderer:subrenderer];
    subrenderer.block = ^(const AERenderContext * _Nonnull context) {
        // Run all the players, though the aggregator
        AEModuleProcess(aggregator, context);
        
        // Put the resulting buffer on the output
        AERenderContextOutput(context, 1);
    };
    self.varispeed = varispeed;
    
    // Setup recorder placeholder
    AEManagedValue * recorderValue = [AEManagedValue new];
    self.recorderValue = recorderValue;
    
    // Setup recording player placeholder
    AEManagedValue * playerValue = [AEManagedValue new];
    self.playerValue = playerValue;
    
    // Setup top-level renderer. This is all performed on the audio thread, so the usual
    // rules apply: No holding locks, no memory allocation, no Objective-C/Swift code.
    renderer.block = ^(const AERenderContext * _Nonnull context) {
        
        // See if we have an active recorder
        __unsafe_unretained AEAudioFileRecorderModule * recorder
            = (__bridge AEAudioFileRecorderModule *)AEManagedValueGetValue(recorderValue);
        
        // See if we have an active player
        __unsafe_unretained AEAudioFilePlayerModule * player
         = (__bridge AEAudioFilePlayerModule *)AEManagedValueGetValue(playerValue);
        
        // Run varispeed unit, which will run its own render loop, above
        AEModuleProcess(varispeed, context);
        
        // Run through bandpass effect
        AEModuleProcess(bandpass, context);
        
        // Sweep balance
        float bal = 0.0;
        if ( _balanceSweepRate > 0 ) {
            bal = AEDSPGenerateOscillator((1.0/_balanceSweepRate) / (context->sampleRate/context->frames), &balanceLfo) * 2 - 1;
        } else {
            balanceLfo = 0.5;
        }
        AEBufferStackApplyFaders(context->stack, 1, NULL, bal, &currentBalalance);
        
        if ( player ) {
            // If we're playing a recording, duck other output
            AEDSPApplyGain(AEBufferStackGet(context->stack, 0), 0.1, context->frames);
        }
        
        // Put on output
        AERenderContextOutput(context, 1);
        
        if ( _inputEnabled ) {
            // Add audio input
            AEModuleProcess(input, context);
            
            // Add effects to input, and amplify by a factor of 2x to recover lost gain from bandpass
            AEModuleProcess(micDelay, context);
            AEModuleProcess(micBandpass, context);
            AEDSPApplyGain(AEBufferStackGet(context->stack, 0), 2.0, context->frames);
            
            // If it's safe to do so, put this on the output
            if ( !_playingThroughSpeaker ) {
                if ( player ) {
                    // If we're playing a recording, duck first
                    AEDSPApplyGain(AEBufferStackGet(context->stack, 0), 0.1, context->frames);
                }
                
                AERenderContextOutput(context, 1);
            }
        }
        
        // Run through recorder, if it's there
        if ( recorder && !player ) {
            if ( _inputEnabled ) {
                // We have a buffer from input to mix in
                AEBufferStackMix(context->stack, 2);
            }
            
            // Run through recorder
            AEModuleProcess(recorder, context);
        }
        
        // Play recorded file, if playing
        if ( player ) {
            // Play
            AEModuleProcess(player, context);
            
            // Put on output
            AERenderContextOutput(context, 1);
        }
    };
    
    return self;
}

- (void)dealloc {
    [self stop];
}

- (BOOL)start:(NSError *__autoreleasing *)error {
    return [self start:error registerObservers:YES];
}

- (BOOL)start:(NSError *__autoreleasing *)error registerObservers:(BOOL)registerObservers {

    // Request a 128 frame hardware duration, for minimal latency
    AVAudioSession * session = [AVAudioSession sharedInstance];
    [session setPreferredIOBufferDuration:128.0/session.sampleRate error:NULL];
    
    // Start the session
    if ( ![self setAudioSessionCategory:error] || ![session setActive:YES error:error] ) {
        return NO;
    }
    
    // Work out if we're playing through the speaker (which affects whether we do input monitoring, to avoid feedback)
    [self updatePlayingThroughSpeaker];
    
    if ( registerObservers ) {
        // Watch for some important notifications
        [self registerObservers];
    }
    
    // Start the output and input (note, starting the input actually a no-op on iOS)
    return [self.output start:error] && (!self.inputEnabled || [self.input start:error]);
}

- (void)stop {
    [self stopAndRemoveObservers:YES];
}

- (void)stopAndRemoveObservers:(BOOL)removeObservers {
    // Stop, and deactivate the audio session
    [self.output stop];
    [self.input stop]; // (this is a no-op on iOS)
    [[AVAudioSession sharedInstance] setActive:NO error:NULL];
    
    if ( removeObservers ) {
        // Remove our notification handlers
        [self unregisterObservers];
    }
}

#pragma mark - Recording

- (BOOL)beginRecordingAtTime:(AEHostTicks)time error:(NSError**)error {
    if ( self.recording ) return NO;
    
    // Create recorder
    AEAudioFileRecorderModule * recorder = [[AEAudioFileRecorderModule alloc] initWithRenderer:self.output.renderer
        URL:self.recordingPath type:AEAudioFileTypeM4A error:error];
    if ( !recorder ) {
        return NO;
    }
    
    // Make recorder available to audio renderer
    self.recorderValue.objectValue = recorder;
    
    self.recording = YES;
    [recorder beginRecordingAtTime:time];
    
    return YES;
}

- (void)stopRecordingAtTime:(AEHostTicks)time completionBlock:(void(^)())block {
    if ( !self.recording ) return;
    
    // End recording
    AEAudioFileRecorderModule * recorder = self.recorderValue.objectValue;
    __weak AEAudioController * weakSelf = self;
    [recorder stopRecordingAtTime:time completionBlock:^{
        weakSelf.recording = NO;
        weakSelf.recorderValue.objectValue = nil;
        if ( block ) block();
    }];
}

- (void)playRecordingWithCompletionBlock:(void (^)())block {
    NSURL * url = self.recordingPath;
    if ( [[NSFileManager defaultManager] fileExistsAtPath:url.path] ) {
        
        // Start player
        AEAudioFilePlayerModule * player =
            [[AEAudioFilePlayerModule alloc] initWithRenderer:self.output.renderer URL:url error:NULL];
        if ( !player ) return;
        
        // Make player available to audio renderer
        self.playerValue.objectValue = player;
        __weak AEAudioController * weakSelf = self;
        player.completionBlock = ^{
            // Keep track of when playback ends
            [weakSelf stopPlayingRecording];
            if ( block ) block();
        };
        
        // Go
        self.playingRecording = YES;
        [player playAtTime:0];
    }
}

- (void)stopPlayingRecording {
    self.playingRecording = NO;
    self.playerValue.objectValue = nil;
}

#pragma mark - Timing

- (AEHostTicks)nextSyncTimeForPlayer:(AEAudioFilePlayerModule *)player {
    AEHostTicks now = AECurrentTimeInHostTicks();
    
    if ( player == self.sweep ) {
        // Instant play for this oneshot
        return 0;
    }
    
    // Identify time-keeper
    AEAudioFilePlayerModule * timekeeper =
        // Use the longest playing loop as the timekeeper - the following are in order of duration
        self.piano.playing ? self.piano :
        self.bass.playing ? self.bass :
        self.drums.playing ? self.drums :
        self.hit.playing ? self.hit :
        nil;
    
    if ( timekeeper ) {
        // Determine sync interval
        AESeconds intervalLength =
            // If the hit's the only loop playing, quantize with a beat
            timekeeper == self.hit ? self.drums.duration / 32 :
            // Quantize the first two samples with the drums
            player == self.sample1 || player == self.sample2 ? self.drums.duration :
            // Quantize the hit with its own duration
            player == self.hit ? self.hit.regionDuration :
            // Bringing in the bass? Time it to the piano so the chord progressions match
            player == self.bass && timekeeper == self.piano ? self.piano.duration :
            // Ditto with the piano
            player == self.piano ? self.bass.duration :
            // Otherwise, time to a quarter of the drums' duration
            self.drums.duration / 4.0;
        
        // Work out how far into this interal the timekeeper is
        AESeconds timeIntoInterval = fmod(AEAudioFilePlayerModuleGetPlayhead(timekeeper, now), intervalLength);
        
        // Calculate time to next interval
        AEHostTicks nextIntervalTime
            = now + AEHostTicksFromSeconds((intervalLength - timeIntoInterval)) / self.varispeed.playbackRate;
        
        // Offset, for the one-shots (for aesthetic reasons!)
        if ( player == self.sample1 ) {
            nextIntervalTime -= AEHostTicksFromSeconds(0.96 / self.varispeed.playbackRate);
        } else if ( player == self.sample2 ) {
            nextIntervalTime -= AEHostTicksFromSeconds(2.2 / self.varispeed.playbackRate);
        } else if ( player == self.sample3 ) {
            nextIntervalTime -= AEHostTicksFromSeconds(0.4 / self.varispeed.playbackRate);
        }
        
        // Defer or bring back the interval, with some tolerance
        AEHostTicks intervalLengthTicks = AEHostTicksFromSeconds(intervalLength);
        if ( nextIntervalTime < now-AEHostTicksFromSeconds(kCountInThreshold) ) {
            nextIntervalTime += intervalLengthTicks;
        } else if ( nextIntervalTime - intervalLengthTicks > now-AEHostTicksFromSeconds(kCountInThreshold) ) {
            nextIntervalTime -= intervalLengthTicks;
        }
        
        return nextIntervalTime;
    }
    
    return 0;
}

#pragma mark - Accessors

- (void)setInputEnabled:(BOOL)inputEnabled {
    if ( inputEnabled == _inputEnabled ) return;
    
    _inputEnabled = inputEnabled;
    
    // Update audio session category
    if ( ![self setAudioSessionCategory:nil] ) {
        return;
    }
    
    // Start or stop the input module (actually a no-op on iOS)
    if ( _inputEnabled ) {
        NSError * error;
        if ( ![self.input start:&error] ) {
            NSLog(@"Couldn't start input unit: %@", error.localizedDescription);
        }
    } else {
        [self.input stop];
    }
}

- (void)setBandpassWetDry:(double)bandpassWetDry {
    _bandpassWetDry = bandpassWetDry;
    self.bandpass.wetDry = bandpassWetDry;
    self.micBandpass.centerFrequency =
        (self.bandpassCenterFrequency * bandpassWetDry) + (kMicBandpassCenterFrequency * (1.0 - bandpassWetDry));
}

- (void)setBandpassCenterFrequency:(double)bandpassCenterFrequency {
    _bandpassCenterFrequency = bandpassCenterFrequency;
    self.bandpass.centerFrequency = bandpassCenterFrequency;
    self.micBandpass.centerFrequency =
        (self.bandpassCenterFrequency * self.bandpassWetDry) + (kMicBandpassCenterFrequency * (1.0 - self.bandpassWetDry));
}

- (NSURL *)recordingPath {
    NSURL * docs = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    return [docs URLByAppendingPathComponent:@"Recording.m4a"];
}

#pragma mark - Helpers

- (void)updatePlayingThroughSpeaker {
    AVAudioSession * session = [AVAudioSession sharedInstance];
    AVAudioSessionRouteDescription *currentRoute = session.currentRoute;
    self.playingThroughSpeaker =
        [currentRoute.outputs filteredArrayUsingPredicate:
         [NSPredicate predicateWithFormat:@"portType = %@", AVAudioSessionPortBuiltInSpeaker]].count > 0;
}

- (BOOL)setAudioSessionCategory:(NSError **)error {
    NSError * e;
    AVAudioSession * session = [AVAudioSession sharedInstance];
    if ( ![session setCategory:self.inputEnabled ? AVAudioSessionCategoryPlayAndRecord : AVAudioSessionCategoryPlayback
                   withOptions:(self.inputEnabled ? AVAudioSessionCategoryOptionDefaultToSpeaker : 0)
                                | AVAudioSessionCategoryOptionMixWithOthers
                         error:&e] ) {
        NSLog(@"Couldn't set category: %@", e.localizedDescription);
        if ( error ) *error = e;
        return NO;
    }
    return YES;
}

- (void)registerObservers {
    AVAudioSession * session = [AVAudioSession sharedInstance];
    __weak AEAudioController * weakSelf = self;
    
    // Watch for route changes, so we can keep track of whether we're playing through the speaker
    self.routeChangeObserverToken =
        [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionRouteChangeNotification
            object:session queue:NULL usingBlock:^(NSNotification * _Nonnull note) {
        
        // Determine if we're playing through the speaker now
        [weakSelf updatePlayingThroughSpeaker];
    }];
    
    // Watch for audio session interruptions. Test this by setting a timer
    self.audioInterruptionObserverToken =
        [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionInterruptionNotification
            object:session queue:NULL usingBlock:^(NSNotification * _Nonnull note) {
                
        // Stop at the beginning of the interruption, resume after
        if ( [note.userInfo[AVAudioSessionInterruptionTypeKey] intValue] == AVAudioSessionInterruptionTypeBegan ) {
            [weakSelf stopAndRemoveObservers:NO];
        } else {
            NSError * error = nil;
            if ( ![weakSelf start:&error registerObservers:NO] ) {
                NSLog(@"Couldn't restart after interruption: %@", error);
            }
        }
    }];
}

- (void)unregisterObservers {
    if ( self.routeChangeObserverToken ) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.routeChangeObserverToken];
        self.routeChangeObserverToken = nil;
    }
    if( self.audioInterruptionObserverToken ) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.audioInterruptionObserverToken];
        self.audioInterruptionObserverToken = nil;
    }
}

@end
