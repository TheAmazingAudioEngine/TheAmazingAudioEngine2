//
//  AEManagedValue.h
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 30/03/2016.
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

/*!
 * Managed value
 *
 *  This class manages a mutable reference to a memory buffer or Objective-C object which is both thread-safe
 *  and realtime safe. It manages the life-cycle of the buffer/object so that it can not be deallocated
 *  while being accessed on the main thread, and does so without locking the realtime thread.
 *
 *  You can use this utility to manage a single module instance, which can be swapped out for
 *  another at any time, for instance.
 *
 *  Remember to use the __unsafe_unretained directive to avoid ARC-triggered retains on the
 *  audio thread if using this class to manage an Objective-C object, and only interact with such objects
 *  via C functions they provide, not via Objective-C methods.
 */
@interface AEManagedValue : NSObject

/*!
 * Get access to the value on the realtime thread
 *
 *  The object or buffer returned is guaranteed to remain valid until the next call to this function.
 *
 * @param managedValue The instance
 * @return The value
 */
void * AEManagedValueGetValue(__unsafe_unretained AEManagedValue * managedValue);

/*!
 * An object. You can set this property from the main thread. Note that you can use this property, 
 * or pointerValue, but not both.
 */
@property (nonatomic, strong) id objectValue;

/*!
 * A pointer to an allocated memory buffer. Old values will be automatically freed when the value 
 * changes. You can set this property from the main thread. Note that you can use this property, 
 * or objectValue, but not both.
 */
@property (nonatomic) void * pointerValue;

/*!
 * Block to perform when deleting old items, on main thread. If not specified, will simply use 
 * free() to dispose values set via pointerValue.
 */
@property (nonatomic, copy) void (^releaseBlock)(void * value);

@end
