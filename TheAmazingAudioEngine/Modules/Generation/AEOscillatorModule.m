//
//  AEOscillatorModule.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 24/03/2016.
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

#import "AEOscillatorModule.h"
#import "AEDSPUtilities.h"

@interface AEOscillatorModule () {
    float _position;
}
@end

@implementation AEOscillatorModule

- (instancetype)initWithRenderer:(AERenderer *)renderer {
    if ( !(self = [super initWithRenderer:renderer]) ) return nil;
    self.frequency = 440;
    self.processFunction = AEOscillatorModuleProcess;
    return self;
}

static void AEOscillatorModuleProcess(__unsafe_unretained AEOscillatorModule * self, const AERenderContext * _Nonnull context) {
    const AudioBufferList * abl = AEBufferStackPushWithChannels(context->stack, 1, 1);
    if ( !abl ) return;
    
    float rate = self->_frequency / context->sampleRate;
    for ( int i=0; i<context->frames; i++ ) {
        ((float*)abl->mBuffers[0].mData)[i] = AEDSPGenerateOscillator(rate, &self->_position) - 0.5;
    }
}

@end
