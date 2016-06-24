//
//  AEMixerModule.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 7/05/2016.
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


#import "AEMixerModule.h"
#import "AEArray.h"
#import "AEBufferStack.h"
#import "AEUtilities.h"
#import "AEAudioBufferListUtilities.h"

typedef struct {
    __unsafe_unretained AEModule * module;
    float currentVolume;
    float targetVolume;
    float currentBalance;
    float targetBalance;
} AEMixerModuleSubModuleEntry;

@interface AEMixerModule ()
@property (nonatomic, strong) AEArray * array;
@end

@implementation AEMixerModule
@dynamic modules;

- (instancetype)initWithRenderer:(AERenderer *)renderer {
    if ( !(self = [super initWithRenderer:renderer]) ) return nil;
    
    __weak typeof(self) weakSelf = self;
    self.array = [[AEArray alloc] initWithCustomMapping:^void * _Nonnull(id _Nonnull item) {
        return [weakSelf newEntryForModule:item volume:1.0 balance:0.0];
    }];
    [self.array updateWithContentsOfArray:@[]];
    
    self.numberOfChannels = 2;
    
    self.processFunction = AEMixerModuleProcess;
    
    return self;
}

- (void)addModule:(AEModule *)module {
    [self addModule:module volume:1.0 balance:0.0];
}

- (void)addModule:(AEModule *)module volume:(float)volume balance:(float)balance {
    [self.array updateWithContentsOfArray:[self.array.allValues arrayByAddingObject:module]
                            customMapping:^void * _Nonnull(id  _Nonnull item, int index) {
                                // Use a custom mapping to apply volume and balance to new entry
                                return [self newEntryForModule:item volume:volume balance:balance];
                            }];
}

- (void)removeModule:(AEModule *)module {
    NSMutableArray * array = self.array.allValues.mutableCopy;
    [array removeObject:module];
    [self.array updateWithContentsOfArray:array];
}

- (NSArray *)modules {
    return self.array.allValues;
}

- (void)setModules:(NSArray *)modules {
    [self.array updateWithContentsOfArray:modules];
}

- (void)setVolume:(float)volume balance:(float)balance forModule:(AEModule *)module {
    AEMixerModuleSubModuleEntry * entry = [self.array pointerValueForObject:module];
    if ( entry ) {
        entry->targetVolume = volume;
        entry->targetBalance = balance;
    }
}

- (void)getVolume:(float *)volume balance:(float *)balance forModule:(AEModule *)module {
    AEMixerModuleSubModuleEntry * entry = [self.array pointerValueForObject:module];
    if ( entry ) {
        *volume = entry->targetVolume;
        *balance = entry->targetBalance;
    }
}

static void AEMixerModuleProcess(__unsafe_unretained AEMixerModule * self, const AERenderContext * _Nonnull context) {
    const AudioBufferList * abl = AEBufferStackPushWithChannels(context->stack, 1, self->_numberOfChannels);
    if ( !abl ) return;
    
    // Silence buffer first
    AEAudioBufferListSilence(abl, 0, context->frames);
    
    // Run each module, applying volume/balance then mixing into our output buffer
    AEArrayEnumeratePointers(self->_array, AEMixerModuleSubModuleEntry *, entry) {
        
        if ( !AEModuleIsActive(entry->module) ) {
            // Module is idle; skip (and skip the volume/balance ramp, too)
            entry->currentVolume = entry->targetVolume;
            entry->currentBalance = entry->targetBalance;
            continue;
        }
        
        #ifdef DEBUG
        int priorStackDepth = AEBufferStackCount(context->stack);
        #endif
        
        AEModuleProcess(entry->module, context);
        
        #ifdef DEBUG
        if ( AEBufferStackCount(context->stack) != priorStackDepth+1 ) {
            if ( AERateLimit() ) {
                printf("A module within AEMixerModule didn't push a buffer! Sure it's a generator?\n");
            }
            continue;
        }
        #endif
        
        AEBufferStackApplyFaders(context->stack,
                                 entry->targetVolume, &entry->currentVolume,
                                 entry->targetBalance, &entry->currentBalance);
        AEBufferStackMix(context->stack, 2);
    }
}

- (AEMixerModuleSubModuleEntry *)newEntryForModule:(AEModule *)module volume:(float)volume balance:(float)balance {
    AEMixerModuleSubModuleEntry * entry = malloc(sizeof(AEMixerModuleSubModuleEntry));
    entry->module = module;
    entry->currentVolume = volume;
    entry->targetVolume = volume;
    entry->currentBalance = balance;
    entry->targetBalance = balance;
    return entry;
}

@end
