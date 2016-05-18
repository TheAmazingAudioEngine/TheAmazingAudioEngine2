//
//  AEArray.h
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

typedef const void * AEArrayToken; //!< Token for real-thread use

/*!
 * Block for mapping between objects and opaque pointer values
 *
 *  Pass a block matching this type to AEArray's initializer in order to map
 *  between objects in the array and an arbitrary data block; this can be a pointer
 *  to an allocated C structure, for example, or any other collection of bytes.
 *
 *  The block is invoked on the main thread whenever a new item is added to the array
 *  during an update. You should allocate the memory you need, set the contents, and
 *  return a pointer to this memory. It will be freed automatically once the item is 
 *  removed from the array, unless you provide a custom @link AEArray::releaseBlock releaseBlock @endlink.
 *
 * @param item The original object
 * @return Pointer to an allocated memory region
 */
typedef void * _Nullable (^AEArrayCustomMappingBlock)(id _Nonnull item);

/*!
 * Block for mapping between objects and opaque pointer values, for use with AEArray's
 * @link AEArray::updateWithContentsOfArray:customMapping: updateWithContentsOfArray:customMapping: @endlink 
 * method.
 *
 *  See documentation for AEArrayCustomMappingBlock for details.
 *
 * @param item The original object
 * @return Pointer to an allocated memory region
 */
typedef void * _Nullable (^AEArrayIndexedCustomMappingBlock)(id _Nonnull item, int index);

/*!
 * Block for releasing allocated values
 *
 *  Assign a block matching this type to AEArray's releaseBlock property to provide
 *  a custom release implementation. Use this if you are using a custom mapping block
 *  and need to perform extra cleanup tasks beyond simply freeing the returned pointer.
 *
 * @param item The original object
 * @param bytes The bytes originally returned from the custom mapping block
 */
typedef void (^AEArrayReleaseBlock)(id _Nonnull item, void * _Nonnull bytes);

/*!
 * Real-time safe array
 *
 *  Use this class to manage access to an array of items from the audio thread. Accesses
 *  are both thread-safe and realtime-safe.
 *
 *  Using the default initializer results in an instance that manages an array of object
 *  references. You can cast the items returned directly to an __unsafe_unretained Objective-C type.
 *
 *  Alternatively, you can use the custom initializer to provide a block that maps between
 *  objects and any collection of bytes, such as a C structure.
 *
 *  When accessing the array on the realtime audio thread, you must first obtain a token to access
 *  the array using @link AEArrayGetToken @endlink. This token remains valid until the next time
 *  AEArrayGetToken is called. Pass the token to @link AEArrayGetCount @endlink and 
 *  @link AEArrayGetItem @endlink to access array items.
 *
 *  Remember to use the __unsafe_unretained directive to avoid ARC-triggered retains on the
 *  audio thread if using this class to manage Objective-C objects, and only interact with such objects
 *  via C functions they provide, not via Objective-C methods.
 */
@interface AEArray : NSObject <NSFastEnumeration>

/*!
 * Default initializer
 *
 *  This configures the instance to manage an array of object references. You can cast the items 
 *  returned directly to an __unsafe_unretained Objective-C type.
 */
- (instancetype _Nullable)init;

/*!
 * Custom initializer
 *
 *  This allows you to provide a block that maps between the given object and a C structure, or any
 *  other collection of bytes. The block will be invoked on the main thread whenever a new item is
 *  added to the array during an update. You should allocate the memory you need, set the contents, and 
 *  return a pointer to this memory. It will be freed automatically once the item is removed from the array,
 *  unless you provide a custom releaseBlock.
 *
 * @param block The block mapping between objects and stored information, or nil to get the same behaviour
 *  as the default initializer.
 */
- (instancetype _Nullable)initWithCustomMapping:(AEArrayCustomMappingBlock _Nullable)block;

/*!
 * Update the array by copying the contents of the given NSArray
 *
 *  New values will be retained, and old values will be released in a thread-safe manner.
 *  If you have provided a custom mapping when initializing the instance, the custom mapping
 *  block will be called for all new values. Values in the new array that are also present in
 *  the prior array value will be maintained, and old values not present in the new array are released.
 *
 *  Using this method within an AEManagedValue
 *  @link AEManagedValue::performAtomicBatchUpdate: performAtomicBatchUpdate @endlink block
 *  will cause the update to occur atomically along with any other value updates.
 *
 * @param array Array of values
 */
- (void)updateWithContentsOfArray:(NSArray * _Nonnull)array;

/*!
 * Update the array, with custom mapping
 *
 *  If you provide a custom mapping using this method, it will be used instead of the one
 *  provided when initializing this instance (if any), for all new values not present in the
 *  previous array value. This allows you to capture state particular to an individual
 *  update at the time of calling this method.
 *
 *  New values will be retained, and old values will be released in a thread-safe manner.
 *
 *  Using this method within an AEManagedValue
 *  @link AEManagedValue::performAtomicBatchUpdate: performAtomicBatchUpdate @endlink block
 *  will cause the update to occur atomically along with any other value updates.
 *
 * @param array Array of values
 * @param block The block mapping between objects and stored information
 */
