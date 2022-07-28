//
//  AEAudioDevice.h
//  TheAmazingAudioEngine macOS
//
//  Created by Michael Tyson on 28/7/2022.
//  Copyright © 2022 A Tasty Pixel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const AEAudioDeviceDefaultInputDeviceChangedNotification;
extern NSString * const AEAudioDeviceDefaultOutputDeviceChangedNotification;
extern NSString * const AEAudioDeviceAvailableDevicesChangedNotification;

@interface AEAudioDevice : NSObject
+ (NSArray <AEAudioDevice *> *)availableAudioDevices;
+ (AEAudioDevice *)defaultInputAudioDevice;
+ (AEAudioDevice *)defaultOutputAudioDevice;
+ (AEAudioDevice *)audioDeviceWithUID:(NSString *)UID;

- (double)closestSupportedSampleRateTo:(double)sampleRate;

@property (nonatomic, readonly) BOOL isDefault;
@property (nonatomic, readonly) AudioObjectID objectID;
@property (nonatomic, strong, readonly) NSString * UID;
@property (nonatomic, strong, readonly) NSString * name;
@property (nonatomic, readonly) AudioStreamBasicDescription inputStreamFormat;
@property (nonatomic, readonly) AudioStreamBasicDescription outputStreamFormat;
@property (nonatomic) UInt32 inputBufferDuration;
@property (nonatomic) UInt32 outputBufferDuration;
@property (nonatomic, strong, readonly) NSArray <NSValue *> * supportedSampleRates; //!< Array of AudioValueRange structs
@property (nonatomic) double sampleRate;
@end

NS_ASSUME_NONNULL_END
