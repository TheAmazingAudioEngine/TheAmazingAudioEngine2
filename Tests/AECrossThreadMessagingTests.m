//
//  AECrossThreadMessagingTests.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 29/04/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "AEMainThreadEndpoint.h"
#import "AEAudioThreadEndpoint.h"
#import "AEMessageQueue.h"

typedef struct {
    int value1;
    int value2;
} AECrossThreadMessagingTestsTestStruct;

@interface AECrossThreadMessagingTests : XCTestCase
@property (nonatomic) int mainThreadMessageValue1;
@property (nonatomic, weak) id mainThreadMessageValue2;
@property (nonatomic) AECrossThreadMessagingTestsTestStruct mainThreadMessageValue3;
@property (nonatomic) NSData * mainThreadMessageValue4;
@end

@implementation AECrossThreadMessagingTests

- (void)testMainThreadEndpointMessaging {
    NSMutableArray * messages = [NSMutableArray array];
    AEMainThreadEndpoint * endpoint = [[AEMainThreadEndpoint alloc] initWithHandler:^(const void *data, size_t length) {
        [messages addObject:[NSData dataWithBytes:data length:length]];
    }];
    
    AEMainThreadEndpointSend(endpoint, NULL, 0);
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:endpoint.pollInterval]];
    
    XCTAssertEqualObjects(messages, (@[[NSData dataWithBytes:NULL length:0]]));
    [messages removeAllObjects];
    
    int value1 = 1;
    int value2 = 2;
    double value3 = 3;
    AEMainThreadEndpointSend(endpoint, &value1, sizeof(value1));
    AEMainThreadEndpointSend(endpoint, &value2, sizeof(value2));
    AEMainThreadEndpointSend(endpoint, &value3, sizeof(value3));
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:endpoint.pollInterval]];
    
    XCTAssertEqualObjects(messages, (@[[NSData dataWithBytes:&value1 length:sizeof(value1)], [NSData dataWithBytes:&value2 length:sizeof(value2)], [NSData dataWithBytes:&value3 length:sizeof(value3)]]));
    [messages removeAllObjects];
    
    AEMainThreadEndpointSend(endpoint, &value1, sizeof(value1));
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:endpoint.pollInterval]];
    
    XCTAssertEqualObjects(messages, (@[[NSData dataWithBytes:&value1 length:sizeof(value1)]]));
    [messages removeAllObjects];
    
    __weak AEMainThreadEndpoint * weakEndpoint = endpoint;
    endpoint = nil;
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    
    XCTAssertNil(weakEndpoint);
}

- (void)testAudioThreadEndpointMessaging {
    NSMutableArray * messages = [NSMutableArray array];
    AEAudioThreadEndpoint * endpoint = [[AEAudioThreadEndpoint alloc] initWithHandler:^(const void *data, size_t length) {
        [messages addObject:[NSData dataWithBytes:data length:length]];
    }];
    
    [endpoint sendBytes:NULL length:0];
    AEAudioThreadEndpointPoll(endpoint);
    
    XCTAssertEqualObjects(messages, (@[[NSData dataWithBytes:NULL length:0]]));
    [messages removeAllObjects];
    
    int value1 = 1;
    int value2 = 2;
    double value3 = 3;
    [endpoint sendBytes:&value1 length:sizeof(value1)];
    [endpoint sendBytes:&value2 length:sizeof(value2)];
    [endpoint sendBytes:&value3 length:sizeof(value3)];
    AEAudioThreadEndpointPoll(endpoint);
    
    XCTAssertEqualObjects(messages, (@[[NSData dataWithBytes:&value1 length:sizeof(value1)], [NSData dataWithBytes:&value2 length:sizeof(value2)], [NSData dataWithBytes:&value3 length:sizeof(value3)]]));
    [messages removeAllObjects];
    
    [endpoint beginMessageGroup];
    [endpoint sendBytes:&value1 length:sizeof(value1)];
    [endpoint sendBytes:&value2 length:sizeof(value2)];
    
    AEAudioThreadEndpointPoll(endpoint);
    XCTAssertEqualObjects(messages, (@[]));
    
    [endpoint sendBytes:&value3 length:sizeof(value3)];
    
    [endpoint endMessageGroup];
    
    AEAudioThreadEndpointPoll(endpoint);
    
    XCTAssertEqualObjects(messages, (@[[NSData dataWithBytes:&value1 length:sizeof(value1)], [NSData dataWithBytes:&value2 length:sizeof(value2)], [NSData dataWithBytes:&value3 length:sizeof(value3)]]));
    [messages removeAllObjects];
    
    
    [endpoint sendBytes:&value1 length:sizeof(value1)];
    AEAudioThreadEndpointPoll(endpoint);
    
    XCTAssertEqualObjects(messages, (@[[NSData dataWithBytes:&value1 length:sizeof(value1)]]));
    [messages removeAllObjects];
}

