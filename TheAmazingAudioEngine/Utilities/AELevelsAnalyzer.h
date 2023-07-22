//
//  AELevelsAnalyzer.h
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 30/11/17.
//  Copyright © 2017 A Tasty Pixel. All rights reserved.
//

#ifdef __cplusplus
extern "C" {
#endif

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

/*!
 * Levels analyzer
 *
 *  Provides utility to analyze peak and average for an audio stream
 */
@interface AELevelsAnalyzer : NSObject

/*!
 * Analyze a buffer
 *
 *  If the buffer has multiple channels, will generate levels across all of them.
 *
 * @param analyzer The analyzer instance
 * @param buffer The audio buffer
 * @param numberFrames The length of the audio buffer, in frames
 */
void AELevelsAnalyzerAnalyzeBuffer(__unsafe_unretained AELevelsAnalyzer * analyzer, const AudioBufferList * buffer, UInt32 numberFrames);

/*!
 * Analyze a buffer, mixing results rather than appending
 *
 * @param analyzer The analyzer instance
 * @param buffer The audio buffer
 * @param numberFrames The length of the audio buffer, in frames
 * @param first Whether this is the first buffer of the current time interval; if NO, subsequent analyses will be mixed additively
 */
void AELevelsAnalyzerMixAndAnalyzeBuffer(__unsafe_unretained AELevelsAnalyzer * analyzer, const AudioBufferList * buffer, UInt32 numberFrames, BOOL first);

/*!
 * Mark next buffer as first of time interval, for use with `AELevelsAnalyzerMixAndAnalyzeBuffer`
 *
 *  As an alternative to passing YES for the `first` parameter of `AELevelsAnalyzerMixAndAnalyzeBuffer`, use this method mark the next call as the first for the current time interval.
 *  This will override the next `first` parameter value of the next call to `AELevelsAnalyzerMixAndAnalyzeBuffer`.
 *
 * @param analyzer The analyzer instance
 */
void AELevelsAnalyzerSetNextBufferIsFirst(__unsafe_unretained AELevelsAnalyzer * analyzer);

/*!
 * Analyze a single buffer channel
 *
 * @param analyzer The analyzer instance
 * @param buffer The audio buffer
 * @param channel The channel within the buffer
 * @param numberFrames The length of the audio buffer, in frames
 */
void AELevelsAnalyzerAnalyzeBufferChannel(__unsafe_unretained AELevelsAnalyzer * analyzer, const AudioBufferList * buffer, int channel, UInt32 numberFrames);

/*!
 * Get peak value
 *
 * @param analyzer The analyzer instance
 */
double AELevelsAnalyzerGetPeak(__unsafe_unretained AELevelsAnalyzer * analyzer);

/*!
 * Get everage value
 *
 * @param analyzer The analyzer instance
 */
double AELevelsAnalyzerGetAverage(__unsafe_unretained AELevelsAnalyzer * analyzer);

@property (nonatomic, readonly) double peak; //!< Retrieve the peak value, in decibels
@property (nonatomic, readonly) double average; //!< Retrieve the average value, in decibels
@property (nonatomic) double gain; //!< Gain to apply when analyzing

@end

/*!
 * Stereo levels analyzer
 *
 *  Encapsulates two levels analyzers, one for each channel
 */
@interface AEStereoLevelsAnalyzer : NSObject

/*!
 * Analyze a buffer
 *
 *  If the buffer is mono, will duplicate across both analyzers
 *
 * @param analyzer The analyzer instance
 * @param buffer The audio buffer
 * @param numberFrames The length of the audio buffer, in frames
 */
void AEStereoLevelsAnalyzerAnalyzeBuffer(__unsafe_unretained AEStereoLevelsAnalyzer * analyzer, const AudioBufferList * buffer, UInt32 numberFrames);

/*!
 * Analyze a buffer, mixing results rather than appending
 *
 * @param analyzer The analyzer instance
 * @param buffer The audio buffer
 * @param numberFrames The length of the audio buffer, in frames
 * @param first Whether this is the first buffer; if NO, subsequent analyses will be mixed additively
 */
void AEStereoLevelsAnalyzerMixAndAnalyzeBuffer(__unsafe_unretained AEStereoLevelsAnalyzer * analyzer, const AudioBufferList * buffer, UInt32 numberFrames, BOOL first);

/*!
 * Mark next buffer as first of time interval, for use with `AEStereoLevelsAnalyzerMixAndAnalyzeBuffer`
 *
 *  As an alternative to passing YES for the `first` parameter of `AEStereoLevelsAnalyzerMixAndAnalyzeBuffer`, use this method mark the next call as the first for the current time interval.
 *  This will override the next `first` parameter value of the next call to `AEStereoLevelsAnalyzerMixAndAnalyzeBuffer`.
 *
 * @param analyzer The analyzer instance
 */
void AEStereoLevelsAnalyzerSetNextBufferIsFirst(__unsafe_unretained AEStereoLevelsAnalyzer * analyzer);

@property (nonatomic, strong, readonly) AELevelsAnalyzer * left;
@property (nonatomic, strong, readonly) AELevelsAnalyzer * right;
@property (nonatomic) double gain; //!< Gain to apply when analyzing
@end

 
#ifdef __cplusplus
}
#endif
