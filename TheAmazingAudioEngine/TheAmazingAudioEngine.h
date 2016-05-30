//
//  TheAmazingAudioEngine.h
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

#ifdef __cplusplus
extern "C" {
#endif

#import <TheAmazingAudioEngine/AEBufferStack.h>
#import <TheAmazingAudioEngine/AETypes.h>

#import <TheAmazingAudioEngine/AEModule.h>
#import <TheAmazingAudioEngine/AESubrendererModule.h>
#import <TheAmazingAudioEngine/AEAudioUnitModule.h>
#import <TheAmazingAudioEngine/AEAudioUnitInputModule.h>
#import <TheAmazingAudioEngine/AEAudioFilePlayerModule.h>
#import <TheAmazingAudioEngine/AEOscillatorModule.h>
#import <TheAmazingAudioEngine/AEAggregatorModule.h>
#import <TheAmazingAudioEngine/AESplitterModule.h>
#import <TheAmazingAudioEngine/AEBandpassModule.h>
#import <TheAmazingAudioEngine/AEDelayModule.h>
#import <TheAmazingAudioEngine/AEDistortionModule.h>
#import <TheAmazingAudioEngine/AEDynamicsProcessorModule.h>
#import <TheAmazingAudioEngine/AEHighPassModule.h>
#import <TheAmazingAudioEngine/AEHighShelfModule.h>
#import <TheAmazingAudioEngine/AELowPassModule.h>
#import <TheAmazingAudioEngine/AELowShelfModule.h>
#import <TheAmazingAudioEngine/AENewTimePitchModule.h>
#import <TheAmazingAudioEngine/AEParametricEqModule.h>
#import <TheAmazingAudioEngine/AEPeakLimiterModule.h>
#import <TheAmazingAudioEngine/AEVarispeedModule.h>
#import <TheAmazingAudioEngine/AEAudioFileRecorderModule.h>
#if TARGET_OS_IPHONE
#import <TheAmazingAudioEngine/AEReverbModule.h>
#endif

#import <TheAmazingAudioEngine/AERenderer.h>
#import <TheAmazingAudioEngine/AERenderContext.h>
#import <TheAmazingAudioEngine/AEAudioUnitOutput.h>
#import <TheAmazingAudioEngine/AEAudioFileOutput.h>

#import <TheAmazingAudioEngine/AEUtilities.h>
#import <TheAmazingAudioEngine/AEAudioBufferListUtilities.h>
#import <TheAmazingAudioEngine/TPCircularBuffer.h>
#import <TheAmazingAudioEngine/AECircularBuffer.h>
#import <TheAmazingAudioEngine/AEDSPUtilities.h>
#import <TheAmazingAudioEngine/AEMainThreadEndpoint.h>
#import <TheAmazingAudioEngine/AEAudioThreadEndpoint.h>
#import <TheAmazingAudioEngine/AEMessageQueue.h>
#import <TheAmazingAudioEngine/AETime.h>
#import <TheAmazingAudioEngine/AEArray.h>
#import <TheAmazingAudioEngine/AEManagedValue.h>
#import <TheAmazingAudioEngine/AEIOAudioUnit.h>
#import <TheAmazingAudioEngine/AEAudioFileReader.h>


/*!
 @mainpage
 
 The Amazing Audio Engine (or TAAE) is a framework for making audio apps.
  
 It is an infrastructure and a variety of utilities that make it easier to focus on the core
 tasks of making and working with audio, without spending time writing boilerplate code and
 reinventing the wheel. Most of the common tasks are taken care of, so you can get straight to the good stuff.
 
 TAAE 2's design philosophy leans towards the simple and modular: to provide a set of small and simple
 building blocks that you can use together, or alone.
 
 TAAE 2 is made up of:
 
 <img src="Block Diagram.png" width="570" height="272" alt="Block Diagram">
 
 <table class="definition-list">
 <tr>
    <th>@link AEBufferStack AEBufferStack @endlink</th>
    <td>The pool of buffers used for storing and manipulating audio. This is the main component you'll be working
        with, as it forms the backbone of the audio pipeline. You'll push buffers to generate audio; get existing
        buffers to apply effects, analysis and to record; mix buffers to combine multpile sources; output buffers
        to the renderer, and pop buffers when you're done with them.</td>
 </tr>
  <tr>
    <th>AERenderer</th>
    <td>The main driver of audio processing, via the @link AERenderLoopBlock AERenderLoopBlock @endlink.</td>
 </tr>
  <tr>
    <th>AEAudioUnitOutput</th>
    <td>The system output interface, for playing generated audio.</td>
 </tr>
 <tr>
    <th>AEAudioFileOutput</th>
    <td>An offline render target, for rendering out to an audio file.</td>
 </tr>
 <tr>
    <th>AEModule</th>
    <td>A unit of processing, which interact with the buffer stack to generate audio, filter it, monitor or
        analyze, etc. Modules are driven by calling AEModuleProcess(). Some important modules:
 - AEAudioFilePlayerModule: Play files.
 - AEAudioUnitInputModule: Get system input.
 - AEAudioFileRecorderModule: Record files.
 - AESubrendererModule: Drive a sub-renderer.
 - AEAggregatorModule: Drive multiple generators.
    </td>
 </tr>
 <tr>
    <th>AEManagedValue</th>
    <td>Manage a reference to an object or pointer in a thread-safe way. Use this to hold references to modules
        that can be swapped out, removed or inserted at any time, for example.</td>
 </tr>
 <tr>
    <th>AEArray</th>
    <td>Manage a list of objects or pointers in a thread-safe way. Use this to manage lists of modules that can
        be manipulated at any time, or use it to map between model objects in your app and C structures that you use
        for rendering or analysis tasks.</td>
 </tr>
  <tr>
    <th>[AEAudioBufferListUtilities](@ref AEAudioBufferListUtilities.h)</th>
    <td>Utilities for working with AudioBufferLists: create mutable copies on the stack, offset, copy, silence,
        and isolate certain channel combinations.
    </td>
 </tr>
 <tr>
    <th>[AEDSPUtilties](@ref AEDSPUtilities.h)</th>
    <td>Digital signal processing utilities: apply gain adjustments, linear and equal-power ramps, apply gain or
        volume and balance adjustments with automatic smoothing; mix buffers together, and generate oscillators.
    </td>
 </tr>
 <tr>
    <th>AEMessageQueue</th>
    <td>A powerful cross-thread synchronization facility. Use it to safely send messages back and forth between
        the main thread and the audio thread, to update state, trigger notifications from the audio thread, exchange
        data and more. The message queue is built from:
 - AEMainThreadEndpoint: A simple facility for sending messages to the main thread from the audio thread.
 - AEAudioThreadEndpoint: A simple facility for sending messages to the audio thread from the main thread.
    </td>
 </tr>
 <tr>
    <th>AECircularBuffer</th>
    <td>Circular/ring buffer implementation that works with AudioBufferList types. Use this to buffer audio to work
        in blocks of a certain size, or use it to transport audio off to a secondary thread, or from a secondary
        thread to the audio thread. Fully realtime- and thread-safe.</td>
 </tr>
 </table>
 
 Read about [the Buffer Stack](@ref The-Buffer-Stack) and audio processing next.
 
 
 
 
 
 
 
 @page The-Buffer-Stack The Buffer Stack
 
 The central component of TAAE 2 is the [buffer stack](@ref AEBufferStack), a utility that manages a pool of
 AudioBufferList structures, which in turn store audio for the current render cycle.
 
 The buffer stack is a production line. At the beginning of each render cycle, the buffer stack starts 
 empty; at the end of the render cycle, the buffer stack is reset to this empty state. In between, your 
 code will manipulate the stack to produce, manipulate, analyse, record and ultimately output audio.
 
 Think of the stack as a stacked collection of buffers, one on top of the other, with the oldest at the
 bottom, and the newest at the top. You can push buffers on top of the stack, and pop them off, and you
 can inspect any buffer within the stack:
 
 <img src="Stack.png" width="570" height="272" alt="Stack">
 
 @section The-Buffer-Stack-Operations Operations
 
 Push buffers onto the stack to generate new audio. Get existing buffers from the stack and edit them to
 apply effects, analyse, or record audio. Mix buffers on the stack to combine multiple audio sources.
 Output buffers to the current output to play their audio out loud. Pop buffers off the stack when you're
 done with them.
 
 Each buffer on the stack can be mono, stereo, or multi-channel audio, and every buffer has the same number
 of frames of audio: that is, the number of frames requested by the output for the current render cycle.
 
 <table class="definition-list">
 <tr>
    <th>AEBufferStackPush()</th>
    <td>Push one or more stereo buffers onto the stack.
        - Use AEBufferStackPushWithChannels() to push a buffer with the given number of channels.
        - Use AEBufferStackPushExternal() to push your own pre-allocated buffer onto the stack.
        - Use AEBufferStackDuplicate() to push a copy of the top stack item.
    </td>
 </tr>
 <tr>
    <th>AEBufferStackPop()</th>
    <td>Remove one or more buffers from the top of the stack.
        - Use AEBufferStackRemove() to remove a buffer from the middle of the stack.
    </td>
 </tr>
 <tr>
    <th>AEBufferStackMix()</th>
    <td>Push a buffer that consists of the mixed audio from the top two or more buffers, and pop the original buffers.
        - Use AEBufferStackMixWithGain() to use individual mix factors for each buffer.
        - Use AEBufferStackMixToBufferList() to mix two or more buffers to a target audio buffer list.
        - Use AEBufferStackMixToBufferListChannels() to mix two or more buffers to a subset of the target buffer 
          list's channels.
    </td>
 </tr>
 <tr>
    <th>AEBufferStackApplyFaders()</th>
    <td>Apply volume and balance controls to the top buffer.</td>
 </tr>
 <tr>
    <th>AEBufferStackSilence()</th>
    <td>Fill the top buffer with silence (zero samples).</td>
 </tr>
 <tr>
    <th>AEBufferStackSwap()</th>
    <td>Swap the top two stack items.</td>
 </tr>
 </table>
 
 When you're ready to output a stack item, use AERenderContextOutput() to send the buffer to the output;
 it will be mixed with whatever's already on the output. Then optionally use AEBufferStackPop() to throw
 the buffer away.
 
 Most interaction with the stack is done through [modules](@ref AEModule), individual units of processing
 which can do anything from processing audio (i.e. pushing new buffers on the stack), adding effects
 (getting stack items and modifying the audio within), analysing or recording audio (getting stack items
 and doing something with the contents), or mixing audio together (popping stack items off, and pushing
 new buffers). You create modules on the main thread when initialising your audio engine, or when changing
 state, and then process them from within your [render loop](@ref AERenderLoopBlock) using
 AEModuleProcess().
 The modules, in turn, interact with the stack; pushing, getting and popping buffers.
 
 @section The-Buffer-Stack-Example An Example
 
 The following example takes three audio files, mixes and applies effects (we apply one effect to one player, and
 a second effect to the other two), then records and outputs the result.
 This perfoms the equivalent of the following graph:
 
 <img src="Graph Equivalent.png" width="570" height="192" alt="Graph Equivalent">
 
 First, some setup. We'll create an instance of AERenderer, which will drive our main render loop. Then
 we create an instance of AEAudioUnitOutput, which is our interface to the system audio output. Finally,
 we'll create a number of modules that we shall use. Note that each module maintains a reference to its
 controlling renderer, so it can track important changes such as sample rate.
 
 @code
 // Create our renderer and output
 AERenderer * renderer = [AERenderer new];
 self.output = [[AEAudioUnitOutput alloc] initWithRenderer:renderer];
 
 // Create the players
 AEAudioFilePlayerModule * file1 = [[AEAudioFilePlayerModule alloc] initWithRenderer:renderer URL:url1 error:NULL];
 AEAudioFilePlayerModule * file2 = [[AEAudioFilePlayerModule alloc] initWithRenderer:renderer URL:url2 error:NULL];
 AEAudioFilePlayerModule * file3 = [[AEAudioFilePlayerModule alloc] initWithRenderer:renderer URL:url3 error:NULL];
 
 // Create the filters
 AEBandpassModule * filter1 = [[AEBandpassModule alloc] initWithRenderer:renderer];
 AEBandpassModule * filter2 = [[AEDelayModule alloc] initWithRenderer:renderer];
 
 // Create the recorder
 AEAudioFileRecorderModule * recorder = [[AEAudioFileRecorderModule alloc] initWithRenderer:renderer URL:outputUrl error:NULL];
 @endcode
 
 Now, we can provide a render block, which contains the implementation for the audio pipeline. We run each module
 in turn, in the order that will provide the desired result:
 
 <img src="Rendering Example.png" width="570" height="251" alt="Rendering Example">
 
 @code
 renderer.block = ^(const AERenderContext * _Nonnull context) {
     AEModuleProcess(file1, context);     // Run player (pushes 1)
     AEModuleProcess(filter1, context);   // Run filter (edits top buffer)
 
     AEModuleProcess(file2, context);     // Run player (pushes 1)
     AEModuleProcess(file3, context);     // Run player (pushes 1)
     AEBufferStackMix(context->stack, 2); // Mix top 2 buffers
 
     AEModuleProcess(filter2, context);   // Run filter (edits top buffer)
 
     AERenderContextOutput(context, 1);   // Put top buffer onto output
     AEModuleProcess(recorder, context);  // Run recorder (uses top buffer)
 };
 @endcode
 
 Note that we interact with the rendering environment via the AERenderContext; this provides us with a variety
 of important state information for the current render, as well as access to the buffer stack.
 
 Finally, when we're initialized, we start the output:
 
 @code
 [self.output start:NULL];
 @endcode
 
 We should hear all three audio file players, with a bandpass effect on the first, and a delay effect on the
 other two. We'll also get a recorded file which contains what we heard.
 
 For a more sophisticated example, take a look at the sample app that comes with TAAE 2.
 
 <hr>
 
 More documentation coming soon.

 
*/

#ifdef __cplusplus
}
#endif