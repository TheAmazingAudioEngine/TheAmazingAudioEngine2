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

// Uncomment the following to report every time we spot something bad, not just the first time
// #define REPORT_EVERY_INFRACTION




void AERealtimeWatchdogUnsafeActivityWarning(const char * activity) {
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

BOOL AERealtimeWatchdogIsOnRealtimeThread() {
    pthread_t thread = pthread_self();
    
    static pthread_t __audioThread = NULL;
    
    if ( __audioThread ) {
        return thread == __audioThread;
    }
    
    char name[21] = {0};
    if ( pthread_getname_np(thread, name, sizeof(name)) == 0 && !strcmp(name, "AURemoteIO::IOThread") ) {
        __audioThread = thread;
        return YES;
    }
    
    return NO;
}





#pragma mark - Overrides

// Signatures for the functions we'll override
typedef void * (*malloc_t)(size_t);
typedef void (*free_t)(void*);
typedef id (*objc_storeStrong_t)(id *object, id value);
typedef id (*objc_msgSend_t)(void);
typedef int (*pthread_mutex_lock_t)(pthread_mutex_t *);
typedef int (*objc_sync_enter_t)(id obj);

void * malloc(size_t sz) {
    static malloc_t funcptr = NULL;
    if ( !funcptr ) {
        funcptr = (malloc_t) dlsym(RTLD_NEXT, "malloc");
    }
    if ( AERealtimeWatchdogIsOnRealtimeThread() ) {
        AERealtimeWatchdogUnsafeActivityWarning("malloc");
    }
    return funcptr(sz);
}

void free(void *p) {
    static free_t funcptr = NULL;
    if ( !funcptr ) {
        funcptr = (free_t) dlsym(RTLD_NEXT, "free");
    };
    if ( AERealtimeWatchdogIsOnRealtimeThread() ) {
        AERealtimeWatchdogUnsafeActivityWarning("free");
    }
    funcptr(p);
}

int pthread_mutex_lock(pthread_mutex_t * mutex) {
    static pthread_mutex_lock_t funcptr = NULL;
    if ( !funcptr ) {
        funcptr = (pthread_mutex_lock_t) dlsym(RTLD_NEXT, "pthread_mutex_lock");
    };
    if ( AERealtimeWatchdogIsOnRealtimeThread() ) {
        AERealtimeWatchdogUnsafeActivityWarning("pthread_mutex_lock");
    }
    return funcptr(mutex);
}

int objc_sync_enter(id obj) {
    static objc_sync_enter_t funcptr = NULL;
    if ( !funcptr ) {
        funcptr = (objc_sync_enter_t) dlsym(RTLD_NEXT, "objc_sync_enter");
    };
    if ( AERealtimeWatchdogIsOnRealtimeThread() ) {
        AERealtimeWatchdogUnsafeActivityWarning("@synchronized block");
    }
    return funcptr(obj);
}

id objc_storeStrong(id * object, id value) {
    static objc_storeStrong_t funcptr = NULL;
    if ( !funcptr ) {
        funcptr = (objc_storeStrong_t) dlsym(RTLD_NEXT, "objc_storeStrong");
    };
    if ( AERealtimeWatchdogIsOnRealtimeThread() ) {
        AERealtimeWatchdogUnsafeActivityWarning("object retain");
    }
    return funcptr(object,value);
}

objc_msgSend_t AERealtimeWatchdogLookupMsgSendAndWarn() {
    // This method is called by our objc_msgSend implementation
    static objc_msgSend_t funcptr = NULL;
    if ( !funcptr ) {
        funcptr = (objc_msgSend_t) dlsym(RTLD_NEXT, "objc_msgSend");
    };
    if ( AERealtimeWatchdogIsOnRealtimeThread() ) {
        AERealtimeWatchdogUnsafeActivityWarning("message send");
    }
    return funcptr;
}

#endif
