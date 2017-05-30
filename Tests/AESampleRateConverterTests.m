#import <XCTest/XCTest.h>

#import "AESampleRateConverterModule.h"

@interface AESampleRateConverterTests : XCTestCase
@end

@implementation AESampleRateConverterTests

- (void)testSampleRateConverter {
  // Use stereo buffers because AEModuleProcess is currently hard-coded to use stereo buffers.
  // If we use a mono buffer, the conversion to/from stereo internal to AEModuleProcess ends up
  // doubling the amplitude of the samples.
  const AudioStreamBasicDescription inFormat = AEAudioDescriptionWithChannelsAndRate(2,44100);
  const AudioStreamBasicDescription outFormat = AEAudioDescriptionWithChannelsAndRate(2,48000);
  const UInt32 kOutFrames = 128;
  const UInt32 kInFrames =
      (UInt32) ceil((inFormat.mSampleRate / outFormat.mSampleRate) * kOutFrames);
  AudioBufferList * in = AEAudioBufferListCreateWithFormat(inFormat, kInFrames);
  AudioBufferList * out = AEAudioBufferListCreateWithFormat(outFormat, kOutFrames);

  AERenderer * renderer = [[AERenderer alloc] init];
  renderer.isOffline = YES;
  renderer.sampleRate = outFormat.mSampleRate;
  renderer.numberOfOutputChannels = outFormat.mChannelsPerFrame;
  AERenderer * subrenderer = [[AERenderer alloc] init];
  subrenderer.isOffline = YES;
  subrenderer.sampleRate = inFormat.mSampleRate;
  subrenderer.numberOfOutputChannels = inFormat.mChannelsPerFrame;

  GPMSampleRateConverterModule * converterModule =
      [[GPMSampleRateConverterModule alloc] initWithRenderer:renderer subrenderer:subrenderer];

  renderer.block = ^(const AERenderContext * context) {
    AEModuleProcess(converterModule, context);
    AERenderContextOutput(context, 1);
  };
  subrenderer.block = ^(const AERenderContext * context) {
    const AudioBufferList * abl = AEBufferStackPushWithChannels(context->stack, 1, 2);
    if ( !abl ) return;

    for ( int i=0; i<context->frames; i++ ) {
      ((float*)abl->mBuffers[0].mData)[i] = 0.0;
    }

    ((float*)abl->mBuffers[0].mData)[0] = 1.0;

    AERenderContextOutput(context, 1);
  };

  AudioTimeStamp timestamp = { .mFlags = kAudioTimeStampSampleTimeValid, .mSampleTime = 0 };

  AERendererRun(renderer, out, kOutFrames, &timestamp);

  // Todo: Inspect the output, to see if it is a resampled version of the input.

  for ( int i=0; i<kOutFrames; i++ ) {
    NSLog(@"%d %g", i, ((float*)out->mBuffers[0].mData)[i]);
  }

}

@end
