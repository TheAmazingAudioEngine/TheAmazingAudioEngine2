//
//  AEAudioDevice.m
//  TheAmazingAudioEngine macOS
//
//  Created by Michael Tyson on 28/7/2022.
//  Copyright © 2022 A Tasty Pixel. All rights reserved.
//

#import "AEAudioDevice.h"
#import "AEUtilities.h"
#import <AVFoundation/AVFoundation.h>

NSString * const AEAudioDeviceDefaultInputDeviceChangedNotification = @"AEAudioDeviceDefaultInputDeviceChangedNotification";
NSString * const AEAudioDeviceDefaultOutputDeviceChangedNotification = @"AEAudioDeviceDefaultOutputDeviceChangedNotification";
NSString * const AEAudioDeviceAvailableDevicesChangedNotification = @"AEAudioDeviceAvailableDevicesChangedNotification";

@interface AEAudioDevice ()
@property (nonatomic, readwrite) BOOL isDefault;
@property (nonatomic, readwrite) AudioObjectID objectID;
@property (nonatomic, strong, readwrite) NSString * UID;
@property (nonatomic, strong, readwrite) NSString * name;
@property (nonatomic, readwrite) AudioStreamBasicDescription inputStreamFormat;
@property (nonatomic, readwrite) AudioStreamBasicDescription outputStreamFormat;
@end

@implementation AEAudioDevice

+ (void)initialize {
    AudioObjectAddPropertyListener(kAudioObjectSystemObject, &(AudioObjectPropertyAddress){kAudioHardwarePropertyDefaultInputDevice, kAudioObjectPropertyScopeGlobal}, AEAudioDeviceDefaultInputChanged, NULL);
    AudioObjectAddPropertyListener(kAudioObjectSystemObject, &(AudioObjectPropertyAddress){kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal}, AEAudioDeviceDefaultOutputChanged, NULL);
    AudioObjectAddPropertyListener(kAudioObjectSystemObject, &(AudioObjectPropertyAddress){kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal}, AEAudioDeviceAvailableDevicesChanged, NULL);
}

+ (NSArray<AEAudioDevice *> *)availableAudioDevices {
    AudioObjectPropertyAddress deviceListAddr = {kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal};
    UInt32 deviceListSize = 0;
    if ( !AECheckOSStatus(AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &deviceListAddr, 0, NULL, &deviceListSize), "kAudioHardwarePropertyDevices") ) {
        return nil;
    }

    UInt32 deviceCount = deviceListSize / sizeof(AudioDeviceID);
    AudioObjectID * deviceIDs = (AudioObjectID*)malloc(deviceListSize);
    if ( !deviceIDs ) {
        return nil;
    }
    
    if ( !AECheckOSStatus(AudioObjectGetPropertyData(kAudioObjectSystemObject, &deviceListAddr, 0, NULL, &deviceListSize, deviceIDs), "kAudioHardwarePropertyDevices") ) {
        free(deviceIDs);
        return nil;
    }
    
    NSMutableArray <AEAudioDevice *> * devices = [NSMutableArray new];
    for ( UInt32 i=0; i<deviceCount; i++ ) {
        [devices addObject:[[AEAudioDevice alloc] initWithObjectID:deviceIDs[i]]];
    }
    
    free(deviceIDs);
    return devices;
}

+ (AEAudioDevice *)defaultInputAudioDevice {
    AudioDeviceID deviceId;
    UInt32 size = sizeof(deviceId);
    AudioObjectPropertyAddress addr = {kAudioHardwarePropertyDefaultInputDevice, kAudioObjectPropertyScopeGlobal};
    if ( !AECheckOSStatus(AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, &deviceId), "kAudioHardwarePropertyDefaultInputDevice") || deviceId == kAudioObjectUnknown ) {
        return nil;
    }
    AEAudioDevice * device = [[AEAudioDevice alloc] initWithObjectID:deviceId];
    device.isDefault = YES;
    return device;
}

+ (AEAudioDevice *)defaultOutputAudioDevice {
    AudioDeviceID deviceId;
    UInt32 size = sizeof(deviceId);
    AudioObjectPropertyAddress addr = {kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal};
    if ( !AECheckOSStatus(AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, &deviceId), "kAudioHardwarePropertyDefaultOutputDevice") || deviceId == kAudioObjectUnknown ) {
        return nil;
    }
    AEAudioDevice * device = [[AEAudioDevice alloc] initWithObjectID:deviceId];
    device.isDefault = YES;
    return device;
}