- (void)updateWithContentsOfArray:(NSArray * _Nonnull)array customMapping:(AEArrayIndexedCustomMappingBlock _Nullable)block;

/*!
 * Get the pointer value at the given index of the C array, as seen by the audio thread
 *
 *  This method allows you to access the same values as the audio thread; if you are using
 *  a mapping block to create structures that correspond to objects in the original array,
 *  for instance, then you may access these structures using this method.
 *
 *  Note: Take care if modifying these values, as they may also be accessed from the audio 
 *  thread
 *
 * @param index Index of the item to retrieve
 * @return Pointer to the item at the given index
 */
- (void * _Nullable)pointerValueAtIndex:(int)index;

/*!
 * Get the pointer value associated with the given object, if any
 *
 *  This method allows you to access the same values as the audio thread; if you are using
 *  a mapping block to create structures that correspond to objects in the original array,
 *  for instance, then you may access these structures using this method.
 *
 *  Note: Take care if modifying these values, as they may also be accessed from the audio
 *  thread
 *
 * @param object The object
 * @return Pointer to the item corresponding to the object
 */
- (void * _Nullable)pointerValueForObject:(id _Nonnull)object;


/*!
 * Access objects using subscript syntax
 */
- (id _Nullable)objectAtIndexedSubscript:(NSUInteger)idx;

/*!
 * Get the array token, for use on realtime audio thread
 *
 *  In order to access this class on the audio thread, you should first use AEArrayGetToken
 *  to obtain a token for accessing the object. Then, pass that token to AEArrayGetCount or
 *  AEArrayGetItem. The token remains valid until the next time AEArrayGetToken is called,
 *  after which the array values may differ. Consequently, it is advised that AEArrayGetToken
 *  is called only once per render loop.
 *
 *  Note: Do not use this function on the main thread
 *
 * @param array The array
 * @return The token, for use with other accessors
 */
AEArrayToken _Nonnull AEArrayGetToken(__unsafe_unretained AEArray * _Nonnull array);

/*!
 * Get the number of items in the array
 *
 * @param token The array token, as returned from AEArrayGetToken
 * @return Item count
 */
int AEArrayGetCount(AEArrayToken _Nonnull token);

/*!
 * Get the item at a given index
 *
 * @param token The array token, as returned from AEArrayGetToken
 * @param index The item index
 * @return Item at the given index
 */
void * _Nullable AEArrayGetItem(AEArrayToken _Nonnull token, int index);

/*!
 * Enumerate object types in the array, for use on audio thread
 *
 *  This convenience macro provides the ability to enumerate the objects
 *  in the array, in a realtime-thread safe fashion.
 *
 *  Note: This macro calls AEArrayGetToken to access the array. Consequently, it is not
 *  recommended for use when you need to access the array in addition to this enumeration.
 *
 *  Note: Do not use this macro on the main thread
 *
 * @param array The array
 * @param type The object type
 * @param varname Name of object variable for inner loop
 * @param inner Inner loop implementation
 */
#define AEArrayEnumerateObjects(array, type, varname, inner) { \
    AEArrayToken _token = AEArrayGetToken(array); \
    int _count = AEArrayGetCount(_token); \
    for ( int _i=0; _i < _count; _i++ ) { \
        __unsafe_unretained type varname = (__bridge type)AEArrayGetItem(_token, _i); \
        { inner; } \
    } \
}

/*!
 * Enumerate pointer types in the array, for use on audio thread
 *
 *  This convenience macro provides the ability to enumerate the pointers
 *  in the array, in a realtime-thread safe fashion. It differs from AEArrayEnumerateObjects
 *  in that it is designed for use with pointer types, rather than objects.
 *
 *  Note: This macro calls AEArrayGetToken to access the array. Consequently, it is not
 *  recommended for use when you need to access the array in addition to this enumeration.
 *
 *  Note: Do not use this macro on the main thread
 *
 * @param array The array
 * @param type The pointer type (e.g. struct myStruct *)
 * @param varname Name of pointer variable for inner loop
 * @param inner Inner loop implementation
 */
#define AEArrayEnumeratePointers(array, type, varname, inner) { \
    AEArrayToken _token = AEArrayGetToken(array); \
    int _count = AEArrayGetCount(_token); \
    for ( int _i=0; _i < _count; _i++ ) { \
        type varname = (type)AEArrayGetItem(_token, _i); \
        { inner; } \
    } \
}

//! Number of values in array
@property (nonatomic, readonly) int count;

//! Current object values
@property (nonatomic, strong, readonly) NSArray * _Nonnull allValues;

//! Block to perform when deleting old items, on main thread. If not specified, will simply use
//! free() to dispose bytes, if pointer differs from original Objective-C pointer.
@property (nonatomic, copy) AEArrayReleaseBlock _Nullable releaseBlock;

@end

#ifdef __cplusplus
}
#endif
