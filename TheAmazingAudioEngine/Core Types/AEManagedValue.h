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

#ifdef __cplusplus
extern "C" {
#endif
    
#import <Foundation/Foundation.h>

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
 * Update multiple AEManagedValue instances atomically
 *
 *  Any changes made within the block will be applied atomically with respect to the audio thread.
 *  Any value accesses made from the realtime thread while the block is executing will return the
 *  prior value, until the block has completed.
 *
 *  These may be nested safely.
 *
 *  Important: If you use this method, you must also use the AEManagedValueCommitPendingAtomicUpdates 
 *  function at the beginning of your main render loop. This ensures batched updates are all committed
 *  in sync with your render loop. Until this function is called, AEManagedValueGetValue returns old
 *  values, prior to those set in the given block.
 *
 * @param block Atomic update block
 */
+ (void)performAtomicBatchUpdate:(void(^ _Nonnull)())block;

/*!
 * Get access to the value on the realtime thread
 *
 *  The object or buffer returned is guaranteed to remain valid until the next call to this function.
 *
 * @param managedValue The instance
 * @return The value
 */
void * _Nullable AEManagedValueGetValue(__unsafe_unretained AEManagedValue * _Nonnull managedValue);

/*!
 * Commit pending atomic batch updates on the realtime thread
 *
 *  If you use performAtomicBatchUpdate: to change the values of multiple managed values atomically,
 *  with respect to the render loop, then you must also call this function at the start of your top-level
 *  render loop in order to apply updates in sync.
 *
 *  After you call this function, any updates made within the loop bassed to performAtomicBatchUpdate:
 *  become available on the render thread.
 */
void AEManagedValueCommitPendingAtomicUpdates();

/*!
 * An object. You can set this property from the main thread. Note that you can use this property, 
 * or pointerValue, but not both.
 */
@property (nonatomic, strong) id _Nullable objectValue;

/*!
 * A pointer to an allocated memory buffer. Old values will be automatically freed when the value 
 * changes. You can set this property from the main thread. Note that you can use this property, 
 * or objectValue, but not both.
 */
@property (nonatomic) void * _Nullable pointerValue;

/*!
 * Block to perform when deleting old items, on main thread. If not specified, will simply use 
 * free() to dispose values set via pointerValue, or CFRelease() to dispose values set via objectValue.
 */
@property (nonatomic, copy) void (^ _Nullable releaseBlock)(void * _Nonnull value);

/*!
 * Block for release notifications. Use this to be informed when an old value has been released.
 */
@property (nonatomic, copy) void (^ _Nullable releaseNotificationBlock)(void);

@end

#ifdef __cplusplus
}
#endif