+ (AEAudioDevice *)audioDeviceWithUID:(NSString *)UID {
    AudioDeviceID deviceId;
    UInt32 size = sizeof(deviceId);
    CFStringRef UIDStr = (__bridge CFStringRef)UID;
    AudioObjectPropertyAddress addr = {kAudioHardwarePropertyTranslateUIDToDevice, kAudioObjectPropertyScopeGlobal};
    if ( !AECheckOSStatus(AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, sizeof(UIDStr), &UIDStr, &size, &deviceId), "kAudioHardwarePropertyTranslateUIDToDevice") || deviceId == kAudioObjectUnknown ) {
        return nil;
    }
    return [[AEAudioDevice alloc] initWithObjectID:deviceId];
}

- (instancetype)initWithObjectID:(AudioObjectID)objectID {
    if ( !(self = [super init]) ) return nil;
    self.objectID = objectID;
    return self;
}

- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:[self class]] && [((AEAudioDevice *)object).UID isEqualToString:self.UID];
}

- (NSUInteger)hash {
    return ((NSUInteger)7079)*self.UID.hash;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %@ (%@) %d in, %d out>", NSStringFromClass([self class]), self.name, self.UID, self.inputStreamFormat.mChannelsPerFrame, self.outputStreamFormat.mChannelsPerFrame];
}

- (NSString *)UID {
    if ( _UID ) return _UID;
    CFStringRef value;
    UInt32 size = sizeof(value);
    AudioObjectPropertyAddress addr = {kAudioDevicePropertyDeviceUID, kAudioObjectPropertyScopeGlobal};
    if ( !AECheckOSStatus(AudioObjectGetPropertyData(_objectID, &addr, 0, NULL, &size, &value), "kAudioDevicePropertyDeviceUID") ) {
        return nil;
    }
    return _UID = (__bridge_transfer NSString *)value;
}

- (NSString *)name {
    if ( _name ) return _name;
    CFStringRef value;
    UInt32 size = sizeof(value);
    AudioObjectPropertyAddress addr = {kAudioDevicePropertyDeviceNameCFString, kAudioObjectPropertyScopeGlobal};
    if ( !AECheckOSStatus(AudioObjectGetPropertyData(_objectID, &addr, 0, NULL, &size, &value), "kAudioDevicePropertyDeviceName") ) {
        return nil;
    }
    return _name = (__bridge_transfer NSString *)value;
}

- (BOOL)hasInput {
    UInt32 size;
    AudioObjectPropertyAddress addr = {kAudioDevicePropertyStreams, kAudioDevicePropertyScopeInput};
    if ( !AECheckOSStatus(AudioObjectGetPropertyDataSize(_objectID, &addr, 0, NULL, &size), "kAudioDevicePropertyStreams") ) return 0;
    return size > 0;
}

- (BOOL)hasOutput {
    UInt32 size;
    AudioObjectPropertyAddress addr = {kAudioDevicePropertyStreams, kAudioDevicePropertyScopeOutput};
    if ( !AECheckOSStatus(AudioObjectGetPropertyDataSize(_objectID, &addr, 0, NULL, &size), "kAudioDevicePropertyStreams") ) return 0;
    return size > 0;
}

- (AudioStreamBasicDescription)inputStreamFormat {
    if ( _inputStreamFormat.mChannelsPerFrame ) return _inputStreamFormat;
    return _inputStreamFormat = [self streamFormatForScope:kAudioDevicePropertyScopeInput];
}

- (AudioStreamBasicDescription)outputStreamFormat {
    if ( _outputStreamFormat.mChannelsPerFrame ) return _outputStreamFormat;
    return _outputStreamFormat = [self streamFormatForScope:kAudioDevicePropertyScopeOutput];
}

- (AudioStreamBasicDescription)streamFormatForScope:(AudioObjectPropertyScope)scope {
    AudioStreamBasicDescription asbd;
    UInt32 size = sizeof(asbd);
    AudioObjectPropertyAddress addr = { kAudioDevicePropertyStreamFormat, scope, 0 };
    if ( !AECheckOSStatus(AudioObjectGetPropertyData(_objectID, &addr, 0, NULL, &size, &asbd),  "kAudioDevicePropertyStreamFormat") ) {
        return (AudioStreamBasicDescription){};
    }
    return asbd;
}

- (UInt32)inputBufferDuration {
    UInt32 duration;
    UInt32 size = sizeof(duration);
    AudioObjectPropertyAddress addr = {kAudioDevicePropertyBufferFrameSize, kAudioDevicePropertyScopeInput};
    if ( !AECheckOSStatus(AudioObjectGetPropertyData(_objectID, &addr, 0, NULL, &size, &duration), "kAudioDevicePropertyBufferFrameSize") ) return 0;
    return duration;
}

- (void)setInputBufferDuration:(UInt32)duration {
    AudioObjectPropertyAddress addr = {kAudioDevicePropertyBufferFrameSize, kAudioDevicePropertyScopeInput};
    AECheckOSStatus(AudioObjectSetPropertyData(_objectID, &addr, 0, NULL, sizeof(duration), &duration), "kAudioDevicePropertyBufferFrameSize");
}

