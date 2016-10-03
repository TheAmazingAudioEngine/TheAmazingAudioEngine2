//
//  AEAudioFilePlayerModule.m
//  The Amazing Audio Engine
//
//  Created by Michael Tyson on 30/03/2016.
//
//  Contributions by Ryan King and Jeremy Huff of Hello World Engineering, Inc on 7/15/15.
//      Copyright (c) 2015 Hello World Engineering, Inc. All rights reserved.
//  Contributions by Ryan Holmes
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

#ifdef __cplusplus
extern "C" {
#endif

#import "AEAudioUnitModule.h"
#import "AETime.h"

//! Completion/begin block
typedef void (^AEAudioFilePlayerModuleBlock)();

/*!
 * Audio file player module
 *
 *  This class allows you to play audio files, either as one-off samples, or looped.
 *  It will play any audio file format supported by iOS.
 *
 *  When processing, it will push a buffer onto the stack containing audio from the
 *  playing file, or silence if not playing. The number of channels in the pushed buffer
 *  matches the channels from the audio file.
 */
@interface AEAudioFilePlayerModule : AEAudioUnitModule

/*!
 * Default initialiser
 *
 * @param renderer The renderer
 * @param url URL to the file to load
 * @param error If not NULL, the error on output
 */
- (instancetype _Nullable)initWithRenderer:(AERenderer * _Nullable)renderer
                                       URL:(NSURL * _Nonnull)url
                                     error:(NSError * _Nullable * _Nullable)error;

/*!
 * Begin playback
 *
 *  This causes the player to emit silence up until the given timestamp
 *  is reached. Use this method to synchronize playback with other audio
 *  generators.
 *
 *  If you pass AETimeStampNone as the time, the module will immediately 
 *  begin outputting audio.
 *
 * @param time The timestamp at which to begin playback
 */
- (void)playAtTime:(AudioTimeStamp)time;

/*!
 * Begin playback
 *
 *  Begins playback at the given time; this version allows you to provide a 
 *  block which will be called on the main thread shortly after playback starts.
 *
 * @param time The timestamp at which to begin playback
 * @param block Block to call on main thread when the time is reached and playback starts
 */
- (void)playAtTime:(AudioTimeStamp)time beginBlock:(AEAudioFilePlayerModuleBlock _Nullable)block;

/*!
 * Stop playback
 */
- (void)stop;

/*!
 * Get playhead position, in frames, for a given time
 *
 *  For use on the realtime thread.
 *
 * @param filePlayer The player
 * @param time Time to look up playhead position for
 * @return Current playhead position, in seconds, relative to the start of the file
 */
AESeconds AEAudioFilePlayerModuleGetPlayhead(__unsafe_unretained AEAudioFilePlayerModule * _Nonnull filePlayer,
                                             AEHostTicks time);

/*!
 * Determine if playing
 *
 * @param filePlayer The player
 * @return Whether currently playing
 */
BOOL AEAudioFilePlayerModuleGetPlaying(__unsafe_unretained AEAudioFilePlayerModule * _Nonnull filePlayer);

//! Original media URL
@property (nonatomic, strong, readonly) NSURL * _Nullable url;

//! Length of audio file, in seconds
@property (nonatomic, readonly) AESeconds duration;

//! Time offset within file to begin playback
@property (nonatomic, assign) AESeconds regionStartTime;

//! Duration of playback within the file
@property (nonatomic, assign) AESeconds regionDuration;

//! Current playback position relative to the beginning of the file
@property (nonatomic, assign) AESeconds currentTime;

//! Whether playing (not KVO observable)
@property (nonatomic, readonly) BOOL playing;

//! Whether to loop this track
@property (nonatomic, readwrite) BOOL loop;

//! Number of frames to microfade at start and end (0 by default; increase to smooth out
//! discontinuities - clicks - at start and end)
@property (nonatomic) UInt32 microfadeFrames;

//! A block to be called when non-looped playback finishes
@property (nonatomic, copy) AEAudioFilePlayerModuleBlock _Nullable completionBlock;

@end
    
#ifdef __cplusplus
}
#endif