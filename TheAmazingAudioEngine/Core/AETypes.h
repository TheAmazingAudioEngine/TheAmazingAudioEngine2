//
//  AETypes.h
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 23/03/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
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

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

/*!
 * The maximum number of frames per rendering block
 */
UInt32 AEGetMaxFramesPerSlice(void);

/*!
 * Set the max frames per slice
 *
 *  Only use this method prior to beginning of rendering
 */
void AESetMaxFramesPerSlice(UInt32 maxFramesPerSlice);

/*!
 * Max frames per slice change notification
 */
extern NSString * const AEDidChangeMaxFramesPerSliceNotification;

/*!
 * The audio description used throughout TAAE
 *
 *  This is 32-bit floating-point, non-interleaved stereo PCM.
 */
extern const AudioStreamBasicDescription AEAudioDescription;

/*!
 * Get the TAAE audio description at a given sample rate
 *
 * @param channels Number of channels
 * @param rate The sample rate
 * @return The audio description
 */
AudioStreamBasicDescription AEAudioDescriptionWithChannelsAndRate(int channels, double rate);

/*!
 * File types
 */
typedef enum {
    AEAudioFileTypeAIFFInt16,   //!< 16-bit signed little-endian integer AIFF
    AEAudioFileTypeAIFFInt24,   //!< 24-bit signed little-endian integer AIFF
    AEAudioFileTypeAIFFFloat32, //!< 32-bit floating point AIFF (AIFC)
    AEAudioFileTypeWAVInt16,    //!< 16-bit signed little-endian integer WAV
    AEAudioFileTypeWAVInt24,    //!< 24-bit signed little-endian integer WAV
    AEAudioFileTypeWAVFloat32,  //!< 32-bit floating-point WAV
    AEAudioFileTypeM4A,         //!< AAC in an M4A container
} AEAudioFileType;

/*!
 * Channel set
 */
typedef struct AEChannelSet {
    int firstChannel; //!< The index of the first channel of the set
    int lastChannel;  //!< The index of the last channel of the set
} AEChannelSet;
    
extern AEChannelSet AEChannelSetDefault; //!< A default, stereo channel set
extern AEChannelSet AEChannelSetNone; //!< Invalid channel set

/*!
 * Create an AEChannelSet
 *
 * @param firstChannel The first channel
 * @param lastChannel The last channel
 * @returns An initialized AEChannelSet structure
 */
static inline AEChannelSet AEChannelSetMake(int firstChannel, int lastChannel) {
    return (AEChannelSet) {firstChannel, lastChannel};
}
    
/*!
 * Determine number of channels in an AEChannelSet
 *
 * @param set The channel set
 * @return The number of channels
 */
static inline int AEChannelSetGetNumberOfChannels(AEChannelSet set) {
    return set.lastChannel - set.firstChannel + 1;
}
    
/*!
 * Compare two channel sets
 *
 * @param a First channel set
 * @param b Second channel set
 * @return YES if both match
 */
static inline BOOL AEChannelSetEqualToSet(AEChannelSet a, AEChannelSet b) {
    return a.firstChannel == b.firstChannel && a.lastChannel == b.lastChannel;
}
    
@interface NSValue (AEChannelSet)
+ (NSValue *)valueWithChannelSet:(AEChannelSet)channelSet;
- (AEChannelSet)channelSetValue;
@end

//! The realtime thread; set this to pthread_self on the render thread (AEAudioUnitOutput does this automatically)
extern pthread_t AERealtimeThreadIdentifier;

#ifdef __cplusplus
}
#endif
