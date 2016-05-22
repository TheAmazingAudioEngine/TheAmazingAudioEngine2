//
//  AEMainThreadEndpoint.m
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

#import "AEMainThreadEndpoint.h"
#import "TPCircularBuffer.h"
#import <dispatch/semaphore.h>

@class AEMainThreadEndpointThread;

@interface AEMainThreadEndpoint () {
    TPCircularBuffer _buffer;
}
@property (nonatomic, copy) AEMainThreadEndpointHandler handler;
@property (nonatomic) dispatch_semaphore_t semaphore;
@property (nonatomic, strong) AEMainThreadEndpointThread * thread;
@end

@interface AEMainThreadEndpointThread : NSThread
@property (nonatomic, unsafe_unretained) AEMainThreadEndpoint * endpoint;
@end

@implementation AEMainThreadEndpoint

- (instancetype)initWithHandler:(AEMainThreadEndpointHandler)handler {
    return [self initWithHandler:handler bufferCapacity:8192];
}

- (instancetype)initWithHandler:(AEMainThreadEndpointHandler)handler bufferCapacity:(size_t)bufferCapacity {
    if ( !(self = [super init]) ) return nil;
    
    self.handler = handler;
    
    if ( !TPCircularBufferInit(&_buffer, (int32_t)bufferCapacity) ) {
        return nil;
    }
    
    self.semaphore = dispatch_semaphore_create(0);
    
    self.thread = [AEMainThreadEndpointThread new];
    self.thread.endpoint = self;
    [self.thread start];
    
    return self;
}

- (void)dealloc {
    @synchronized ( self.thread ) {
        [self.thread cancel];
        dispatch_semaphore_signal(_semaphore);
    }
    TPCircularBufferCleanup(&_buffer);
}

BOOL AEMainThreadEndpointSend(__unsafe_unretained AEMainThreadEndpoint * THIS, const void * data, size_t length) {
    
    // Prepare message
    void * message = AEMainThreadEndpointCreateMessage(THIS, length);
    if ( !message ) {
        return NO;
    }
    
    if ( length ) {
        // Copy data
        memcpy(message, data, length);
    }
    
    // Dispatch
    AEMainThreadEndpointDispatchMessage(THIS);
    
    return YES;
}

void * AEMainThreadEndpointCreateMessage(__unsafe_unretained AEMainThreadEndpoint * THIS, size_t length) {
    
    // Get pointer to writable bytes
    int32_t size = (int32_t)(length + sizeof(size_t));
    int32_t availableBytes;
    void * head = TPCircularBufferHead(&THIS->_buffer, &availableBytes);
    if ( availableBytes < size ) {
        return NULL;
    }
    
    // Write the length of the message
    *((size_t*)head) = length;
    
    // Return the following region ready for writing
    return head + sizeof(size_t);
}

void AEMainThreadEndpointDispatchMessage(__unsafe_unretained AEMainThreadEndpoint * THIS) {

    // Get pointer to writable bytes
    int32_t availableBytes;
    void * head = TPCircularBufferHead(&THIS->_buffer, &availableBytes);
    size_t size = *((size_t*)head) + sizeof(size_t);
    
    // Mark as ready to read
    TPCircularBufferProduce(&THIS->_buffer, (int32_t)size);
    dispatch_semaphore_signal(THIS->_semaphore);
}

- (void)poll {
    while ( 1 ) {
        // Get pointer to readable bytes
        int32_t availableBytes;
        void * tail = TPCircularBufferTail(&_buffer, &availableBytes);
        if ( availableBytes == 0 ) return;
        
        // Get length and data
        size_t length = *((size_t*)tail);
        void * data = length > 0 ? (tail + sizeof(size_t)) : NULL;
        
        // Run handler
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.handler(data, length);
        });
        
        // Mark as read
        TPCircularBufferConsume(&_buffer, (int32_t)(sizeof(size_t) + length));
    }
}

@end

@implementation AEMainThreadEndpointThread

- (void)main {
    dispatch_semaphore_t semaphore = self.endpoint.semaphore;
    
    while ( 1 ) {
        @synchronized ( self ) {
            if ( self.cancelled ) {
                break;
            }
            @autoreleasepool {
                [self.endpoint poll];
            }
        }
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
}

@end
