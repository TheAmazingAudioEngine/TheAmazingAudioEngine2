//
//  AERenderer.h
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

@import Foundation;
@import AudioToolbox;
#import "AERenderContext.h"

#ifdef __cplusplus
extern "C" {
#endif

/*!
 * Render loop block
 *
 *  Use the render loop block to provide top-level audio processing.
 *
 *  Generate and process audio by interacting with the buffer stack, generally through the use of
 *  AEModule objects, which can perform a mix of pushing new buffers onto the stack, manipulating
 *  existing buffers, and popping buffers off the stack.
 *
 *  At the end of the render block, use @link AERenderContextOutput @endlink to output buffers on the
 *  stack to the context's output bufferList.
 *
 * @param context The rendering context
 */
typedef void (^AERenderLoopBlock)(const AERenderContext * _Nonnull context);
    
/*!
 * Sample rate change notification
 */
extern NSString * const _Nonnull AERendererDidChangeSampleRateNotification;

/*!
 * Channel count change notification
 */
extern NSString * const _Nonnull AERendererDidChangeNumberOfOutputChannelsNotification;


/*!
 * Base renderer class
 *
 *  A renderer is responsible for driving the main processing loop, which is the central point
 *  for audio generation and processing. A sub-renderer may also be used, which can drive an
 *  intermediate render loop, such as for a variable-speed module.
 *
 *  Renderers can provide an interface with the system audio output, or offline rendering to
 *  file, offline analysis, conversion, etc.
 *
 *  Use this class by allocating an instance, then assigning a block to the 'block' property,
 *  which will be invoked during audio generation, usually on the audio render thread. You may
 *  assign new blocks to this property at any time, and assignment will be thread-safe. 
 */
@interface AERenderer : NSObject

/*!
 * Perform one pass of the render loop
 *
 * @param renderer The renderer instance
 * @param bufferList An AudioBufferList to write audio to. If mData pointers are NULL, will set these
 *      to the top buffer's mData pointers instead.
 * @param frames The number of frames to process
 * @param timestamp The timestamp of the current period
 */
void AERendererRun(__unsafe_unretained AERenderer * _Nonnull renderer,
                   const AudioBufferList * _Nonnull bufferList,
                   UInt32 frames,
                   const AudioTimeStamp * _Nonnull timestamp);

@property (nonatomic, copy) AERenderLoopBlock _Nonnull block; //!< The output loop block. Assignment is thread-safe.
@property (nonatomic) double sampleRate; //!< The sample rate
@property (nonatomic) int numberOfOutputChannels; //!< The number of output channels
@property (nonatomic) BOOL isOffline; //!< Whether rendering is offline (faster than realtime), default NO
@property (nonatomic, readonly) AEBufferStack * _Nonnull stack; //!< Buffer stack
@end

#ifdef __cplusplus
}
#endif
