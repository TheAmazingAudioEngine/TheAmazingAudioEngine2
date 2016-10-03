//
//  AEManagedValueTests.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 5/04/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "AEManagedValue.h"

@interface AEManagedValueTests : XCTestCase

@end

@implementation AEManagedValueTests

- (void)testUpdateAndRelease {
    AEManagedValue * value = [AEManagedValue new];
    __weak id weakRef = nil;
    
    // Set value, verify
    @autoreleasepool {
        value.objectValue = [[NSMutableString alloc] initWithFormat:@"%d", 1];
        weakRef = value.objectValue;
        
        XCTAssertEqualObjects(value.objectValue, @"1");
        XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value), @"1");
    }
    
    // Verify object still alive
    XCTAssertNotNil(weakRef);
    
    // Change value, verify
    @autoreleasepool {
        value.objectValue = [[NSMutableString alloc] initWithFormat:@"%d", 2];
    
        XCTAssertEqualObjects(value.objectValue, @"2");
        XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value), @"2");
        AEManagedValueCommitPendingUpdates();
    }
    
    // Allow release timer to run
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    
    // Ensure prior value released
    XCTAssertNil(weakRef);
    
    // Set new values, verify
    __weak id weakRef2 = nil;
    __weak id weakRef3 = nil;
    @autoreleasepool {
        weakRef = value.objectValue;
        value.objectValue = [[NSMutableString alloc] initWithFormat:@"%d", 3];
        
        XCTAssertEqualObjects(value.objectValue, @"3");
        XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value), @"3");
        
        weakRef2 = value.objectValue;
        value.objectValue = [[NSMutableString alloc] initWithFormat:@"%d", 4];
        
        XCTAssertEqualObjects(value.objectValue, @"4");
        XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value), @"4");
        
        weakRef3 = value.objectValue;
        value.objectValue = [[NSMutableString alloc] initWithFormat:@"%d", 5];
        AEManagedValueCommitPendingUpdates();
    }
    
    // Run release timer
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    
    // Make sure old values released
    XCTAssertNil(weakRef);
    XCTAssertNil(weakRef2);
    XCTAssertNil(weakRef3);
    
    @autoreleasepool {
        weakRef = value.objectValue;
        value = nil;
    }
    
    // Make sure value released after dealloc
    XCTAssertNil(weakRef);
}

