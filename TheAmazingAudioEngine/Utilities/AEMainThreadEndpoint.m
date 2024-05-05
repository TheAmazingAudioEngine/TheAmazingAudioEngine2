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
#import <mach/semaphore.h>
#import <mach/task.h>
#import <mach/mach_init.h>
#import <pthread.h>

static const int kMaxMessagesEachService = 20;

@class AEMainThreadEndpointThread;

static AEMainThreadEndpointThread * __sharedThread = nil;

@interface AEMainThreadEndpoint () {
    TPCircularBuffer _buffer;
    BOOL _hasPendingMainThreadMessages;
    pthread_mutex_t _mutex;
}
@property (nonatomic, copy) AEMainThreadEndpointHandler handler;
@property (nonatomic) semaphore_t semaphore;
@property (nonatomic, strong) AEMainThreadEndpointThread * thread;
@property (nonatomic, strong) NSMutableArray <void (^)(void)> * mainThreadBlocks;
@end

@interface AEMainThreadEndpointThread : NSThread
- (void)addEndpoint:(AEMainThreadEndpoint *)endpoint;
- (void)removeEndpoint:(AEMainThreadEndpoint *)endpoint;
@property (nonatomic) semaphore_t semaphore;
@end

@implementation AEMainThreadEndpoint

+ (AEMainThreadEndpointThread *)sharedThread {
    if ( !__sharedThread ) {
        __sharedThread = [AEMainThreadEndpointThread new];
        [__sharedThread start];
    }
    
    return __sharedThread;
}

- (instancetype)initWithHandler:(AEMainThreadEndpointHandler)handler {
    return [self initWithHandler:handler bufferCapacity:8192];
}

- (instancetype)initWithHandler:(AEMainThreadEndpointHandler)handler bufferCapacity:(size_t)bufferCapacity {
    if ( !(self = [super init]) ) return nil;
    
    self.handler = handler;
    
    if ( !TPCircularBufferInit(&_buffer, (int32_t)bufferCapacity) ) {
        return nil;
    }
    
    self.thread = [AEMainThreadEndpoint sharedThread];
    [self.thread addEndpoint:self];
    self.semaphore = self.thread.semaphore;
    
    self.mainThreadBlocks = [NSMutableArray array];
    pthread_mutex_init(&_mutex, NULL);
    
    return self;
}

- (void)dealloc {
    [self.thread removeEndpoint:self];
    TPCircularBufferCleanup(&_buffer);
    pthread_mutex_destroy(&_mutex);
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
    semaphore_signal(THIS->_semaphore);
}

- (void)serviceMessages {
    if ( NSThread.isMainThread ) {
        [self serviceBlockQueue];
    }
    
    pthread_mutex_lock(&_mutex);
    for ( int i=0; i<kMaxMessagesEachService; i++ ) {
        // Get pointer to readable bytes
        int32_t availableBytes;
        void * tail = TPCircularBufferTail(&_buffer, &availableBytes);
        if ( availableBytes == 0 ) {
            pthread_mutex_unlock(&_mutex);
            return;
        }
        
        // Get length and data
        size_t length = *((size_t*)tail);
        void * data = length > 0 ? (tail + sizeof(size_t)) : NULL;
        
        if ( NSThread.isMainThread ) {
            self.handler(data, length);
        } else {
            void * dataCopy = malloc(length);
            memcpy(dataCopy, data, length);
            __weak typeof(self) weakSelf = self;
            [self.mainThreadBlocks addObject:^{
                // Run handler
                weakSelf.handler(dataCopy, length);
                free(dataCopy);
            }];
            dispatch_async(dispatch_get_main_queue(), ^{ [self serviceBlockQueue]; });
        }
        
        // Mark as read
        TPCircularBufferConsume(&_buffer, (int32_t)(sizeof(size_t) + length));
    }
    pthread_mutex_unlock(&_mutex);
}

- (void)serviceBlockQueue {
    pthread_mutex_lock(&_mutex);
    NSArray <void (^)(void)> * mainThreadBlocks = self.mainThreadBlocks.copy;
    [self.mainThreadBlocks removeAllObjects];
    pthread_mutex_unlock(&_mutex);
    
    for ( void (^block)(void) in mainThreadBlocks ) {
        block();
    }
}

@end

#pragma mark - Handler thread

@interface AEMainThreadEndpointThread () {
    pthread_mutex_t _mutex;
}
@property (nonatomic, strong) NSHashTable * endpoints;
@end

@implementation AEMainThreadEndpointThread

- (instancetype)init {
    if ( !(self = [super init]) ) return nil;
    semaphore_create(mach_task_self(), &_semaphore, SYNC_POLICY_FIFO, 0);
    self.endpoints = [NSHashTable weakObjectsHashTable];
    pthread_mutex_init(&_mutex, NULL);
    return self;
}

- (void)dealloc {
    semaphore_destroy(mach_task_self(), _semaphore);
    pthread_mutex_destroy(&_mutex);
}

- (void)cancel {
    [super cancel];
    semaphore_signal(_semaphore);
}

- (void)addEndpoint:(AEMainThreadEndpoint *)endpoint {
    pthread_mutex_lock(&_mutex);
    [self.endpoints addObject:endpoint];
    pthread_mutex_unlock(&_mutex);
}

- (void)removeEndpoint:(AEMainThreadEndpoint *)endpoint {
    pthread_mutex_lock(&_mutex);
    [self.endpoints removeObject:endpoint];
    pthread_mutex_unlock(&_mutex);
}

- (void)main {
    pthread_setname_np("AEMainThreadEndpoint");
    
    while ( !self.cancelled ) {
        @autoreleasepool {
            // Get list of endpoints (protected by mutex)
            pthread_mutex_lock(&_mutex);
            NSArray <AEMainThreadEndpoint *> * endpoints = self.endpoints.allObjects;
            pthread_mutex_unlock(&_mutex);
            
            // Service endpoints
            for ( AEMainThreadEndpoint * endpoint in endpoints ) {
                [endpoint serviceMessages];
            }
        }
        
        semaphore_wait(_semaphore);
    }
}

@end
