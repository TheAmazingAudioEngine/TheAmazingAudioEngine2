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
#import "AEManagedValue.h"

@interface AEMainThreadEndpoint ()
@property (nonatomic, copy) AEMainThreadEndpointHandler handler;
@property (nonatomic, strong) NSTimer * timer;
@property (nonatomic, strong) AEManagedValue * buffer;
@end

@interface AEMainThreadEndpointProxy : NSProxy
@property (nonatomic, weak) AEMainThreadEndpoint * target;
@end

@implementation AEMainThreadEndpoint
@dynamic isPolling;

- (instancetype)initWithHandler:(AEMainThreadEndpointHandler)handler {
    if ( !(self = [super init]) ) return nil;
    
    _pollInterval = 0.01;
    _bufferCapacity = 8192;
    self.handler = handler;
    self.buffer = [AEManagedValue new];
    self.buffer.releaseBlock = ^(void * value) {
        TPCircularBufferCleanup((TPCircularBuffer*)value);
        free(value);
    };
    
    return self;
}

- (void)dealloc {
    if ( self.timer ) {
        [self.timer invalidate];
    }
}

- (BOOL)startPolling {
    if ( self.timer ) {
        return YES;
    }
    
    if ( ![self allocateBuffer] ) {
        return NO;
    }
    
    [self startTimer];
    
    return YES;
}

- (void)endPolling {
    [self.timer invalidate];
    self.timer = nil;
    self.buffer.pointerValue = NULL;
}

- (BOOL)isPolling {
    return self.timer != nil;
}

- (void)setPollInterval:(AESeconds)pollInterval {
    _pollInterval = pollInterval;
    
    if ( self.timer ) {
        // Restart timer
        [self.timer invalidate];
        [self startTimer];
    }
}

- (void)setBufferCapacity:(size_t)bufferCapacity {
    _bufferCapacity = bufferCapacity;
    if ( self.buffer.pointerValue ) {
        [self allocateBuffer];
    }
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
    // Get buffer
    TPCircularBuffer * buffer = (TPCircularBuffer *)AEManagedValueGetValue(THIS->_buffer);
    if ( !buffer ) {
        return NULL;
    }
    
    // Get pointer to writable bytes
    int32_t size = (int32_t)(length + sizeof(size_t));
    int32_t availableBytes;
    void * head = TPCircularBufferHead(buffer, &availableBytes);
    if ( availableBytes < size ) {
        return NULL;
    }
    
    // Write the length of the message
    *((size_t*)head) = length;
    
    // Return the following region ready for writing
    return head + sizeof(size_t);
}

void AEMainThreadEndpointDispatchMessage(__unsafe_unretained AEMainThreadEndpoint * THIS) {
    // Get buffer
    TPCircularBuffer * buffer = (TPCircularBuffer *)AEManagedValueGetValue(THIS->_buffer);
    if ( !buffer ) {
        return;
    }
    
    // Get pointer to writable bytes
    int32_t availableBytes;
    void * head = TPCircularBufferHead(buffer, &availableBytes);
    size_t size = *((size_t*)head) + sizeof(size_t);
    
    // Mark as ready to read
    TPCircularBufferProduce(buffer, (int32_t)size);
}

- (BOOL)allocateBuffer {
    TPCircularBuffer * buffer = (TPCircularBuffer*)malloc(sizeof(TPCircularBuffer));
    if ( !TPCircularBufferInit(buffer, (int32_t)self.bufferCapacity) ) {
        free(buffer);
        return NO;
    }
    self.buffer.pointerValue = buffer;
    return YES;
}

- (void)startTimer {
    AEMainThreadEndpointProxy * proxy = [AEMainThreadEndpointProxy alloc];
    proxy.target = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:self.pollInterval target:proxy selector:@selector(poll)
                                                userInfo:nil repeats:YES];
}

- (void)poll {
    TPCircularBuffer * buffer = (TPCircularBuffer *)self.buffer.pointerValue;
    while ( 1 ) {
        // Get pointer to readable bytes
        int32_t availableBytes;
        void * tail = TPCircularBufferTail(buffer, &availableBytes);
        if ( availableBytes == 0 ) return;
        
        // Get length and data
        size_t length = *((size_t*)tail);
        void * data = length > 0 ? (tail + sizeof(size_t)) : NULL;
        
        // Run handler
        self.handler(data, length);
        
        // Mark as read
        TPCircularBufferConsume(buffer, (int32_t)(sizeof(size_t) + length));
    }
}

@end

@implementation AEMainThreadEndpointProxy
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [_target methodSignatureForSelector:selector];
}
- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation setTarget:_target];
    [invocation invoke];
}
@end
