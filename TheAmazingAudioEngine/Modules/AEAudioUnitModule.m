//
//  AEAudioUnitModule.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 25/03/2016.
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

#import "AEAudioUnitModule.h"
#import "AEUtilities.h"
#import "AETypes.h"
#import "AERenderer.h"
#import "AEAudioBufferListUtilities.h"
#import "AEManagedValue.h"
#import <AVFoundation/AVFoundation.h>

@interface AEAudioUnitModule () {
    const AERenderContext * _currentContext;
    BOOL _pushBuffer;
    int _channelCount;
    BOOL _isClean;
}
@property (nonatomic, readwrite) AudioComponentDescription componentDescription;
@property (nonatomic, readwrite) BOOL hasInput;
@property (nonatomic) AEManagedValue * subrendererValue;
#if TARGET_OS_IPHONE
@property (nonatomic, strong) id mediaResetObserverToken;
#endif
@end

@implementation AEAudioUnitModule
@dynamic subrenderer;

- (instancetype)initWithRenderer:(AERenderer *)renderer
            componentDescription:(AudioComponentDescription)audioComponentDescription {
    return [self initWithRenderer:renderer componentDescription:audioComponentDescription subrenderer:nil];
}

- (instancetype _Nullable)initWithRenderer:(AERenderer *)renderer
                      componentDescription:(AudioComponentDescription)audioComponentDescription
                               subrenderer:(AERenderer *)subrenderer {
    
    if ( !(self = [super initWithRenderer:renderer]) ) return nil;
    
    _componentDescription = audioComponentDescription;
    
    if ( _componentDescription.componentType == kAudioUnitType_FormatConverter ) {
        NSAssert(subrenderer != nil, @"You must provide a sub-renderer for format converter audio units");
    } else {
        NSAssert(subrenderer == nil, @"You cannot use a sub-renderer with non-format converter audio units");
    }
    
    if ( ![self setup] ) return nil;
    [self initialize];
    self.processFunction = AEAudioUnitModuleProcess;
    self.resetFunction = AEAudioUnitModuleReset;
    _wetDry = 1.0;
    _pushBuffer = self.audioUnitModuleShouldPushBufferOnProcess;
    _channelCount = [self numberOfChannels];
    if ( subrenderer ) {
        subrenderer.sampleRate = renderer.sampleRate;
        self.subrendererValue = [AEManagedValue new];
        self.subrendererValue.objectValue = subrenderer;
    }
    return self;
}

- (void)dealloc {
    [self teardown];
}

- (double)getParameterValueForId:(AudioUnitParameterID)parameterId {
    AudioUnitParameterValue value = 0;
    AECheckOSStatus(AudioUnitGetParameter(_audioUnit, parameterId, kAudioUnitScope_Global, 0, &value),
                    "AudioUnitGetParameter");
    return value;
}

- (void)setParameterValue:(double)value forId:(AudioUnitParameterID)parameterId {
    AECheckOSStatus(AudioUnitSetParameter(_audioUnit, parameterId, kAudioUnitScope_Global, 0, value, 0),
                    "AudioUnitSetParameter");
}

- (void)setSubrenderer:(AERenderer *)subrenderer {
    if ( !self.subrendererValue ) {
        self.subrendererValue = [AEManagedValue new];
    }
    subrenderer.sampleRate = self.renderer.sampleRate;
    self.subrendererValue.objectValue = subrenderer;
}

- (AERenderer *)subrenderer {
    return self.subrendererValue.objectValue;
}

- (BOOL)audioUnitModuleShouldPushBufferOnProcess {
    return YES;
}

- (int)numberOfChannels {
    return AEAudioDescription.mChannelsPerFrame;
}

