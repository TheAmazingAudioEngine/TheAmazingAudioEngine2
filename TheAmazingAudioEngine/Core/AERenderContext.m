//
//  AERenderContext.m
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

#import "AERenderContext.h"
#import "AEBufferStack.h"

void AERenderContextOutput(const AERenderContext * context, int bufferCount) {
    AEBufferStackMixToBufferList(context->stack, bufferCount, context->output);
}

void AERenderContextOutputToChannels(const AERenderContext * _Nonnull context, int bufferCount, AEChannelSet channels) {
    AEBufferStackMixToBufferListChannels(context->stack, bufferCount, channels, context->output);
}

void AERenderContextRestoreBufferStack(const AERenderContext * context) {
    AEBufferStackSetFrameCount(context->stack, context->frames);
    AEBufferStackSetTimeStamp(context->stack, context->timestamp);
}
