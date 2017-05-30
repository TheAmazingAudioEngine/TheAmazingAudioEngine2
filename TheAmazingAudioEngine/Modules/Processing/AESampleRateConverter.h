#import <TheAmazingAudioEngine/TheAmazingAudioEngine.h>

/**
 * A processing module that converts the sample rate and number of channels. In this module the
 * subrenderer sample rate and number of channels is decoupled from the renderer sample rate and
 * number of channels.
 */
@interface AESampleRateConverterModule : AEAudioUnitModule

- (instancetype _Nullable)initWithRenderer:(AERenderer* _Nullable)renderer
                               subrenderer:(AERenderer* _Nonnull)subrenderer;

@end
