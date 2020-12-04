//
//  AERealtimeWatchdog.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 12/06/2016.
//  Idea by Taylor Holliday
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

#import "AERealtimeWatchdog.h"
#ifdef REALTIME_WATCHDOG_ENABLED

#import <dlfcn.h>
#import <stdio.h>
#import <objc/runtime.h>
#import <pthread.h>
#import <string.h>
#include <sys/socket.h>
#include <dispatch/dispatch.h>

// Uncomment the following to report every time we spot something bad, not just the first time
//#define REPORT_EVERY_INFRACTION




static void AERealtimeWatchdogUnsafeActivityWarning(const char * activity) {
#ifndef REPORT_EVERY_INFRACTION
    static BOOL once = NO;
    if ( !once ) {
        once = YES;
#endif
        
        printf("AERealtimeWatchdog: Caught unsafe %s on realtime thread. Put a breakpoint on %s to debug\n",
               activity, __FUNCTION__);
        
#ifndef REPORT_EVERY_INFRACTION
    }
#endif
}

BOOL AERealtimeWatchdogIsOnRealtimeThread(void);
BOOL AERealtimeWatchdogIsOnRealtimeThread(void) {
    pthread_t thread = pthread_self();
    int policy;
    struct sched_param param;
    if ( pthread_getschedparam(thread, &policy, &param) == 0 && param.sched_priority >= sched_get_priority_max(policy) ) {
        return YES;
    }
    return NO;
}





#pragma mark - Overrides

// Signatures for the functions we'll override
typedef void * (*malloc_t)(size_t);
typedef void * (*calloc_t)(size_t, size_t);
typedef void * (*realloc_t)(void *, size_t);
typedef void (*free_t)(void*);
typedef int (*pthread_mutex_lock_t)(pthread_mutex_t *);
typedef int (*pthread_rwlock_wrlock_t)(pthread_rwlock_t *);
typedef int (*pthread_rwlock_rdlock_t)(pthread_rwlock_t *);
typedef int (*objc_sync_enter_t)(id obj);
typedef id (*objc_storeStrong_t)(id *object, id value);
typedef id (*objc_loadWeak_t)(id *object);
typedef id (*objc_storeWeak_t)(id *object, id value);
typedef id (*object_getIvar_t)(id object, Ivar ivar);
typedef id (*objc_msgSend_t)(void);
typedef ssize_t (*send_t)(int socket, const void *buffer, size_t length, int flags);
typedef ssize_t (*sendto_t)(int socket, const void *buffer, size_t length, int flags,
                            const struct sockaddr *dest_addr, socklen_t dest_len);
typedef ssize_t (*recv_t)(int socket, void *buffer, size_t length, int flags);
typedef ssize_t (*recvfrom_t)(int socket, void *restrict buffer, size_t length, int flags,
                              struct sockaddr *restrict address, socklen_t *restrict address_len);
typedef FILE * (*fopen_t)(const char *restrict filename, const char *restrict mode);
typedef size_t (*fread_t)(void *restrict ptr, size_t size, size_t nitems, FILE *restrict stream);
typedef size_t (*fwrite_t)(const void *restrict ptr, size_t size, size_t nitems, FILE *restrict stream);
typedef char * (*fgets_t)(char * restrict str, int size, FILE * restrict stream);
typedef ssize_t (*read_t)(int fildes, void *buf, size_t nbyte);
typedef ssize_t (*pread_t)(int d, void *buf, size_t nbyte, off_t offset);
typedef ssize_t (*write_t)(int fildes, const void *buf, size_t nbyte);
typedef ssize_t (*pwrite_t)(int fildes, const void *buf, size_t nbyte, off_t offset);

typedef void (*dispatch_async_t)(dispatch_queue_t queue, dispatch_block_t block);
typedef void (*dispatch_sync_t)(dispatch_queue_t queue, DISPATCH_NOESCAPE dispatch_block_t block);
typedef void (*dispatch_async_f_t)(dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work);
typedef void (*dispatch_sync_f_t)(dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work);
typedef void (*dispatch_after_t)(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block);
typedef void (*dispatch_after_f_t)(dispatch_time_t when, dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work);
typedef void (*dispatch_barrier_async_t)(dispatch_queue_t queue, dispatch_block_t block);
typedef void (*dispatch_barrier_async_f_t)(dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work);
typedef void (*dispatch_barrier_sync_t)(dispatch_queue_t queue, DISPATCH_NOESCAPE dispatch_block_t block);
typedef void (*dispatch_barrier_sync_f_t)(dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work);

// Overrides

