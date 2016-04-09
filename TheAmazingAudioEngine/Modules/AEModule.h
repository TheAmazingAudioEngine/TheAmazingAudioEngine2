//
//  AEModule.h
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
#import "AEBufferStack.h"
#import "AERenderer.h"

#ifdef __cplusplus
extern "C" {
#endif


@class AEModule;

/*!
 * Processing function
 *
 *  All modules must provide a function of this type, and assign it to the
 *  @link AEModule::processFunction processFunction @endlink property.
 *
 *  Within a processing a function, a module may add, modify or remove
 *  buffers within the stack.
 *
 * @param self A pointer to the module
 * @param context The rendering context
 */
typedef void (*AEModuleProcessFunc)(__unsafe_unretained AEModule * _Nonnull self, const AERenderContext * _Nonnull context);

/*!
 * Module base class
 *
 *  Modules are the basic processing unit, and all provide a function to perform processing.
 *  Processing is invoked by calling AEModuleProcess and passing in the module.
 */
@interface AEModule : NSObject

/*!
 * Initializer
 *
 * @param renderer The renderer
 */
- (instancetype _Nullable)initWithRenderer:(AERenderer * _Nonnull)renderer;

/*!
 * Invoke processing for a module
 *
 * @param module The module subclass
 * @param context The rendering context
 */
void AEModuleProcess(__unsafe_unretained AEModule * _Nonnull module, const AERenderContext * _Nonnull context);

/*!
 * Notifies the module that the renderer's sample rate has changed
 *
 *  Subclasses may override this method to react to sample rate changes.
 */
- (void)rendererDidChangeSampleRate;

/*!
 * Notifies the module that the renderer's channel count has changed
 *
 *  Subclasses may override this method to react to channel count changes.
 */
- (void)rendererDidChangeChannelCount;

/*!
 * Process function
 *
 *  All subclasses must set this property to the address of their
 *  processing function to be able to process audio.
 */
@property (nonatomic) AEModuleProcessFunc _Nonnull processFunction;

/*!
 * The renderer
 */
@property (nonatomic, weak, readonly) AERenderer * _Nullable renderer;

@end

#ifdef __cplusplus
}
#endif
