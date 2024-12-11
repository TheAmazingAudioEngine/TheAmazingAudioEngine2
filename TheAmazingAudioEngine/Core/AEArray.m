//
//  AEArray.m
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

#import "AEArray.h"
#import "AEManagedValue.h"

typedef struct {
    void * pointer;
    int referenceCount;
} array_entry_t;

typedef struct {
    int count;
    __unsafe_unretained NSPointerArray * objects;
    array_entry_t * entries[1];
} array_t;

@interface AEArrayManagedValue : AEManagedValue
@property (nonatomic, copy) AEArrayReleaseBlock arrayReleaseBlock;
@end

@interface AEArray ()
@property (nonatomic, strong) AEArrayManagedValue * value;
@property (nonatomic, copy) void*(^mappingBlock)(id item);
@end

@implementation AEArray
@dynamic allValues, count, usedOnAudioThread;

- (instancetype)init {
    return [self initWithCustomMapping:nil];
}

- (instancetype)initWithCustomMapping:(AEArrayCustomMappingBlock)block {
    if ( !(self = [super init]) ) return nil;
    self.mappingBlock = block;
    
    self.value = [AEArrayManagedValue new];
    
    array_t * array = (array_t*)calloc(1, sizeof(array_t));
    array->count = 0;
    self.value.pointerValue = array;
    
    return self;
}

- (void)setReleaseBlock:(AEArrayReleaseBlock)releaseBlock {
    _releaseBlock = releaseBlock;
    self.value.arrayReleaseBlock = releaseBlock;
}

- (void)setUsedOnAudioThread:(BOOL)usedOnAudioThread {
    self.value.usedOnAudioThread = usedOnAudioThread;
}

- (BOOL)usedOnAudioThread {
    return self.value.usedOnAudioThread;
}

- (NSArray *)allValues {
    array_t * array = (array_t*)_value.pointerValue;
    return array->objects ? array->objects.allObjects : @[];
}

