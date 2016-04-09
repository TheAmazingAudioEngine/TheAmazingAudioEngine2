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

@interface AEModule ()
@property (nonatomic, weak, readwrite) AERenderer * renderer;
@end

@implementation AEModule

- (instancetype)initWithRenderer:(AERenderer *)renderer {
    if ( !(self = [super init]) ) return nil;
    self.renderer = renderer;
    return self;
}

- (void)dealloc {
    self.renderer = nil;
}

- (void)setRenderer:(AERenderer *)renderer {
    if ( _renderer ) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AERendererDidChangeSampleRateNotification
                                                      object:_renderer];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AERendererDidChangeChannelCountNotification
                                                      object:_renderer];
    }
    
    BOOL hadRenderer = _renderer != nil;
    
    _renderer = renderer;
    
    if ( _renderer ) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rendererDidChangeSampleRate)
                                                     name:AERendererDidChangeSampleRateNotification object:_renderer];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rendererDidChangeChannelCount)
                                                     name:AERendererDidChangeChannelCountNotification object:_renderer];
        
        if ( hadRenderer ) {
            [self rendererDidChangeSampleRate];
            [self rendererDidChangeChannelCount];
        }
    }
}

- (void)rendererDidChangeSampleRate {
    
}

- (void)rendererDidChangeChannelCount {
    
}

void AEModuleProcess(__unsafe_unretained AEModule * module, const AERenderContext * _Nonnull context) {
    if ( module->_processFunction ) {
        module->_processFunction(module, context);
    }
}

@end
