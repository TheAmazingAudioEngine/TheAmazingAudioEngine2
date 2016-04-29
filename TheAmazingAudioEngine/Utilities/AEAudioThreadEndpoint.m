//
//  AEAudioThreadEndpoint.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 29/04/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import "AEAudioThreadEndpoint.h"

#import "TPCircularBuffer.h"
#import "AEManagedValue.h"

@interface AEAudioThreadEndpoint () {
    int _groupNestCount;
    int32_t _groupLength;
}
@property (nonatomic, copy) AEAudioThreadEndpointHandler handler;
@property (nonatomic, strong) AEManagedValue * buffer;
@end

@implementation AEAudioThreadEndpoint

- (instancetype)initWithHandler:(AEAudioThreadEndpointHandler)handler {
    if ( !(self = [super init]) ) return nil;
    
    _bufferCapacity = 8192;
    self.handler = handler;
    self.buffer = [AEManagedValue new];
    self.buffer.releaseBlock = ^(void * value) {
        TPCircularBufferCleanup((TPCircularBuffer*)value);
        free(value);
    };
    
    if ( ![self allocateBuffer] ) {
        return nil;
    }
    
    return self;
}

- (void)setBufferCapacity:(size_t)bufferCapacity {
    _bufferCapacity = bufferCapacity;
    if ( self.buffer.pointerValue ) {
        [self allocateBuffer];
    }
}

void AEAudioThreadEndpointPoll(__unsafe_unretained AEAudioThreadEndpoint * _Nonnull THIS) {
    // Get buffer
    TPCircularBuffer * buffer = (TPCircularBuffer *)AEManagedValueGetValue(THIS->_buffer);
    if ( !buffer ) {
        return;
    }
    
    while ( 1 ) {
        // Get pointer to readable bytes
        int32_t availableBytes;
        void * tail = TPCircularBufferTail(buffer, &availableBytes);
        if ( availableBytes == 0 ) return;
        
        // Get length and data
        size_t length = *((size_t*)tail);
        void * data = length > 0 ? (tail + sizeof(size_t)) : NULL;
        
        // Run handler
        THIS->_handler(data, length);
        
        // Mark as read
        TPCircularBufferConsume(buffer, (int32_t)(sizeof(size_t) + length));
    }
}

- (BOOL)sendBytes:(const void *)bytes length:(size_t)length {
    // Prepare message
    void * message = [self createMessageWithLength:length];
    if ( !message ) {
        return NO;
    }
    
    if ( length ) {
        // Copy data
        memcpy(message, bytes, length);
    }
    
    // Dispatch
    [self dispatchMessage];
    
    return YES;
}

- (void *)createMessageWithLength:(size_t)length {
    // Get buffer
    TPCircularBuffer * buffer = (TPCircularBuffer *)self.buffer.pointerValue;
    
    // Get pointer to writable bytes
    int32_t size = (int32_t)(length + sizeof(size_t));
    int32_t availableBytes;
    void * head = TPCircularBufferHead(buffer, &availableBytes);
    if ( availableBytes < size + (_groupNestCount > 0 ? _groupLength : 0) ) {
        return nil;
    }
    
    if ( _groupNestCount > 0 ) {
        // If we're grouping messages, write to end of group
        head += _groupLength;
    }
    
    // Write to buffer: the length of the message, and the message data
    *((size_t*)head) = length;
    
    // Return the following region ready for writing
    return head + sizeof(size_t);
}

-(void)dispatchMessage {
    // Get buffer
    TPCircularBuffer * buffer = (TPCircularBuffer *)self.buffer.pointerValue;
    
    // Get pointer to writable bytes
    int32_t availableBytes;
    void * head = TPCircularBufferHead(buffer, &availableBytes);
    if ( _groupNestCount > 0 ) {
        // If we're grouping messages, write to end of group
        head += _groupLength;
    }
    
    size_t size = *((size_t*)head) + sizeof(size_t);
    
    if ( _groupNestCount == 0 ) {
        TPCircularBufferProduce(buffer, (int32_t)size);
    } else {
        _groupLength += size;
    }
}

- (void)beginMessageGroup {
    _groupNestCount++;
}

- (void)endMessageGroup {
    _groupNestCount--;
    
    if ( _groupNestCount == 0 && _groupLength > 0 ) {
        TPCircularBuffer * buffer = (TPCircularBuffer *)self.buffer.pointerValue;
        TPCircularBufferProduce(buffer, _groupLength);
        _groupLength = 0;
    }
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

@end
