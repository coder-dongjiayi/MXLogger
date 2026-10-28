//
//  MXLoggerDemoTests.m
//  MXLoggerDemoTests
//
//  Created by 董家祎 on 2022/3/23.
//

#import <XCTest/XCTest.h>
#import <MXLogger/MXLogger.h>

@interface MXLoggerDemoTests : XCTestCase

@end

@implementation MXLoggerDemoTests

/// 单线程顺序写入 100 条，检查 selectWithDiskCacheFilePath 返回的顺序
- (void)testSelectPreservesInsertOrder {
    NSString *ns = [NSString stringWithFormat:@"com.djy.mxlogger.ordertest.%.0f", [NSDate date].timeIntervalSince1970];
    MXLogger *logger = [MXLogger initializeWithNamespace:ns];

    for (NSInteger i = 1; i <= 100; i++) {
        [logger infoWithName:@"order" msg:[NSString stringWithFormat:@"#%05ld", (long)i] tag:@"order"];
    }

    NSArray *files = [logger logFiles];
    XCTAssertTrue(files.count > 0);
    NSString *path = [logger.diskCachePath stringByAppendingString:[files.lastObject[@"name"] description]];
    NSArray<NSDictionary *> *records = [MXLogger selectWithDiskCacheFilePath:path cryptKey:nil iv:nil];

    NSMutableArray *seqs = [NSMutableArray array];
    for (NSDictionary *record in records) {
        NSString *msg = [record[@"msg"] description];
        if ([msg hasPrefix:@"#"]) [seqs addObject:@([[msg substringFromIndex:1] integerValue])];
    }
    NSMutableArray *parts = [NSMutableArray array];
    for (NSNumber *seq in seqs) [parts addObject:seq.stringValue];
    NSLog(@"[ordertest] 解析条数=%lu 序号=%@", (unsigned long)seqs.count, [parts componentsJoinedByString:@","]);

    XCTAssertEqual(seqs.count, (NSUInteger)100);

    // selectWithDiskCacheFilePath 返回"最新的在前"(倒序): 100, 99, ..., 1
    NSInteger next = 100;
    BOOL newestFirst = YES;
    for (NSNumber *seq in seqs) {
        if (seq.integerValue != next--) { newestFirst = NO; break; }
    }
    NSLog(@"[ordertest] 倒序(最新在前)=%@", newestFirst ? @"YES" : @"NO");
    XCTAssertTrue(newestFirst, @"解析结果应为倒序且无丢失/乱序");

    [MXLogger destroyWithNamespace:ns];
}

@end