static void AEAudioUnitModuleProcess(__unsafe_unretained AEAudioUnitModule * THIS, const AERenderContext * _Nonnull context) {
    
    const AudioBufferList * abl = NULL;
    
    if ( (THIS->_hasInput || !THIS->_pushBuffer)
            && THIS->_componentDescription.componentType != kAudioUnitType_FormatConverter ) {
        abl = AEBufferStackGet(context->stack, 0);
    } else {
        abl = AEBufferStackPush(context->stack, 1);
    }
    
    if ( !abl || (THIS->_hasInput && THIS->_wetDry < DBL_EPSILON) ) {
        if ( !THIS->_isClean ) {
            AECheckOSStatus(AudioUnitReset(THIS->_audioUnit, kAudioUnitScope_Global, 0), "AudioUnitReset");
            THIS->_isClean = YES;
        }
        return;
    }
    
    THIS->_isClean = NO;
    
    if ( THIS->_hasInput && abl->mNumberBuffers != THIS->_channelCount && !AEBufferStackGetIsExternalBuffer(context->stack, 0) ) {
        // Get a buffer with THIS->_channelCount channels
        AEBufferStackPop(context->stack, 1);
        abl = AEBufferStackPushWithChannels(context->stack, 1, THIS->_channelCount);
        if ( !abl ) {
            // Restore prior buffer and bail
            AEBufferStackPushWithChannels(context->stack, 1, 1);
            return;
        }
        for ( int i=1; i<THIS->_channelCount; i++ ) {
            memcpy(abl->mBuffers[i].mData, abl->mBuffers[0].mData, context->frames * AEAudioDescription.mBytesPerFrame);
        }
    }
    
    if ( THIS->_hasInput && THIS->_wetDry < 1.0-DBL_EPSILON ) {
        // Not 100% wet - need to mix with a pristine buffer. We'll push one to write to, and mix it down after
        abl = AEBufferStackPush(context->stack, 1);
        if ( !abl ) {
            return;
        }
    }
    
    AudioUnitRenderActionFlags flags = 0;
    THIS->_currentContext = context;
    
    AEAudioBufferListCreateOnStackWithFormat(mutableAbl, AEAudioDescriptionWithChannelsAndRate(THIS->_channelCount, 0));
    memcpy(mutableAbl, abl, MIN(AEAudioBufferListGetStructSize(mutableAbl), AEAudioBufferListGetStructSize(abl)));
    if ( mutableAbl->mNumberBuffers != THIS->_channelCount ) {
        // If channel count doesn't match, then pad it out (we'll discard the extra channels)
        int extra = THIS->_channelCount - mutableAbl->mNumberBuffers;
        const AudioBufferList * extraAbl = NULL;
        if ( extra > 0 ) {
            extraAbl = AEBufferStackPushWithChannels(context->stack, 1, extra);
        }
        mutableAbl->mNumberBuffers = THIS->_channelCount;
        for ( int i=0; i<extra; i++ ) {
            memcpy(&mutableAbl->mBuffers[abl->mNumberBuffers+i], &extraAbl->mBuffers[i], sizeof(AudioBuffer));
        }
        if ( extra > 0 ) {
            AEBufferStackPop(context->stack, 1);
        }
    }
    
    if ( !AECheckOSStatus(AudioUnitRender(THIS->_audioUnit, &flags, context->timestamp, 0, context->frames, mutableAbl),
                          "AudioUnitRender") ) {
        if ( !THIS->_hasInput ) {
            AEAudioBufferListSilence(abl, 0, context->frames);
        } else if ( THIS->_wetDry >= 1.0-DBL_EPSILON ) {
            AEBufferStackPop(context->stack, 1);
        }
        return;
    }
    
    if ( THIS->_hasInput && THIS->_wetDry < 1.0-DBL_EPSILON ) {
        // Not 100% wet - mix down with ratio
        AEBufferStackMixWithGain(context->stack, 2, (float[]){ THIS->_wetDry, 1.0-THIS->_wetDry });
    }
}

static OSStatus audioUnitRenderCallback(void                       *inRefCon,
                                        AudioUnitRenderActionFlags *ioActionFlags,
                                        const AudioTimeStamp       *inTimeStamp,
                                        UInt32                      inBusNumber,
                                        UInt32                      inNumberFrames,
                                        AudioBufferList            *ioData) {
    
    __unsafe_unretained AEAudioUnitModule * THIS = (__bridge AEAudioUnitModule*)inRefCon;
    
    if ( THIS->_componentDescription.componentType == kAudioUnitType_FormatConverter ) {
        __unsafe_unretained AERenderer * renderer = (__bridge AERenderer*)AEManagedValueGetValue(THIS->_subrendererValue);
        if ( renderer ) {
            AERendererRun(renderer, ioData, inNumberFrames, inTimeStamp);
        } else {
            AEAudioBufferListSilence(ioData, 0, inNumberFrames);
        }
    } else {
        const AERenderContext * context = THIS->_currentContext;
        const AudioBufferList * abl =
            AEBufferStackGet(context->stack, THIS->_hasInput && THIS->_wetDry < 1.0-DBL_EPSILON ? 1 : 0);
        assert(abl->mBuffers[0].mDataByteSize >= inNumberFrames * AEAudioDescription.mBytesPerFrame);
        
        for ( int i=0; i<ioData->mNumberBuffers; i++ ) {
            memcpy(ioData->mBuffers[i].mData, abl->mBuffers[MIN(abl->mNumberBuffers-1, i)].mData,
                   inNumberFrames * AEAudioDescription.mBytesPerFrame);
        }
    }
    
    return noErr;
}

