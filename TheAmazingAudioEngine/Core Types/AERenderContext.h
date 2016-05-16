//
//  AERenderContext.h
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 29/04/2016.
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

@import Foundation;
@import AudioToolbox;
#import "AEBufferStack.h"

/*!
 * Render context
 *
 *  This structure is passed into the render loop block, and contains information about the
 *  current rendering environment, as well as providing access to the render's buffer stack.
 */
typedef struct {
    
    //! The output buffer list. You should write to this to produce audio.
    const AudioBufferList * _Nonnull output;
    
    //! The number of frames to render to the output
    UInt32 frames;
    
    //! The current sample rate, in Hertz
    double sampleRate;
    
    //! The current audio timestamp
    const AudioTimeStamp * _Nonnull timestamp;
    
    //! Whether rendering is offline (faster than realtime)
    BOOL offlineRendering;
    
    //! The buffer stack. Use this as a workspace for generating and processing audio.
    AEBufferStack * _Nonnull stack;
    
} AERenderContext;

/*!
 * Mix stack items onto the output
 *
 *  The given number of stack items will mixed into the context's output.
 *  This method is a convenience wrapper for AEBufferStackMixToBufferList.
 *
 * @param context The context
 * @param bufferCount Number of buffers on the stack to process, or 0 for all
 */
void AERenderContextOutput(const AERenderContext * _Nonnull context, int bufferCount);

/*!
 * Mix stack items onto the output, with specific channel configuration
 *
 *  The given number of stack items will mixed into the context's output.
 *  This method is a convenience wrapper for AEBufferStackMixToBufferListChannels.
 *
 * @param context The context
 * @param bufferCount Number of buffers on the stack to process, or 0 for all
 * @param channels The set of channels to output to. If stereo, any mono inputs will be doubled to stereo.
 *      If mono, any stereo inputs will be mixed down.
 */
void AERenderContextOutputToChannels(const AERenderContext * _Nonnull context, int bufferCount, AEChannelSet channels);

#ifdef __cplusplus
}
#endif
