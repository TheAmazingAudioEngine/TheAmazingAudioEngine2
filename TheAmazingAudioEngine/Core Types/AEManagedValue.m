//
//  AEManagedValue.m
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

#import "AEManagedValue.h"
#import <pthread.h>

typedef struct __linkedlistitem_t {
    void * data;
    struct __linkedlistitem_t * next;
} linkedlistitem_t;

@interface AEManagedValue () {
    void * _value;
    linkedlistitem_t * _pendingReleases;
    linkedlistitem_t * _releases;
    pthread_mutex_t _mutex;
    BOOL _valueSet;
    BOOL _isObjectValue;
}
@property (nonatomic, strong) NSTimer * pollTimer;
@end

@interface AEManagedValueProxy : NSProxy
@property (nonatomic, weak) AEManagedValue * target;
@end

@implementation AEManagedValue
@dynamic objectValue, pointerValue;

- (instancetype)init {
    if ( !(self = [super init]) ) return nil;
    pthread_mutex_init(&_mutex, NULL);
    return self;
}

- (void)dealloc {
    [self releaseOldValue:_value];
    if ( _pendingReleases ) AEManagedValueLinkedListAppend(&_releases, _pendingReleases);
    [self pollReleaseList];
    pthread_mutex_destroy(&_mutex);
}

- (id)objectValue {
    NSAssert(!_valueSet || _isObjectValue, @"You can use objectValue or pointerValue, but not both");
    return (__bridge id)_value;
}

- (void)setObjectValue:(id)objectValue {
    NSAssert(!_valueSet || _isObjectValue, @"You can use objectValue or pointerValue, but not both");
    _isObjectValue = YES;
    [self setValue:(__bridge_retained void*)objectValue];
}

- (void *)pointerValue {
    NSAssert(!_valueSet || !_isObjectValue, @"You can use objectValue or pointerValue, but not both");
    return _value;
}

- (void)setPointerValue:(void *)pointerValue {
    NSAssert(!_valueSet || !_isObjectValue, @"You can use objectValue or pointerValue, but not both");
    [self setValue:pointerValue];
}

- (void)setValue:(void *)value {
    // Assign new value
    void * oldValue = _value;
    _value = value;
    _valueSet = YES;
    
    if ( oldValue ) {
        // Mark old value as pending release - it'll be transferred to the release queue by
        // AEManagedValueGetValue on the audio thread
        linkedlistitem_t * release = (linkedlistitem_t*)calloc(1, sizeof(linkedlistitem_t));
        release->data = oldValue;
        pthread_mutex_lock(&_mutex);
        AEManagedValueLinkedListAppend(&_pendingReleases, release);
        pthread_mutex_unlock(&_mutex);
    
        if ( !self.pollTimer ) {
            // Start polling for pending releases
            AEManagedValueProxy * proxy = [AEManagedValueProxy alloc];
            proxy.target = self;
            self.pollTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:proxy
                                                            selector:@selector(pollReleaseList) userInfo:nil repeats:YES];
        }
    }
}

#pragma mark - Realtime thread accessor

void * AEManagedValueGetValue(__unsafe_unretained AEManagedValue * THIS) {
    if ( !THIS ) return NULL;
    if ( THIS->_pendingReleases && pthread_mutex_trylock(&THIS->_mutex) == 0 ) {
        // Move pending release items into the release queue
        if ( THIS->_pendingReleases ) {
            AEManagedValueLinkedListAppend(&THIS->_releases, THIS->_pendingReleases);
            THIS->_pendingReleases = NULL;
        }
        pthread_mutex_unlock(&THIS->_mutex);
    }
    
    return THIS->_value;
}

#pragma mark - Helpers

- (void)pollReleaseList {
    pthread_mutex_lock(&_mutex);
    linkedlistitem_t * release = _releases;
    if ( release ) {
        while ( release ) {
            [self releaseOldValue:release->data];
            linkedlistitem_t * next = release->next;
            free(release);
            release = next;
        }
        _releases = NULL;
        [self.pollTimer invalidate];
        self.pollTimer = nil;
    }
    pthread_mutex_unlock(&_mutex);
}

- (void)releaseOldValue:(void *)value {
    if ( _isObjectValue ) {
        CFRelease(value);
    } else if ( _releaseBlock ) {
        _releaseBlock(value);
    } else {
        free(value);
    }
}

void AEManagedValueLinkedListAppend(linkedlistitem_t ** list, linkedlistitem_t * item) {
    while ( *list ) {
        list = &(*list)->next;
    }
    *list = item;
}

@end

@implementation AEManagedValueProxy
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [_target methodSignatureForSelector:selector];
}
- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation setTarget:_target];
    [invocation invoke];
}
@end
