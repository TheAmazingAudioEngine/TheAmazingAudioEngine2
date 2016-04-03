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

@import Foundation;

typedef const void * AEArrayToken; //!< Token for real-thread use

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
@interface AEArray : NSObject

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
 *  return a pointer to this memory. It will be freed automatically once the item is removed from the array.
 *
 * @param block The block mapping between objects and stored information, or nil to get the same behaviour
 *  as the default initializer.
 */
- (instancetype _Nullable)initWithCustomMapping:(void * _Nonnull(^ _Nullable)(id _Nonnull item))block;

/*!
 * Update the array by copying the contents of the given NSArray
 *
 *  New values will be retained, and old values will be released in a thread-safe manner.
 */
- (void)updateWithContentsOfArray:(NSArray * _Nonnull)array;

/*!
 * Get the array token, for use on realtime audio thread
 *
 *  In order to access this class on the audio thread, you should first use AEArrayGetToken
 *  to obtain a token for accessing the object. Then, pass that token to AEArrayGetCount or
 *  AEArrayGetItem. The token remains valid until the next time AEArrayGetToken is called,
 *  after which the array values may differ. Consequently, it is advised that AEArrayGetToken
 *  is called only once per render loop.
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
 * @param array The array
 * @param index The item index
 * @return Item at the given index
 */
void * _Nullable AEArrayGetItem(AEArrayToken _Nonnull token, int index);

/*!
 * Enumerate object types in the array
 *
 *  This convenience macro provides the ability to enumerate the objects
 *  in the array, in a realtime-thread safe fashion.
 *
 *  Note: This macro calls AEArrayGetToken to access the array. Consequently, it is not
 *  recommended for use when you need to access the array in addition to this enumeration.
 *
 * @param array The array
 * @param type The object type
 * @param varname Name of object variable for inner loop
 * @param what Inner loop implementation
 */
#define AEArrayEnumerateObjects(array, type, varname, what) { \
    AEArrayToken _token = AEArrayGetToken(array); \
    int _count = AEArrayGetCount(_token); \
    for ( int _i=0; _i < _count; _i++ ) { \
        __unsafe_unretained type varname = (__bridge type)AEArrayGetItem(_token, _i); \
        { what; } \
    } \
}

/*!
 * Enumerate pointer types in the array
 *
 *  This convenience macro provides the ability to enumerate the pointers
 *  in the array, in a realtime-thread safe fashion. It differs from AEArrayEnumerateObjects
 *  in that it is designed for use with pointer types, rather than objects.
 *
 *  Note: This macro calls AEArrayGetToken to access the array. Consequently, it is not
 *  recommended for use when you need to access the array in addition to this enumeration.
 *
 * @param array The array
 * @param type The pointer type (e.g. struct myStruct *)
 * @param varname Name of pointer variable for inner loop
 * @param what Inner loop implementation
 */
#define AEArrayEnumeratePointers(array, type, varname, what) { \
    AEArrayToken _token = AEArrayGetToken(array); \
    int _count = AEArrayGetCount(_token); \
    for ( int _i=0; _i < _count; _i++ ) { \
        type varname = (type)AEArrayGetItem(_token, _i); \
        { what; } \
    } \
}

@property (nonatomic, strong, readonly) NSArray * _Nonnull allValues; //!< Current values
@property (nonatomic, copy) void (^_Nullable releaseBlock)(id _Nonnull item, void * _Nonnull bytes); //!< Block to perform when deleting old items, on main thread. If not specified, will simply use free() to dispose bytes, if pointer differs from original Objective-C pointer.
@end
