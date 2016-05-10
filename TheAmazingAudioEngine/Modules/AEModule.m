//
//  AEModule.m
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

#import "AEModule.h"
#import "AERenderer.h"

@implementation AEModule

- (instancetype)initWithRenderer:(AERenderer *)renderer {
    if ( !(self = [super init]) ) return nil;
    _renderer = renderer;
    if ( _renderer ) {
        [self startObservingRenderer];
    }
    return self;
}

- (void)dealloc {
    self.renderer = nil;
}

- (void)setRenderer:(AERenderer *)renderer {
    if ( _renderer == renderer ) return;
    
    if ( _renderer ) {
        [self stopObservingRenderer];
    }
    
    _renderer = renderer;
    
    if ( _renderer ) {
        [self startObservingRenderer];
        [self rendererDidChangeSampleRate];
        [self rendererDidChangeNumberOfChannels];
    }
}

- (void)startObservingRenderer {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rendererDidChangeSampleRate)
                                                 name:AERendererDidChangeSampleRateNotification object:_renderer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rendererDidChangeNumberOfChannels)
                                                 name:AERendererDidChangeNumberOfOutputChannelsNotification object:_renderer];
}

- (void)stopObservingRenderer {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AERendererDidChangeSampleRateNotification
                                                  object:_renderer];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AERendererDidChangeNumberOfOutputChannelsNotification
                                                  object:_renderer];
}

- (void)rendererDidChangeSampleRate {
    
}

- (void)rendererDidChangeNumberOfChannels {
    
}

void AEModuleProcess(__unsafe_unretained AEModule * module, const AERenderContext * _Nonnull context) {
    if ( module->_processFunction ) {
        module->_processFunction(module, context);
    }
}

BOOL AEModuleIsActive(__unsafe_unretained AEModule * _Nonnull module) {
    if ( module->_isActiveFunction ) {
        return module->_isActiveFunction(module);
    } else {
        return YES;
    }
}

@end
