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
#import <TheAmazingAudioEngine/AEFileRecorderModule.h>
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


/*!
 @mainpage
 
 @section Introduction
 
 The programming guide for TAAE 2 has not yet been written. Until it has been, please refer to
 the header documentation, available in the list to the left, and the TAAE 2 sample app.
 
 Top-level classes of interest:
 
 - AEAudioUnitOutput - The typical output used to link the renderer to the system audio output
 - AERenderer - The main driver of audio processing, via the @link AERenderLoopBlock AERenderLoopBlock @endlink
 - AERenderContext - The rendering context, passed to the render block
 - @link AEBufferStack AEBufferStack @endlink - The pool of buffers used for passing around audio
 - AEModule - A unit of processing, which can generate audio, filter it, monitor or analyze, etc.
    - AEAudioFilePlayerModule - Play files
    - AEAudioUnitInputModule - Get input from the system audio
    - AEFileRecorderModule - Record files
 - AEManagedValue - Manage a reference to an object or pointer in a thread-safe way
 - AEArray - Manage a list of objects or pointers in a thread-safe way
 - AEMessageQueue, AEMainThreadEndpoint, AEAudioThreadEndpoint - Cross-thread synchronisation
 
*/

#ifdef __cplusplus
}
#endif