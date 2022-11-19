//
//  AEBlockModule.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 15/7/19.
//  Copyright © 2019 A Tasty Pixel. All rights reserved.
//

#import "AEBlockModule.h"
#import "AEManagedValue.h"
#import "AERenderer.h"

@interface AEBlockModule ()
@property (nonatomic, strong) AEManagedValue <AEModuleProcessBlock> * processBlockValue;
@property (nonatomic, strong) AEManagedValue <AEModuleIsActiveBlock> * isActiveBlockValue;
@end

@implementation AEBlockModule
@dynamic processBlock, isActiveBlock;

- (instancetype)initWithRenderer:(AERenderer *)renderer processBlock:(AEModuleProcessBlock)processBlock {
    if ( !(self = [super initWithRenderer:renderer]) ) return nil;
    
    self.processBlockValue = [AEManagedValue new];
    self.isActiveBlockValue = [AEManagedValue new];
    
    self.processBlock = processBlock;
    
    self.processFunction = AEBlockModuleProcess;
    self.isActiveFunction = AEBlockModuleIsActive;
    
    return self;
}

- (void)setProcessBlock:(AEModuleProcessBlock)processBlock {
    self.processBlockValue.objectValue = processBlock;
}

- (AEModuleProcessBlock)processBlock {
    return self.processBlockValue.objectValue;
}

- (void)setIsActiveBlock:(AEModuleIsActiveBlock)isActiveBlock {
    self.isActiveBlockValue.objectValue = isActiveBlock;
}

- (AEModuleIsActiveBlock)isActiveBlock {
    return self.isActiveBlockValue.objectValue;
}

- (void)rendererDidChangeSampleRate {
    if ( self.sampleRateChangedBlock ) {
        self.sampleRateChangedBlock(self.renderer.sampleRate);
    }
}

- (void)rendererDidChangeNumberOfChannels {
    if ( self.rendererChannelCountChangedBlock ) {
        self.rendererChannelCountChangedBlock(self.renderer.numberOfOutputChannels);
    }
}

static void AEBlockModuleProcess(__unsafe_unretained AEBlockModule * THIS, const AERenderContext * context) {
    __unsafe_unretained AEModuleProcessBlock block = (__bridge AEModuleProcessBlock)AEManagedValueGetValue(THIS->_processBlockValue);
    if ( block ) block(context);
}

static BOOL AEBlockModuleIsActive(__unsafe_unretained AEBlockModule * THIS) {
    __unsafe_unretained AEModuleIsActiveBlock block = (__bridge AEModuleIsActiveBlock)AEManagedValueGetValue(THIS->_isActiveBlockValue);
    if ( block ) return block();
    return AEManagedValueGetValue(THIS->_processBlockValue) != NULL;
}



@end
