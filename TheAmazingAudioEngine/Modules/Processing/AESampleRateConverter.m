#import "AESampleRateConverterModule.h"

@implementation AESampleRateConverterModule

- (instancetype)initWithRenderer:(AERenderer *)renderer subrenderer:(AERenderer *)subrenderer {
  AudioComponentDescription description = {kAudioUnitType_FormatConverter,
                                           kAudioUnitSubType_AUConverter,
                                           kAudioUnitManufacturer_Apple, 0, 0};
  // Superclass smashes subrenderer sample rate. Save it.
  double subrendererSampleRate = subrenderer.sampleRate;
  self = [super initWithRenderer:renderer componentDescription:description subrenderer:subrenderer];
  if (self) {
    // Restore subrenderer sample rate.
    subrenderer.sampleRate = subrendererSampleRate;
    [self rendererDidChangeSampleRate];
  }
  return self;
}

- (void)rendererDidChangeSampleRate {
  // Update the sample rate
  AECheckOSStatus(AudioUnitUninitialize(self.audioUnit), "AudioUnitUninitialize");
  AudioStreamBasicDescription outputAudioDescription = AEAudioDescription;
  outputAudioDescription.mSampleRate = self.renderer.sampleRate;
  AECheckOSStatus(
      AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output,
                           0, &outputAudioDescription, sizeof(outputAudioDescription)),
      "AudioUnitSetProperty(kAudioUnitProperty_StreamFormat)");

  if (self.hasInput) {
    AudioStreamBasicDescription inputAudioDescription = outputAudioDescription;
    if (self.subrenderer) {
      inputAudioDescription.mSampleRate = self.subrenderer.sampleRate;
      inputAudioDescription.mChannelsPerFrame = self.subrenderer.numberOfOutputChannels;
    }
    AECheckOSStatus(
        AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,
                             0, &inputAudioDescription, sizeof(inputAudioDescription)),
        "AudioUnitSetProperty(kAudioUnitProperty_StreamFormat)");
  }
  [self initialize];
}

@end