#define CHECK_FUNCTION_MSG(name, msg)                       \
    static name##_t funcptr = NULL;                             \
    static dispatch_once_t onceToken;                            \
    dispatch_once(&onceToken, ^{                                \
        funcptr = (name##_t) dlsym(RTLD_NEXT, #name);        \
    }); \
    if ( AERealtimeWatchdogIsOnRealtimeThread() ) AERealtimeWatchdogUnsafeActivityWarning(msg);

#define CHECK_FUNCTION(name) CHECK_FUNCTION_MSG(name, #name)

void * malloc(size_t sz) {
    CHECK_FUNCTION(malloc);
    return funcptr(sz);
}

void * calloc(size_t count, size_t size) {
    CHECK_FUNCTION(calloc);
    return funcptr(count, size);
}

void * realloc(void * ptr, size_t size) {
    CHECK_FUNCTION(realloc);
    return funcptr(ptr, size);
}

void free(void *p) {
    CHECK_FUNCTION(free);
    funcptr(p);
}

int pthread_mutex_lock(pthread_mutex_t * mutex) {
    CHECK_FUNCTION(pthread_mutex_lock);
    return funcptr(mutex);
}

int pthread_rwlock_wrlock(pthread_rwlock_t * rwlock) {
    CHECK_FUNCTION(pthread_rwlock_wrlock);
    return funcptr(rwlock);
}

int pthread_rwlock_rdlock(pthread_rwlock_t * rwlock) {
    CHECK_FUNCTION(pthread_rwlock_rdlock);
    return funcptr(rwlock);
}

int objc_sync_enter(id obj) {
    CHECK_FUNCTION_MSG(objc_sync_enter, "@synchronized block");
    return funcptr(obj);
}

id objc_storeStrong(id * object, id value);
id objc_storeStrong(id * object, id value) {
    CHECK_FUNCTION_MSG(objc_storeStrong, "object retain");
    return funcptr(object,value);
}

id objc_loadWeak(id * object);
id objc_loadWeak(id * object) {
    CHECK_FUNCTION_MSG(objc_loadWeak, "weak load");
    return funcptr(object);
}

id objc_storeWeak(id * object, id value);
id objc_storeWeak(id * object, id value) {
    CHECK_FUNCTION_MSG(objc_storeWeak, "weak store");
    return funcptr(object,value);
}

id object_getIvar(id object, Ivar value);
id object_getIvar(id object, Ivar value) {
    CHECK_FUNCTION_MSG(object_getIvar, "ivar fetch");
    return funcptr(object,value);
}

objc_msgSend_t AERealtimeWatchdogLookupMsgSendAndWarn(void);
objc_msgSend_t AERealtimeWatchdogLookupMsgSendAndWarn(void) {
    // This method is called by our objc_msgSend implementation
    CHECK_FUNCTION_MSG(objc_msgSend, "message send");
    return funcptr;
}

ssize_t send(int socket, const void *buffer, size_t length, int flags) {
    CHECK_FUNCTION(send);
    return funcptr(socket, buffer, length, flags);
}

ssize_t sendto(int socket, const void *buffer, size_t length, int flags,
               const struct sockaddr *dest_addr, socklen_t dest_len) {
    CHECK_FUNCTION(sendto);
    return funcptr(socket, buffer, length, flags, dest_addr, dest_len);
}

ssize_t recv(int socket, void *buffer, size_t length, int flags) {
    CHECK_FUNCTION(recv);
    return funcptr(socket, buffer, length, flags);
}

ssize_t recvfrom(int socket, void *restrict buffer, size_t length, int flags,
                 struct sockaddr *restrict address, socklen_t *restrict address_len) {
    CHECK_FUNCTION(recvfrom);
    return funcptr(socket, buffer, length, flags, address, address_len);
}

FILE * fopen(const char *restrict filename, const char *restrict mode) {
    CHECK_FUNCTION(fopen);
    return funcptr(filename, mode);
}

size_t fread(void *restrict ptr, size_t size, size_t nitems, FILE *restrict stream) {
    CHECK_FUNCTION(fread);
    return funcptr(ptr, size, nitems, stream);
}

size_t fwrite(const void *restrict ptr, size_t size, size_t nitems, FILE *restrict stream) {
    CHECK_FUNCTION(fwrite);
    return funcptr(ptr, size, nitems, stream);
}

char * fgets(char * restrict str, int size, FILE * restrict stream) {
    CHECK_FUNCTION(fgets);
    return funcptr(str, size, stream);
}

ssize_t read(int fildes, void *buf, size_t nbyte) {
    CHECK_FUNCTION(read);
    return funcptr(fildes, buf, nbyte);
}

ssize_t pread(int d, void *buf, size_t nbyte, off_t offset) {
    CHECK_FUNCTION(pread);
    return funcptr(d, buf, nbyte, offset);
}

ssize_t write(int fildes, const void *buf, size_t nbyte) {
    CHECK_FUNCTION(write);
    return funcptr(fildes, buf, nbyte);
}

ssize_t pwrite(int fildes, const void *buf, size_t nbyte, off_t offset) {
    CHECK_FUNCTION(pwrite);
    return funcptr(fildes, buf, nbyte, offset);
}

void dispatch_async(dispatch_queue_t queue, dispatch_block_t block) {
    CHECK_FUNCTION(dispatch_async);
    funcptr(queue, block);
}

void dispatch_sync(dispatch_queue_t queue, DISPATCH_NOESCAPE dispatch_block_t block) {
    CHECK_FUNCTION(dispatch_sync);
    funcptr(queue, block);
}

void dispatch_async_f(dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work) {
    CHECK_FUNCTION(dispatch_async_f);
    funcptr(queue, context, work);
}

void dispatch_sync_f(dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work) {
    CHECK_FUNCTION(dispatch_sync_f);
    funcptr(queue, context, work);
}

void dispatch_after(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block) {
    CHECK_FUNCTION(dispatch_after);
    funcptr(when, queue, block);
}

void dispatch_after_f(dispatch_time_t when, dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work) {
    CHECK_FUNCTION(dispatch_after_f);
    funcptr(when, queue, context, work);
}

void dispatch_barrier_async(dispatch_queue_t queue, dispatch_block_t block) {
    CHECK_FUNCTION(dispatch_barrier_async);
    funcptr(queue, block);
}

void dispatch_barrier_async_f(dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work) {
    CHECK_FUNCTION(dispatch_barrier_async_f);
    funcptr(queue, context, work);
}

void dispatch_barrier_sync(dispatch_queue_t queue, DISPATCH_NOESCAPE dispatch_block_t block) {
    CHECK_FUNCTION(dispatch_barrier_sync);
    funcptr(queue, block);
}

void dispatch_barrier_sync_f(dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work) {
    CHECK_FUNCTION(dispatch_barrier_sync_f);
    funcptr(queue, context, work);
}

#endif
