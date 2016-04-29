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

/*!
 * Main thread message handler function
 *
 *  Create functions of this type in order to handle messages from the realtime thread
 *  on the main thread. You then pass a pointer to these functions when using
 *  @link AEMessageQueue::AEMessageQueueSendMessageToMainThread AEMessageQueueSendMessageToMainThread @endlink 
 *  on the realtime thread, along with data to pass through via the userInfo parameter.
 *
 *  See @link AEMessageQueue::AEMessageQueueSendMessageToMainThread AEMessageQueueSendMessageToMainThread @endlink
 *  for further discussion.
 *
 * @param userInfo          Pointer to your data
 * @param userInfoLength    Length of userInfo in bytes
 */
typedef void (*AEMessageQueueMessageHandler)(const void * _Nonnull data, size_t length);

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
 * Send a message to the main thread asynchronously
 *
 *  Tip: To pass a pointer (including pointers to __unsafe_unretained Objective-C objects) through the
 *  userInfo parameter, be sure to pass the address to the pointer, using the "&" prefix:
 *
 *  @code
 *  AEMessageQueueSendMessageToMainThread(queue, myMainThreadFunction, &pointer, sizeof(void*));
 *  @endcode
 *
 *  or
 *
 *  @code
 *  AEMessageQueueSendMessageToMainThread(queue, myMainThreadFunction, &object, sizeof(MyObject*));
 *  @endcode
 *
 *  You can then retrieve the pointer value via a void** dereference from your function:
 *
 *  @code
 *  void * myPointerValue = *(void**)userInfo;
 *  @endcode
 *
 *  To access an Objective-C object pointer, you also need to bridge the pointer value:
 *
 *  @code
 *  MyObject *object = (__bridge MyObject*)*(void**)userInfo;
 *  @endcode
 *
 * @param messageQueue The message queue instance.
 * @param handler A pointer to a function to call on the main thread.
 * @param data Message data (or NULL) to copy
 * @param length Length of message data
 * @return YES on success, or NO if out of buffer space or not polling
 */
BOOL AEMessageQueuePerformOnMainThread(AEMessageQueue * _Nonnull messageQueue,
                                       AEMessageQueueMessageHandler _Nonnull handler,
                                       const void * _Nonnull data,
                                       size_t length);

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
