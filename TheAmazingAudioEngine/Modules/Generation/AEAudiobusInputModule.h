//
//  AEAudiobusInputModule.h
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 11/10/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import <TheAmazingAudioEngine/TheAmazingAudioEngine.h>

@class AEAudioUnitInputModule;
@class ABAudioReceiverPort;

@interface AEAudiobusInputModule : AEModule

/*!
 * Initializer
 *
 * @param renderer The renderer
 * @param port The Audiobus audio receiver port
 * @param input If not NULL, the Remote IO audio unit input to use when the Audiobus port is not in use
 */
- (instancetype)initWithRenderer:(AERenderer *)renderer
               audioReceiverPort:(ABAudioReceiverPort *)port
            audioUnitInputModule:(AEAudioUnitInputModule *)input;

@property (nonatomic, strong, readonly) ABAudioReceiverPort * audioReceiverPort;
@property (nonatomic, strong, readonly) AEAudioUnitInputModule * audioUnitInputModule;
@property (nonatomic) BOOL audiobusEnabled;

@end
