//
//  AEMessageQueue.h
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

@import Foundation;
#import "AETime.h"

//! Argument to method call, for use with AEMessageQueuePerformSelectorOnMainThread
typedef struct {
    BOOL isValue;
    const void * _Nullable data;
    size_t length;
} AEMessageQueueArgument;

//! Empty argument, to terminate list of arguments in AEMessageQueuePerformSelectorOnMainThread
extern AEMessageQueueArgument AEMessageQueueArgumentNone;

/*!
 * Create a scalar argument for use with AEMessageQueuePerformSelectorOnMainThread
 *
 *  For example, to create a literal int argument:
 *
 *      AEMessageQueueArgumentMake(1);
 *
 *  To create a pointer argument:
 *
 *      __unsafe_unretained MyClass * myPointer;
 *      AEMessageQueueArgumentMake(myPointer);
 *
 *  To create a literal structure argument, use AEMessageQueueArgumentMakeStruct;
 *  to create an argument that points a memory region, use AEMessageQueueArgumentMakeData.
 *
 * @param argument The argument value
 * @return The initialized argument
 */
#define AEMessageQueueArgumentMakeScalar(argument) \
    (AEMessageQueueArgument){ YES, &(typeof(argument)){argument}, sizeof(argument) }

/*!
 * Create a literal structure argument for use with AEMessageQueuePerformSelectorOnMainThread
 *
 *  For example (note extra parentheses around braced structure initialization):
 *
 *      AEMessageQueueArgumentMakeStruct(((struct MyStruct) { value1, value2 }))
 *
 * @param argument The literal struct argument
 * @return The initialized argument
 */
#define AEMessageQueueArgumentMakeStruct(argument) \
    (AEMessageQueueArgument){ YES, &(argument), sizeof(argument) }

/*!
 * Create a data argument for use with AEMessageQueuePerformSelectorOnMainThread
 *
 *  The memory region indicated will be copied.
 *  For example:
 *
 *      void * myBuffer = ...;
 *      AEMessageQueueArgumentMakeData(myBuffer, myBufferLength);
 *
 * @param buffer Pointer to the buffer to copy
 * @param size Number of bytes to copy
 * @return The initialized argument
 */
#define AEMessageQueueArgumentMakeData(buffer, size) \
    (AEMessageQueueArgument) { NO, buffer, size }

/*!
 * Message Queue
 *
 *  This class manages a two-way message queue which is used to pass messages back and
 *  forth between the audio thread and the main thread. This provides for
 *  an easy lock-free synchronization method, which is important when working with audio.
 *
 *  To use it, create an instance and then begin calling AEMessageQueuePoll from your render loop,
 *  in order to poll for incoming messages on the render thread. Then call startPolling on the
 *  main thread to begin polling for incoming messages on the main thread.
 *
 *  Then, use AEMessageQueuePerformOnMainThread from the audio thread, or
 *  performBlockOnAudioThread: or performBlockOnAudioThread:completionBlock: from the main thread.
 */
@interface AEMessageQueue : NSObject

/*!
 * Default initializer
 */
- (instancetype _Nullable)init;

/*!
 * Begin polling for messages from the audio thread
 *
 *  Call this to begin listening for messages from the audio thread.
 *
 * @return YES if polling started successfully, NO if there was a buffer allocation problem
 */
- (BOOL)startPolling;

/*!
 * Stop polling for messages
 */
- (void)endPolling;

/*!
 * Send a message to the realtime thread from the main thread
 *
 *  Important: Do not interact with any Objective-C objects inside your block, or hold locks, allocate
 *  memory or interact with the BSD subsystem, as all of these may result in audio glitches due
 *  to priority inversion.
 *
 * @param block A block to be performed on the realtime thread.
 */
- (void)performBlockOnAudioThread:(void (^ _Nonnull)())block;

/*!
 * Send a message to the realtime thread, with a completion block
 *
 *  If provided, the completion block will be called on the main thread after the message has
 *  been processed on the realtime thread. You may exchange information from the realtime thread to
 *  the main thread via a shared data structure (such as a struct, allocated on the heap in advance),
 *  or a __block variable.
 *
 *  Important: Do not interact with any Objective-C objects inside your block, or hold locks, allocate
 *  memory or interact with the BSD subsystem, as all of these may result in audio glitches due
 *  to priority inversion.

 * @param block  A block to be performed on the realtime thread.
 * @param completionBlock A block to be performed on the main thread after the handler has been run, or nil.
 */
- (void)performBlockOnAudioThread:(void (^ _Nonnull)())block completionBlock:(void (^ _Nullable)())completionBlock;

/*!
 * Perform a selector on the main thread asynchronously
 *
 *  This method allows you to cause a method to be called on the main thread. You can provide any number
 *  of arguments to the method, as pointers to the argument data.
 *
 * @param messageQueue The message queue instance
 * @param target The target object
 * @param selector The selector
 * @param arguments List of arguments, terminated by AEMessageQueueArgumentNone
 * @return YES on success, or NO if out of buffer space or not polling
 */
BOOL AEMessageQueuePerformSelectorOnMainThread(__unsafe_unretained AEMessageQueue * _Nonnull messageQueue,
                                               __unsafe_unretained id _Nonnull target,
                                               SEL _Nonnull selector,
                                               AEMessageQueueArgument arguments, ...);

/*!
 * Begins a group of messages to be performed consecutively.
 *
 *  Messages sent using sendBytes:length: between calls to this method and endMessageGroup
 *  will be performed consecutively on the main thread during a single poll interval.
 */
- (void)beginMessageGroup;

/*!
 * Ends a consecutive group of messages
 */
- (void)endMessageGroup;

/*!
 * Poll for pending messages on realtime thread
 *
 *  Call this periodically from the realtime thread to process pending message blocks.
 */
void AEMessageQueuePoll(__unsafe_unretained AEMessageQueue * _Nonnull THIS);

//! The poll interval (default is 10ms)
@property (nonatomic) AESeconds pollInterval;

//! The buffer capacity, in bytes (default is 8192 bytes). Note that due to the underlying implementation,
//! actual capacity may be larger.
@property (nonatomic) size_t bufferCapacity;

@end
