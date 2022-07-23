//
//  AETypes.m
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

#import "AETypes.h"

NSString * const AEDidChangeMaxFramesPerSliceNotification = @"AEDidChangeMaxFramesPerSliceNotification";

UInt32 AEMaxFramesPerSlice = 4096;
UInt32 AEGetMaxFramesPerSlice(void) {
    return AEMaxFramesPerSlice;
}
void AESetMaxFramesPerSlice(UInt32 maxFramesPerSlice) {
    AEMaxFramesPerSlice = maxFramesPerSlice;
    [NSNotificationCenter.defaultCenter postNotificationName:AEDidChangeMaxFramesPerSliceNotification object:nil];
}

AudioStreamBasicDescription const AEAudioDescription = {
    .mFormatID          = kAudioFormatLinearPCM,
    .mFormatFlags       = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
    .mChannelsPerFrame  = 2,
    .mBytesPerPacket    = sizeof(float),
    .mFramesPerPacket   = 1,
    .mBytesPerFrame     = sizeof(float),
    .mBitsPerChannel    = 8 * sizeof(float),
    .mSampleRate        = 0,
};

AudioStreamBasicDescription AEAudioDescriptionWithChannelsAndRate(int channels, double rate) {
    AudioStreamBasicDescription description = AEAudioDescription;
    description.mChannelsPerFrame = channels;
    description.mSampleRate = rate;
    return description;
}

AEChannelSet AEChannelSetDefault = {0, 1};

AEChannelSet AEChannelSetNone = {-1, -1};

pthread_t AERealtimeThreadIdentifier = NULL;

@implementation NSValue (AEChannelSet)
+ (NSValue *)valueWithChannelSet:(AEChannelSet)channelSet {
    return [NSValue valueWithBytes:&channelSet objCType:@encode(AEChannelSet)];
}
- (AEChannelSet)channelSetValue {
    NSAssert(!strcmp(self.objCType, @encode(AEChannelSet)), @"Wrong type");
    AEChannelSet set;
    [self getValue:&set];
    return set;
}
@end
