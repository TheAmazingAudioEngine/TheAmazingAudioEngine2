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
 * @param analyzer The analyzer instance
 * @param buffer The audio buffer
 * @param numberFrames The length of the audio buffer, in frames
 */
void AELevelsAnalyzerAnalyzeBuffer(__unsafe_unretained AELevelsAnalyzer * analyzer,
                                   const AudioBufferList * buffer,
                                   UInt32 numberFrames);

@property (nonatomic, readonly) double peak; //!< Retrieve the peak value, in decibels
@property (nonatomic, readonly) double average; //!< Retrieve the average value, in decibels

@end
 
#ifdef __cplusplus
}
#endif