- (UInt32)outputBufferDuration {
    UInt32 duration;
    UInt32 size = sizeof(duration);
    AudioObjectPropertyAddress addr = {kAudioDevicePropertyBufferFrameSize, kAudioDevicePropertyScopeOutput};
    if ( !AECheckOSStatus(AudioObjectGetPropertyData(_objectID, &addr, 0, NULL, &size, &duration), "kAudioDevicePropertyBufferFrameSize") ) return 0;
    return duration;
}

- (void)setOutputBufferDuration:(UInt32)duration {
    AudioObjectPropertyAddress addr = {kAudioDevicePropertyBufferFrameSize, kAudioDevicePropertyScopeOutput};
    AECheckOSStatus(AudioObjectSetPropertyData(_objectID, &addr, 0, NULL, sizeof(duration), &duration), "kAudioDevicePropertyBufferFrameSize");
}

- (double)closestSupportedSampleRateTo:(double)sampleRate {
    double closest = 0;
    double closestDiff = INFINITY;
    for ( NSValue * value in self.supportedSampleRates ) {
        AudioValueRange range;
        [value getValue:&range size:sizeof(range)];
        if ( range.mMinimum <= sampleRate && range.mMaximum >= sampleRate ) {
            // Exact match
            return sampleRate;
        }
        
        double diff;
        if ( (diff=fabs(range.mMinimum-sampleRate)) < closestDiff ) {
            closest = range.mMinimum;
            closestDiff = diff;
        }
        if ( (diff=fabs(range.mMaximum-sampleRate)) < closestDiff ) {
            closest = range.mMaximum;
            closestDiff = diff;
        }
    }
    return closest;
}

- (NSArray<NSValue *> *)supportedSampleRates {
    AudioObjectPropertyAddress addr = {kAudioDevicePropertyAvailableNominalSampleRates, kAudioObjectPropertyScopeGlobal};
    UInt32 listSize = 0;
    if ( !AECheckOSStatus(AudioObjectGetPropertyDataSize(_objectID, &addr, 0, NULL, &listSize), "kAudioDevicePropertyAvailableNominalSampleRates") ) {
        return nil;
    }
    
    UInt32 entryCount = listSize / sizeof(AudioValueRange);
    AudioValueRange * list = (AudioValueRange*)malloc(listSize);
    if ( !list ) {
        return nil;
    }
    
    if ( !AECheckOSStatus(AudioObjectGetPropertyData(_objectID, &addr, 0, NULL, &listSize, list), "kAudioDevicePropertyAvailableNominalSampleRates") ) {
        free(list);
        return nil;
    }
    
    NSMutableArray <NSValue *> * ranges = [NSMutableArray new];
    for ( UInt32 i=0; i<entryCount; i++ ) {
        [ranges addObject:[NSValue value:&list[i] withObjCType:@encode(AudioValueRange)]];
    }
    
    free(list);
    return ranges;
}

- (double)sampleRate {
    Float64 rate;
    UInt32 size = sizeof(rate);
    AudioObjectPropertyAddress addr = {kAudioDevicePropertyNominalSampleRate, kAudioObjectPropertyScopeGlobal};
    if ( !AECheckOSStatus(AudioObjectGetPropertyData(_objectID, &addr, 0, NULL, &size, &rate), "kAudioDevicePropertyNominalSampleRate") ) return 0;
    return rate;
}

- (void)setSampleRate:(double)sampleRate {
    AudioObjectPropertyAddress addr = {kAudioDevicePropertyNominalSampleRate, kAudioObjectPropertyScopeGlobal};
    Float64 rate = sampleRate;
    AECheckOSStatus(AudioObjectSetPropertyData(_objectID, &addr, 0, NULL, sizeof(rate), &rate), "kAudioDevicePropertyNominalSampleRate");
}

static OSStatus AEAudioDeviceDefaultInputChanged(AudioObjectID inObjectID, UInt32 inNumberAddresses, const AudioObjectPropertyAddress *inAddresses, void *inClientData) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:AEAudioDeviceDefaultInputDeviceChangedNotification object:nil];
    });
    return noErr;
}

static OSStatus AEAudioDeviceDefaultOutputChanged(AudioObjectID inObjectID, UInt32 inNumberAddresses, const AudioObjectPropertyAddress *inAddresses, void *inClientData) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:AEAudioDeviceDefaultOutputDeviceChangedNotification object:nil];
    });
    return noErr;
}

static OSStatus AEAudioDeviceAvailableDevicesChanged(AudioObjectID inObjectID, UInt32 inNumberAddresses, const AudioObjectPropertyAddress *inAddresses, void *inClientData) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:AEAudioDeviceAvailableDevicesChangedNotification object:nil];
    });
    return noErr;
}

@end