static void AEAudioUnitModuleReset(__unsafe_unretained AEAudioUnitModule * THIS) {
    if ( THIS->_audioUnit ) AudioUnitReset(THIS->_audioUnit, kAudioUnitScope_Global, 0);
}

- (BOOL)setup {
    // Get an instance of the audio unit
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &_componentDescription);
    if ( !AECheckOSStatus(AudioComponentInstanceNew(inputComponent, &_audioUnit), "AudioComponentInstanceNew") ) {
        return NO;
    }
    
    // Set the maximum frames per slice to render
    AECheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global,
                                         0, &AEBufferStackMaxFramesPerSlice, sizeof(AEBufferStackMaxFramesPerSlice)),
                    "AudioUnitSetProperty(kAudioUnitProperty_MaximumFramesPerSlice)");
    
    // Set the stream format
    AudioStreamBasicDescription asbd = AEAudioDescription;
    asbd.mSampleRate = self.renderer.sampleRate;
    asbd.mChannelsPerFrame = [self numberOfChannels];
    AECheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0,
                                         &asbd, sizeof(asbd)),
                    "AudioUnitSetProperty(kAudioUnitProperty_StreamFormat)");
    
    // Determine if this unit has input
    UInt32 inputCount;
    UInt32 size = sizeof(inputCount);
    AECheckOSStatus(AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0,
                                         &inputCount, &size),
                    "AudioUnitSetProperty(kAudioUnitProperty_ElementCount)");
    self.hasInput = inputCount > 0;
    
    if ( _hasInput ) {
        
        // This audio unit has an input bus - configure it
        AECheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
                                             &asbd, sizeof(asbd)),
                        "AudioUnitSetProperty(kAudioUnitProperty_StreamFormat)");
        
        // Setup render callback
        AURenderCallbackStruct rcbs;
        rcbs.inputProc = &audioUnitRenderCallback;
        rcbs.inputProcRefCon = (__bridge void *)self;
        AECheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0,
                                             &rcbs, sizeof(rcbs)),
                        "AudioUnitSetProperty(kAudioUnitProperty_SetRenderCallback)");
    }
    
#if TARGET_OS_IPHONE
    // Watch for media reset notifications
    __weak typeof(self) weakSelf = self;
    self.mediaResetObserverToken =
    [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionMediaServicesWereResetNotification object:nil queue:nil
                                                  usingBlock:^(NSNotification *notification) {
        [weakSelf teardown];
        [weakSelf setup];
        [weakSelf initialize];
    }];
#endif
    
    return YES;
}

- (void)initialize {
    // Initialize
    AECheckOSStatus(AudioUnitInitialize(_audioUnit), "AudioUnitInitialize");
    _isClean = YES;
}

- (void)teardown {
#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] removeObserver:self.mediaResetObserverToken];
    self.mediaResetObserverToken = nil;
#endif
    AECheckOSStatus(AudioUnitUninitialize(_audioUnit), "AudioUnitUninitialize");
    AECheckOSStatus(AudioComponentInstanceDispose(_audioUnit), "AudioComponentInstanceDispose");
}

- (void)rendererDidChangeSampleRate {
    // Update the sample rate
    AECheckOSStatus(AudioUnitUninitialize(_audioUnit), "AudioUnitUninitialize");
    AudioStreamBasicDescription asbd = AEAudioDescription;
    asbd.mSampleRate = self.renderer.sampleRate;
    asbd.mChannelsPerFrame = [self numberOfChannels];
    AECheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0,
                                         &asbd, sizeof(asbd)),
                    "AudioUnitSetProperty(kAudioUnitProperty_StreamFormat)");
    
    if ( _hasInput ) {
        AECheckOSStatus(AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
                                             &asbd, sizeof(asbd)),
                        "AudioUnitSetProperty(kAudioUnitProperty_StreamFormat)");
    }
    if ( self.subrenderer ) {
        self.subrenderer.sampleRate = self.renderer.sampleRate;
    }
    [self initialize];
}

AudioUnit AEAudioUnitModuleGetAudioUnit(__unsafe_unretained AEAudioUnitModule * THIS) {
    return THIS->_audioUnit;
}

@end
