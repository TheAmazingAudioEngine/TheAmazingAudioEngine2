//
//  Tests.m
//  Tests
//
//  Created by Michael Tyson on 23/03/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "AEArray.h"
#import "AEManagedValue.h"

@interface AEArrayTests : XCTestCase

@end

@implementation AEArrayTests

- (void)testItemLifecycle {
    AEArray * array = [AEArray new];
    __weak NSArray * weakNSArray;
    
    @autoreleasepool {
        [array updateWithContentsOfArray:@[@(1), @(2), @(3)]];
        weakNSArray = array.allValues;
    }
    
    XCTAssertNotNil(weakNSArray);
    
    AEArrayToken token = AEArrayGetToken(array);
    XCTAssertEqual(AEArrayGetCount(token), 3);
    XCTAssertEqualObjects((__bridge id)AEArrayGetItem(token, 0), @(1));
    XCTAssertEqualObjects((__bridge id)AEArrayGetItem(token, 1), @(2));
    XCTAssertEqualObjects((__bridge id)AEArrayGetItem(token, 2), @(3));
    
    int i=1;
    AEArrayEnumerateObjects(array, NSNumber *, number) {
        XCTAssertEqualObjects(number, @(i++));
    }
    
    i=1;
    AEArrayEnumeratePointers(array, void *, number) {
        XCTAssertEqualObjects((__bridge NSNumber*)number, @(i++));
    }
    
    @autoreleasepool {
        [array updateWithContentsOfArray:@[@(4), @(5)]];
    }
    
    AEArrayGetToken(array);
    AEManagedValueCommitPendingUpdates();
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
    
    XCTAssertNil(weakNSArray);
    
    @autoreleasepool {
        weakNSArray = array.allValues;
    }
    
    token = AEArrayGetToken(array);
    XCTAssertEqual(AEArrayGetCount(token), 2);
    XCTAssertEqualObjects((__bridge id)AEArrayGetItem(token, 0), @(4));
    XCTAssertEqualObjects((__bridge id)AEArrayGetItem(token, 1), @(5));
    
    array = nil;
    
    XCTAssertNil(weakNSArray);
}

struct testStruct {
    int value;
    int otherValue;
};

- (void)testMapping {
    AEArray * array = [[AEArray alloc] initWithCustomMapping:^void *(id item) {
        struct testStruct * value = calloc(sizeof(struct testStruct), 1);
        value->value = ((NSNumber*)item).intValue;
        return value;
    }];
    
    NSMutableArray * released = [NSMutableArray array];
    array.releaseBlock = ^(id item, void * bytes) {
        [released addObject:item];
        free(bytes);
    };
    
    [array updateWithContentsOfArray:@[@(1), @(2), @(3)]];
    
    AEArrayToken token = AEArrayGetToken(array);
    XCTAssertEqual(AEArrayGetCount(token), 3);
    XCTAssertEqual(((struct testStruct*)AEArrayGetItem(token, 0))->value, 1);
    XCTAssertEqual(((struct testStruct*)AEArrayGetItem(token, 1))->value, 2);
    XCTAssertEqual(((struct testStruct*)AEArrayGetItem(token, 2))->value, 3);
    
    ((struct testStruct*)AEArrayGetItem(token, 0))->otherValue = 10;
    
    [array updateWithContentsOfArray:@[@(4), @(1)]];
    
    token = AEArrayGetToken(array);
    AEManagedValueCommitPendingUpdates();
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
    
    XCTAssertEqual(AEArrayGetCount(token), 2);
    XCTAssertEqual(((struct testStruct*)AEArrayGetItem(token, 0))->value, 4);
    XCTAssertEqual(((struct testStruct*)AEArrayGetItem(token, 1))->value, 1);
    XCTAssertEqual(((struct testStruct*)AEArrayGetItem(token, 1))->otherValue, 10);
    XCTAssertEqual(((struct testStruct*)[array pointerValueAtIndex:1])->value, 1);
    XCTAssertEqual(((struct testStruct*)[array pointerValueAtIndex:1])->otherValue, 10);
    XCTAssertEqual(((struct testStruct*)[array pointerValueForObject:@(4)])->value, 4);
    XCTAssertEqual(((struct testStruct*)[array pointerValueForObject:@(1)])->value, 1);
    
    [array updateWithContentsOfArray:@[@(1), @(2)]];
    
    NSMutableArray * added = [NSMutableArray array];
    [array updateWithContentsOfArray:@[@(2), @(3)] customMapping:^void * _Nonnull(id  _Nonnull item, int index) {
        [added addObject:@[item, @(index)]];
        struct testStruct * value = calloc(sizeof(struct testStruct), 1);
        value->value = ((NSNumber*)item).intValue;
        return value;
    }];
    
    XCTAssertEqualObjects(added, (@[@[@(3), @(1)]]));
    
    token = AEArrayGetToken(array);
    AEManagedValueCommitPendingUpdates();
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
    
    XCTAssertEqual(AEArrayGetCount(token), 2);
    XCTAssertEqual(((struct testStruct*)AEArrayGetItem(token, 0))->value, 2);
    XCTAssertEqual(((struct testStruct*)AEArrayGetItem(token, 1))->value, 3);
    
    array = nil;
    
    XCTAssertEqualObjects(released, (@[@(2), @(3), @(4), @(1), @(2), @(3)]));
}

@end