- (int)count {
    array_t * array = (array_t*)_value.pointerValue;
    return array->count;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len {
    array_t * array = (array_t*)_value.pointerValue;
    return [array->objects countByEnumeratingWithState:state objects:buffer count:len];
}

- (id)objectAtIndexedSubscript:(NSUInteger)idx {
    array_t * array = (array_t*)_value.pointerValue;
    return [array->objects pointerAtIndex:idx];
}

- (void *)pointerValueAtIndex:(int)index {
    array_t * array = (array_t*)_value.pointerValue;
    return index < array->count ? array->entries[index]->pointer : NULL;
}

- (void *)pointerValueForObject:(id)object {
    array_t * array = (array_t*)_value.pointerValue;
    if ( !array->objects ) return NULL;
    NSUInteger index = [array->objects.allObjects indexOfObject:object];
    if ( index == NSNotFound ) return NULL;
    return [self pointerValueAtIndex:(int)index];
}

- (id)objectForPointerValue:(void *)pointer {
    array_t * array = (array_t*)_value.pointerValue;
    for ( int i=0; i<array->count; i++ ) {
        if ( array->entries[i]->pointer == pointer ) {
            return [array->objects pointerAtIndex:i];
        }
    }
    return NULL;
}

- (void)updatePointerValue:(void *)value forObject:(id)object {
    array_t * array = (array_t*)_value.pointerValue;
    if ( !array->objects ) return;
    NSUInteger index = [array->objects.allObjects indexOfObject:object];
    if ( index == NSNotFound || index >= array->count ) return;
    
    size_t size = sizeof(array_t) + (sizeof(void*) * array->count-1);
    array_t * newArray = (array_t*)malloc(size);
    memcpy(newArray, array, size);
    
    newArray->entries[index] = (array_entry_t*)malloc(sizeof(array_entry_t));
    newArray->entries[index]->pointer = value;
    newArray->entries[index]->referenceCount = 1;
    
    for ( int i=0; i<newArray->count; i++ ) {
        if ( i != index ) newArray->entries[i]->referenceCount++;
    }
    
    CFBridgingRetain(newArray->objects);
    
    _value.pointerValue = newArray;
}

- (BOOL)containsObject:(__unsafe_unretained id)object pointerValue:(void **)outPointerValue {
    array_t * array = (array_t*)_value.pointerValue;
    if ( !array->objects ) return NO;
    int index = 0;
    for ( id entry in array->objects ) {
        if ( entry == object ) {
            if ( outPointerValue ) *outPointerValue = [self pointerValueAtIndex:index];
            return YES;
        }
        index++;
    }
    return NO;
}

- (void)updateWithContentsOfArray:(NSArray *)array {
    [self updateWithContentsOfArray:array customMapping:nil completionBlock:nil];
}

- (void)updateWithContentsOfArray:(NSArray *)array completionBlock:(void (^)(void))completionBlock {
    [self updateWithContentsOfArray:array customMapping:nil completionBlock:completionBlock];
}

- (void)updateWithContentsOfArray:(NSArray *)array customMapping:(AEArrayIndexedCustomMappingBlock)block {
    [self updateWithContentsOfArray:array customMapping:block completionBlock:nil];
}

- (void)updateWithContentsOfArray:(NSArray *)array
                    customMapping:(AEArrayIndexedCustomMappingBlock)block
                  completionBlock:(void (^)(void))completionBlock {
    array_t * currentArray = (array_t*)_value.pointerValue;
    NSArray * currentArrayObjects = currentArray && currentArray->objects ? currentArray->objects.allObjects : nil;
    if ( [currentArrayObjects isEqualToArray:array] ) {
        // Arrays are identical - skip
        return;
    }
    
    // Create new array
    array_t * newArray = (array_t*)malloc(sizeof(array_t) + (sizeof(void*) * array.count-1));
    newArray->count = (int)array.count;
    
    NSPointerArray * objects = [NSPointerArray pointerArrayWithOptions:self.useWeakReferences ? NSPointerFunctionsOpaqueMemory : NSPointerFunctionsStrongMemory];
    newArray->objects = objects;
    CFBridgingRetain(objects);
    
    int i=0;
    for ( id item in array ) {
        [objects addPointer:(__bridge void*)item];
        NSUInteger priorIndex = currentArrayObjects ? [currentArrayObjects indexOfObject:item] : NSNotFound;
        if ( priorIndex != NSNotFound ) {
            // Copy value from prior array
            newArray->entries[i] = currentArray->entries[priorIndex];
            newArray->entries[i]->referenceCount++;
        } else {
            // Add new value
            newArray->entries[i] = (array_entry_t*)malloc(sizeof(array_entry_t));
            newArray->entries[i]->pointer = block ? block(item, i) : _mappingBlock ? _mappingBlock(item) : (__bridge void*)item;
            newArray->entries[i]->referenceCount = 1;
        }
        i++;
    }
    
    if ( completionBlock ) {
        [_value setPointerValue:newArray withCompletionBlock:^(void * _Nullable oldValue) {
            completionBlock();
        }];
    } else {
        _value.pointerValue = newArray;
    }
}

#pragma mark - Realtime thread accessors

AEArrayToken AEArrayGetToken(__unsafe_unretained AEArray * THIS) {
    if ( !THIS ) return NULL;
    return AEManagedValueGetValue(THIS->_value);
}

int AEArrayGetCount(AEArrayToken token) {
    if ( !token ) return 0;
    return ((array_t*)token)->count;
}

void * AEArrayGetItem(AEArrayToken token, int index) {
    if ( !token ) return NULL;
    return ((array_t*)token)->entries[index]->pointer;
}

@end

@implementation AEArrayManagedValue

- (instancetype)init {
    if ( !(self = [super init]) ) return nil;
    
    __unsafe_unretained typeof(self) weakSelf = self;
    self.releaseBlock = ^(void * value) {
        array_t * array = (array_t *)value;
        for ( int i=0; i<array->count; i++ ) {
            array->entries[i]->referenceCount--;
            if ( array->entries[i]->referenceCount == 0 ) {
                if ( array->entries[i]->pointer ) {
                    if ( weakSelf.arrayReleaseBlock ) {
                        weakSelf.arrayReleaseBlock([array->objects pointerAtIndex:i], array->entries[i]->pointer);
                    } else if ( array->entries[i]->pointer && array->entries[i]->pointer != [array->objects pointerAtIndex:i] ) {
                        free(array->entries[i]->pointer);
                    }
                }
                free(array->entries[i]);
            }
        }
        if ( array->objects ) CFBridgingRelease((__bridge CFTypeRef)array->objects);
        free(array);
    };
    
    return self;
}

@end
