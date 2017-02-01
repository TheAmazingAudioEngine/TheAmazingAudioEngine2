//
//  AEAudiobusInputModule.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 11/10/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import "AEAudiobusInputModule.h"
#import "Audiobus.h"

@interface AEAudiobusInputModule ()
@property (nonatomic, strong, readwrite) ABAudioReceiverPort * audioReceiverPort;
@property (nonatomic, strong, readwrite) AEAudioUnitInputModule * audioUnitInputModule;
@property (nonatomic) BOOL inputIsFromIAA;
@end

@implementation AEAudiobusInputModule

- (instancetype)initWithRenderer:(AERenderer *)renderer
               audioReceiverPort:(ABAudioReceiverPort *)port
            audioUnitInputModule:(AEAudioUnitInputModule *)input {
    if ( !(self = [super initWithRenderer:renderer]) ) return nil;
    
    _audiobusEnabled = YES;
    self.audioReceiverPort = port;
    self.audioUnitInputModule = input;
    self.audioReceiverPort.clientFormat = AEAudioDescriptionWithChannelsAndRate(2, renderer.sampleRate);
    self.processFunction = AEAudiobusInputModuleProcess;
    
    // Register a callback to watch for IAA connection changes
    AECheckOSStatus(AudioUnitAddPropertyListener(input.audioUnit, kAudioUnitProperty_IsInterAppConnected,
                                                 AEAudiobusInputModuleIAAConnectionChanged, (__bridge void*)self),
                    "AudioUnitAddPropertyListener(kAudioUnitProperty_IsInterAppConnected)");
    
    return self;
}

- (void)dealloc {
    // Remove IAA connection change callback
    if ( self.audioUnitInputModule ) {
        AECheckOSStatus(AudioUnitRemovePropertyListenerWithUserData(
            self.audioUnitInputModule.audioUnit, kAudioUnitProperty_IsInterAppConnected,
            AEAudiobusInputModuleIAAConnectionChanged, (__bridge void*)self), "AudioUnitRemovePropertyListenerWithUserData");
    }
}

- (void)rendererDidChangeSampleRate {
    self.audioReceiverPort.clientFormat = AEAudioDescriptionWithChannelsAndRate(2, self.renderer.sampleRate);
}

static void AEAudiobusInputModuleIAAConnectionChanged(void *inRefCon, AudioUnit inUnit, AudioUnitPropertyID inID,
                                             AudioUnitScope inScope, AudioUnitElement inElement) {
    AEAudiobusInputModule * self = (__bridge AEAudiobusInputModule *)inRefCon;

    UInt32 iaaConnected = NO;
    UInt32 size = sizeof(iaaConnected);
    if ( AECheckOSStatus(AudioUnitGetProperty(self.audioUnitInputModule.audioUnit, kAudioUnitProperty_IsInterAppConnected,
                                              kAudioUnitScope_Global, 0, &iaaConnected, &size),
                         "AudioUnitGetProperty(kAudioUnitProperty_IsInterAppConnected)") && iaaConnected ) {
        AudioComponentDescription componentDescription;
        size = sizeof(componentDescription);
        if ( AECheckOSStatus(AudioUnitGetProperty(self.audioUnitInputModule.audioUnit, kAudioOutputUnitProperty_NodeComponentDescription,
                                                  kAudioUnitScope_Global, 0, &componentDescription, &size),
                             "AudioUnitGetProperty(kAudioOutputUnitProperty_NodeComponentDescription)") ) {
            self.inputIsFromIAA = componentDescription.componentType == kAudioUnitType_RemoteEffect
                || componentDescription.componentType == kAudioUnitType_RemoteMusicEffect;
            return;
        }
    }
    
    self.inputIsFromIAA = NO;
}

static void AEAudiobusInputModuleProcess(__unsafe_unretained AEAudiobusInputModule * THIS, const AERenderContext * context) {
    
    if ( ABAudioReceiverPortIsConnected(THIS->_audioReceiverPort) ) {
        // Pull input from Audiobus
        const AudioBufferList * abl = AEBufferStackPushWithChannels(context->stack, 1, 2);
        AudioTimeStamp * timestamp = AEBufferStackGetTimeStampForBuffer(context->stack, 0);
        ABAudioReceiverPortReceive(THIS->_audioReceiverPort, nil, (AudioBufferList *)abl, context->frames, timestamp);
        
        if ( !THIS->_audiobusEnabled ) {
            // Silence
            AEBufferStackSilence(context->stack);
            return;
        }
        
    } else if ( THIS->_audioUnitInputModule ) {
        // Pull input from our input audio unit
        AEModuleProcess(THIS->_audioUnitInputModule, context);
        
        if ( THIS->_inputIsFromIAA && !THIS->_audiobusEnabled ) {
            // Silence
            AEBufferStackSilence(context->stack);
            return;
        }
    } else {
        // Generate silence
        AEBufferStackPushWithChannels(context->stack, 1, 2);
        AEBufferStackSilence(context->stack);
    }
}

@end
