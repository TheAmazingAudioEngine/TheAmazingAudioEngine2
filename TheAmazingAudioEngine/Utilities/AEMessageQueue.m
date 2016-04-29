//
//  AEMessageQueue.m
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

#import "AEMessageQueue.h"
#import "AEMainThreadEndpoint.h"
#import "AEAudioThreadEndpoint.h"

typedef enum {
    AEMessageQueueMainThreadMessage,
    AEMessageQueueAudioThreadMessage,
} AEMessageQueueMessageType;

// Audio thread message type
typedef struct {
    AEMessageQueueMessageType type;
    __unsafe_unretained void (^block)(void);
    __unsafe_unretained void (^completionBlock)(void);
} audio_thread_message_t;

// Main thread message type
typedef struct {
    AEMessageQueueMessageType type;
    AEMessageQueueMessageHandler handler;
    size_t length;
} main_thread_message_t;




@interface AEMessageQueue ()
@property (nonatomic, strong) AEMainThreadEndpoint * mainThreadEndpoint;
@property (nonatomic, strong) AEAudioThreadEndpoint * audioThreadEndpoint;
@end

@implementation AEMessageQueue

- (instancetype)init {
    if ( !(self = [super init]) ) return nil;
    
    // Create main thread endpoint
    self.mainThreadEndpoint = [[AEMainThreadEndpoint alloc] initWithHandler:^(const void * _Nullable data, size_t length) {
        const AEMessageQueueMessageType * type = (AEMessageQueueMessageType *)data;
        if ( *type == AEMessageQueueMainThreadMessage ) {
            // Call handler function
            const main_thread_message_t * message = (const main_thread_message_t *)data;
            message->handler(message->length > 0 ? data + sizeof(main_thread_message_t) : NULL, message->length);
            
        } else if ( *type == AEMessageQueueAudioThreadMessage ) {
            // Clean up audio thread message, and possibly call completion block
            const audio_thread_message_t * message = (const audio_thread_message_t *)data;
            CFRelease((__bridge CFTypeRef)(message->block));
            
            if ( message->completionBlock ) {
                message->completionBlock();
                CFRelease((__bridge CFTypeRef)(message->completionBlock));
            }
        }
    }];
    
    // Create audio thread endpoint
    AEMainThreadEndpoint * mainThread = _mainThreadEndpoint;
    self.audioThreadEndpoint = [[AEAudioThreadEndpoint alloc] initWithHandler:^(const void * _Nullable data, size_t length) {
        // Call block
        const audio_thread_message_t * message = (const audio_thread_message_t *)data;
        message->block();
        
        // Enqueue response on main thread, to clean up and possibly call completion block
        AEMainThreadEndpointSend(mainThread, data, length);
    }];
    
    _pollInterval = self.mainThreadEndpoint.pollInterval;
    _bufferCapacity = self.mainThreadEndpoint.bufferCapacity;
    
    return self;
}

- (BOOL)startPolling {
    return [self.mainThreadEndpoint startPolling];
}

- (void)endPolling {
    [self.mainThreadEndpoint endPolling];
}

- (void)performBlockOnAudioThread:(void (^)())block {
    [self performBlockOnAudioThread:block completionBlock:nil];
}

- (void)performBlockOnAudioThread:(void (^)())block completionBlock:(void (^)())completionBlock {
    // Prepare message
    audio_thread_message_t message = {
        .type = AEMessageQueueAudioThreadMessage,
        .block = CFRetain((__bridge CFTypeRef)[block copy]),
        .completionBlock = completionBlock ? CFRetain((__bridge CFTypeRef)[completionBlock copy]) : NULL,
    };
    
    // Dispatch
    [self.audioThreadEndpoint sendBytes:&message length:sizeof(message)];
}

BOOL AEMessageQueuePerformOnMainThread(AEMessageQueue * THIS,
                                       AEMessageQueueMessageHandler handler,
                                       const void * data,
                                       size_t length) {
    // Prepare message buffer
    size_t messageSize = sizeof(main_thread_message_t) + length;
    void * message = AEMainThreadEndpointCreateMessage(THIS->_mainThreadEndpoint, messageSize);
    if ( !message ) return NO;
    
    // Write header
    ((main_thread_message_t *)message)->type = AEMessageQueueMainThreadMessage;
    ((main_thread_message_t *)message)->handler = handler;
    ((main_thread_message_t *)message)->length = length;
    if ( length > 0 ) {
        // Copy in data
        memcpy(message + sizeof(main_thread_message_t), data, length);
    }
    
    // Dispatch
    AEMainThreadEndpointDispatchMessage(THIS->_mainThreadEndpoint);
    
    return YES;
}

- (void)beginMessageGroup {
    [self.audioThreadEndpoint beginMessageGroup];
}

- (void)endMessageGroup {
    [self.audioThreadEndpoint endMessageGroup];
}

void AEMessageQueuePoll(__unsafe_unretained AEMessageQueue * _Nonnull THIS) {
    AEAudioThreadEndpointPoll(THIS->_audioThreadEndpoint);
}

- (void)setPollInterval:(AESeconds)pollInterval {
    _pollInterval = pollInterval;
    self.mainThreadEndpoint.pollInterval = pollInterval;
}

- (void)setBufferCapacity:(size_t)bufferCapacity {
    _bufferCapacity = bufferCapacity;
    self.mainThreadEndpoint.bufferCapacity = bufferCapacity;
    self.audioThreadEndpoint.bufferCapacity = bufferCapacity;
}

@end