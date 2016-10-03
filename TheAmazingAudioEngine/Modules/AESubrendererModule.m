//
//  AESubrendererModule.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 23/04/2016.
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

#import "AESubrendererModule.h"
#import "AEManagedValue.h"
#import "AEAudioBufferListUtilities.h"

@interface AESubrendererModule ()
@property (nonatomic, strong) AEManagedValue * subrendererValue;
@end

@implementation AESubrendererModule
@dynamic subrenderer;

- (instancetype)initWithRenderer:(AERenderer *)renderer subrenderer:(AERenderer *)subrenderer {
    if ( !(self = [super initWithRenderer:renderer]) ) return nil;
    
    self.numberOfOutputChannels = 2;
    self.subrendererValue = [AEManagedValue new];
    self.subrenderer = subrenderer;
    self.processFunction = AESubrendererModuleProcess;
    
    return self;
}

- (void)setSubrenderer:(AERenderer *)subrenderer {
    self.subrendererValue.objectValue = subrenderer;
}

- (AERenderer *)subrenderer {
    return self.subrendererValue.objectValue;
}

static void AESubrendererModuleProcess(__unsafe_unretained AESubrendererModule * self,
                                       const AERenderContext * _Nonnull context) {
    
    const AudioBufferList * abl =
        AEBufferStackPushWithChannels(context->stack, 1,
                                      self->_numberOfOutputChannels == 0 ? context->output->mNumberBuffers
                                        : self->_numberOfOutputChannels);
    if ( !abl ) return;
    
    __unsafe_unretained AERenderer * renderer = (__bridge AERenderer*)AEManagedValueGetValue(self->_subrendererValue);
    if ( renderer ) {
        AERendererRun(renderer, abl, context->frames, context->timestamp);
    } else {
        AEAudioBufferListSilence(abl, 0, context->frames);
    }
}

- (void)rendererDidChangeSampleRate {
    self.subrenderer.sampleRate = self.renderer.sampleRate;
}

@end