- (void)testAtomicBatchUpdate {
    AEManagedValue * value1 = [AEManagedValue new];
    AEManagedValue * value2 = [AEManagedValue new];
    AEManagedValue * value3 = [AEManagedValue new];
    
    @autoreleasepool {
        __weak id weakRef1 = nil;
        __weak id weakRef2 = nil;
        
        @autoreleasepool {
            // Assign initial values
            value1.objectValue = [[NSMutableString alloc] initWithFormat:@"%d", 1];
            value2.objectValue = [[NSMutableString alloc] initWithFormat:@"%d", 2];
            int * ptr = malloc(sizeof(int)); *ptr = 3;
            value3.pointerValue = ptr;
            weakRef1 = value1.objectValue;
            weakRef2 = value2.objectValue;
        }
        
        // Assign new values in batch
        [AEManagedValue performAtomicBatchUpdate:^{
            // Verify old values still present on C interface
            XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value1), @"1");
            XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value2), @"2");
            XCTAssertEqual(*((int*)AEManagedValueGetValue(value3)), 3);
            
            @autoreleasepool {
                value1.objectValue = [[NSMutableString alloc] initWithFormat:@"%d", 4];
                [AEManagedValue performAtomicBatchUpdate:^{
                    value2.objectValue = [[NSMutableString alloc] initWithFormat:@"%d", 5];
                    int * ptr = malloc(sizeof(int)); *ptr = 6;
                    value3.pointerValue = ptr;
                }];
            
                // Verify new values visible on Obj-C interface
                XCTAssertEqualObjects(value1.objectValue, @"4");
                XCTAssertEqualObjects(value2.objectValue, @"5");
                XCTAssertEqual(*((int*)value3.pointerValue), 6);
            }
            
            // Verify old values still present on C interface
            XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value1), @"1");
            XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value2), @"2");
            XCTAssertEqual(*((int*)AEManagedValueGetValue(value3)), 3);
        }];
        
        // Verify old values still present on C interface
        XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value1), @"1");
        XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value2), @"2");
        XCTAssertEqual(*((int*)AEManagedValueGetValue(value3)), 3);
        
        // Now commit updates (this is normally done at the start of the main render loop)
        AEManagedValueCommitPendingUpdates();
        
        // After batch update, ensure new values present on C interface
        XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value1), @"4");
        XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value2), @"5");
        XCTAssertEqual(*((int*)AEManagedValueGetValue(value3)), 6);
        
        // Run release timer
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
        
        // Make sure both old values released
        XCTAssertNil(weakRef1);
        XCTAssertNil(weakRef2);
        
        // Repeat - this time, perform two atomic batch updates in between commits
        @autoreleasepool {
            weakRef1 = value1.objectValue;
            weakRef2 = value2.objectValue;
        }
        
        // Assign new values in batch
        [AEManagedValue performAtomicBatchUpdate:^{
            // Verify old values still present on C interface
            XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value1), @"4");
            XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value2), @"5");
            XCTAssertEqual(*((int*)AEManagedValueGetValue(value3)), 6);
            
            @autoreleasepool {
                [AEManagedValue performAtomicBatchUpdate:^{
                    value1.objectValue = [[NSMutableString alloc] initWithFormat:@"%d", 7];
                }];
                value2.objectValue = [[NSMutableString alloc] initWithFormat:@"%d", 8];
                int * ptr = malloc(sizeof(int)); *ptr = 9;
                value3.pointerValue = ptr;
            }
            
            // Verify new values visible on Obj-C interface
            XCTAssertEqualObjects(value1.objectValue, @"7");
            XCTAssertEqualObjects(value2.objectValue, @"8");
            XCTAssertEqual(*((int*)value3.pointerValue), 9);
            
            // Verify old values still present on C interface
            XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value1), @"4");
            XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value2), @"5");
            XCTAssertEqual(*((int*)AEManagedValueGetValue(value3)), 6);
        }];
        
        // Verify old values still present on C interface
        XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value1), @"4");
        XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value2), @"5");
        XCTAssertEqual(*((int*)AEManagedValueGetValue(value3)), 6);
        
        __weak id weakRef3 = nil;
        __weak id weakRef4 = nil;
        @autoreleasepool {
            weakRef3 = value1.objectValue;
            weakRef4 = value2.objectValue;
        }
        
        // Do another batch update - no commit yet
        [AEManagedValue performAtomicBatchUpdate:^{
            // Verify old values, from last commit, still present on C interface
            XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value1), @"4");
            XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value2), @"5");
            XCTAssertEqual(*((int*)AEManagedValueGetValue(value3)), 6);
            
            // Assign new values in batch
            [AEManagedValue performAtomicBatchUpdate:^{
                value1.objectValue = [[NSMutableString alloc] initWithFormat:@"%d", 10];
            }];
            value2.objectValue = [[NSMutableString alloc] initWithFormat:@"%d", 11];
            int * ptr = malloc(sizeof(int)); *ptr = 12;
            value3.pointerValue = ptr;
            
            // Verify new values visible on Obj-C interface
            XCTAssertEqualObjects(value1.objectValue, @"10");
            XCTAssertEqualObjects(value2.objectValue, @"11");
            XCTAssertEqual(*((int*)value3.pointerValue), 12);
            
            // Verify old values, from last commit, still present on C interface
            XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value1), @"4");
            XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value2), @"5");
            XCTAssertEqual(*((int*)AEManagedValueGetValue(value3)), 6);
        }];
        
        // Verify old values, from last commit, still present on C interface
        XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value1), @"4");
        XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value2), @"5");
        XCTAssertEqual(*((int*)AEManagedValueGetValue(value3)), 6);
        
        // Commit updates
        AEManagedValueCommitPendingUpdates();
        
        // After batch update, ensure new values present on C interface
        XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value1), @"10");
        XCTAssertEqualObjects((__bridge NSString*)AEManagedValueGetValue(value2), @"11");
        XCTAssertEqual(*((int*)AEManagedValueGetValue(value3)), 12);
        
        // Run release timer
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    
        // Make sure both old values released
        XCTAssertNil(weakRef1);
        XCTAssertNil(weakRef2);
    }
    
    __weak AEManagedValue * weakValue1 = value1;
    value1 = nil;
    
    // Ensure no leaks
    XCTAssertNil(weakValue1);
    
    // Ensure no crashes when doing new batch update, with released deferral
    [AEManagedValue performAtomicBatchUpdate:^{
        
    }];
    
    AEManagedValueCommitPendingUpdates();
}

@end
