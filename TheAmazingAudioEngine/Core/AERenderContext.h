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

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "AEBufferStack.h"


//! Renderer context flags
typedef enum {
    AERendererContextFlagNone = 0, //!< No flags
    AERendererContextFlagIsOffline = 1<<0, //!< Offline rendering (faster than realtime)
    AERendererContextFlagIsVariableRate = 1<<1, //!< Running within variable-rate renderer, like a time/pitch processor
} AERendererContextFlags;

//! Auxiliary buffer, for use with AERendererRunMultiOutput
typedef struct {
    uint64_t identifier;
    AudioBufferList * _Nonnull bufferList;
} AEAuxiliaryBuffer;

/*!
 * Render context
 *
 *  This structure is passed into the render loop block, and contains information about the
 *  current rendering environment, as well as providing access to the render's buffer stack.
 */
typedef struct {
    
    //! The output buffer list. You should write to this to produce audio.
    const AudioBufferList * _Nonnull output;
    
    //! The number of auxiliary buffers (if AERendererRunMultiOutput in use)
    int auxiliaryBufferCount;
    
    //! Array of auxiliary buffers
    const AEAuxiliaryBuffer * _Nullable auxiliaryBuffers;
    
    //! The number of frames to render to the output
    UInt32 frames;
    
    //! The current sample rate, in Hertz
    double sampleRate;
    
    //! The current audio timestamp
    const AudioTimeStamp * _Nonnull timestamp;
    
    //! The buffer stack. Use this as a workspace for generating and processing audio.
    AEBufferStack * _Nonnull stack;
    
    //! Bitmask of flags
    AERendererContextFlags flags;
    
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

/*!
 * Make a copy of the given render context on the stack, with a given offset and length
 *
 * @param name Name of the variable to create on the stack
 * @param context The original context to copy
 * @param offsetFrames Offset, in frames, for the copy (will advance all buffers of the original context)
 * @param lengthFrames Length, in frames, for the copy
 */
#define AERenderContextCopyOnStack(name, context, offsetFrames, lengthFrames) \
    AERenderContext name = *context; \
    name.frames = (UInt32)(lengthFrames); \
    const UInt32 name ## _offsetFrames = (UInt32)(offsetFrames); \
    AEBufferStackSetFrameCount(name.stack, name.frames); \
    AEAudioBufferListCopyOnStack(name ## _output, context->output, name ## _offsetFrames); \
    AEAudioBufferListSetLength(name ## _output, name.frames); \
    name.output = name ## _output; \
    AudioTimeStamp name ## _timestamp = *context->timestamp; \
    name ## _timestamp.mSampleTime += offsetFrames; \
    name ## _timestamp.mHostTime += AEHostTicksFromSeconds(offsetFrames / context->sampleRate); \
    name.timestamp = & name ## _timestamp; \
    AEBufferStackSetTimeStamp(name.stack, & name ## _timestamp); \
    int name ## _auxiliaryBufferTotalBytes = 0; \
    for ( int i=0; i<name.auxiliaryBufferCount; i++ ) { name ## _auxiliaryBufferTotalBytes += AEAudioBufferListGetStructSize(name.auxiliaryBuffers[i].bufferList); }; \
    char * name ## _auxiliaryBufferBytes = alloca(name ## _auxiliaryBufferTotalBytes); \
    char * name ## _auxiliaryBufferPtr = name ## _auxiliaryBufferBytes; \
    AEAuxiliaryBuffer * name ## _auxiliaryBuffers = alloca(name.auxiliaryBufferCount * sizeof(AEAuxiliaryBuffer)); \
    name.auxiliaryBuffers = name.auxiliaryBufferCount > 0 ? name ## _auxiliaryBuffers : NULL; \
    for ( int i=0; i<name.auxiliaryBufferCount; i++ ) { \
        name ## _auxiliaryBuffers[i].identifier = context->auxiliaryBuffers[i].identifier; \
        name ## _auxiliaryBuffers[i].bufferList = (AudioBufferList *)name ## _auxiliaryBufferPtr; \
        AEAudioBufferListAssign(name.auxiliaryBuffers[i].bufferList, context->auxiliaryBuffers[i].bufferList, name ## _offsetFrames, name.frames); \
        name ## _auxiliaryBufferPtr += AEAudioBufferListGetStructSize(context->auxiliaryBuffers[i].bufferList); \
    }

#ifdef __cplusplus
}
#endif