- (void)testMessageQueueAudioThreadMessaging {
    AEMessageQueue * queue = [AEMessageQueue new];
    
    __block BOOL hitBlock = NO;
    __block BOOL hitCompletionBlock = NO;
    id object = [NSObject new];
    @autoreleasepool {
        [queue performBlockOnAudioThread:^{
            hitBlock = YES;
            (void)object;
        } completionBlock:^{
            hitCompletionBlock = YES;
            (void)object;
        }];
    }
    __weak id weakObject = object;
    object = nil;
    
    XCTAssertNotNil(weakObject);
    
    AEMessageQueuePoll(queue);
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:queue.pollInterval]];
    
    XCTAssertTrue(hitBlock);
    XCTAssertTrue(hitCompletionBlock);
    
    XCTAssertNil(weakObject);
    
    __weak id weakQueue = queue;
    queue = nil;
    
    XCTAssertNil(weakQueue);
}

- (void)testMessageQueueMainThreadMessaging {
    AEMessageQueue * queue = [AEMessageQueue new];
    
    [self sendMainThreadMessage:queue];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:queue.pollInterval]];
    
    XCTAssertEqual(self.mainThreadMessageValue1, 1);
    XCTAssertEqual(self.mainThreadMessageValue2, self);
    XCTAssertTrue(!memcmp(&_mainThreadMessageValue3, &(AECrossThreadMessagingTestsTestStruct){1, 2},
                          sizeof(AECrossThreadMessagingTestsTestStruct)));
    
    int data[2] = {1, 2};
    XCTAssertEqualObjects(self.mainThreadMessageValue4, [NSData dataWithBytes:data length:sizeof(data)]);
    
    AEMessageQueuePerformSelectorOnMainThread(queue, self, @selector(mainThreadMessageTestWithNoArguments), AEArgumentNone);
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:queue.pollInterval]];
    
    XCTAssertEqual(self.mainThreadMessageValue1, 3);
}

- (void)sendMainThreadMessage:(AEMessageQueue*)queue {
    int data[2] = {1, 2};
    AEMessageQueuePerformSelectorOnMainThread(queue, self,
                                              @selector(mainThreadMessageTestWithValue1:value2:value3:value4:length:),
                                              AEArgumentScalar(1),
                                              AEArgumentScalar(self),
                                              AEArgumentStruct(((AECrossThreadMessagingTestsTestStruct){1, 2})),
                                              AEArgumentData(data, sizeof(data)),
                                              AEArgumentScalar(sizeof(data)),
                                              AEArgumentNone);
}

- (void)mainThreadMessageTestWithValue1:(int)value1
                                 value2:(id)value2
                                 value3:(AECrossThreadMessagingTestsTestStruct)value3
                                 value4:(const char *)data
                                 length:(size_t)dataLength {
    self.mainThreadMessageValue1 = value1;
    self.mainThreadMessageValue2 = value2;
    self.mainThreadMessageValue3 = value3;
    self.mainThreadMessageValue4 = [NSData dataWithBytes:data length:dataLength];
}

- (void)mainThreadMessageTestWithNoArguments {
    self.mainThreadMessageValue1 = 3;
}

@end
