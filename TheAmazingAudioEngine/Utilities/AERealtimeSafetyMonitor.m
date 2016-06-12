//
//  AERealtimeSafetyMonitor.m
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

#import "AERealtimeSafetyMonitor.h"
#import <dlfcn.h>
#import <stdio.h>
#import <objc/runtime.h>
#import <pthread.h>

// #define REPORT_EVERY_INFRACTION // Uncomment to report every time we spot something bad, not just the first time

static pthread_t __audioThread = NULL;

// Signatures for the functions we'll override
typedef void * (*malloc_t)(size_t);
typedef void (*free_t)(void*);
typedef id (*objc_storeStrong_t)(id *object, id value);
typedef id (*objc_msgSend_t)(void);
typedef int (*pthread_mutex_lock_t)(pthread_mutex_t *);
typedef int (*objc_sync_enter_t)(id obj);

void AERealtimeSafetyMonitorInit(pthread_t audioThread) {
    __audioThread = audioThread;
}

void AERealtimeSafetyMonitorUnsafeActivityWarning(const char * activity) {
#ifndef REPORT_EVERY_INFRACTION
    static BOOL once = NO;
    if ( !once ) {
        once = YES;
#endif
        
        printf("AERealtimeSafetyMonitor: Caught unsafe %s on realtime thread. "
               "Put a breakpoint on AERealtimeSafetyMonitorUnsafeActivityWarning to debug\n", activity);
        
#ifndef REPORT_EVERY_INFRACTION
    }
#endif
}

#ifdef REALTIME_SAFETY_MONITOR_ENABLED

objc_msgSend_t AERealtimeSafetyMonitorLookupMsgSendAndWarn() {
    // This method is called by our objc_msgSend implementation
    static objc_msgSend_t funcptr = NULL;
    if ( !funcptr ) {
        funcptr = (objc_msgSend_t) dlsym(RTLD_NEXT, "objc_msgSend");
    };
    if ( __audioThread && pthread_self() == __audioThread ) {
        AERealtimeSafetyMonitorUnsafeActivityWarning("message send");
    }
    return funcptr;
}

#pragma mark - Overrides

void * malloc(size_t sz) {
    static malloc_t funcptr = NULL;
    if ( !funcptr ) {
        funcptr = (malloc_t) dlsym(RTLD_NEXT, "malloc");
    }
    if ( __audioThread && pthread_self() == __audioThread ) {
        AERealtimeSafetyMonitorUnsafeActivityWarning("malloc");
    }
    return funcptr(sz);
}

void free(void *p) {
    static free_t funcptr = NULL;
    if ( !funcptr ) {
        funcptr = (free_t) dlsym(RTLD_NEXT, "free");
    };
    if ( __audioThread && pthread_self() == __audioThread ) {
        AERealtimeSafetyMonitorUnsafeActivityWarning("free");
    }
    funcptr(p);
}

int pthread_mutex_lock(pthread_mutex_t * mutex) {
    static pthread_mutex_lock_t funcptr = NULL;
    if ( !funcptr ) {
        funcptr = (pthread_mutex_lock_t) dlsym(RTLD_NEXT, "pthread_mutex_lock");
    };
    if ( __audioThread && pthread_self() == __audioThread ) {
        AERealtimeSafetyMonitorUnsafeActivityWarning("pthread_mutex_lock");
    }
    return funcptr(mutex);
}

int objc_sync_enter(id obj) {
    static objc_sync_enter_t funcptr = NULL;
    if ( !funcptr ) {
        funcptr = (objc_sync_enter_t) dlsym(RTLD_NEXT, "objc_sync_enter");
    };
    if ( __audioThread && pthread_self() == __audioThread ) {
        AERealtimeSafetyMonitorUnsafeActivityWarning("@synchronized block");
    }
    return funcptr(obj);
}

id objc_storeStrong(id * object, id value) {
    static objc_storeStrong_t funcptr = NULL;
    if ( !funcptr ) {
        funcptr = (objc_storeStrong_t) dlsym(RTLD_NEXT, "objc_storeStrong");
    };
    if ( __audioThread && pthread_self() == __audioThread ) {
        AERealtimeSafetyMonitorUnsafeActivityWarning("object retain");
    }
    return funcptr(object,value);
}

#endif
