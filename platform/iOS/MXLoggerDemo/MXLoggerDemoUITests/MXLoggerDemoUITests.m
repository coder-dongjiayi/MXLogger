//
//  MXLoggerDemoUITests.m
//  MXLoggerDemoUITests
//
//  Created by 董家祎 on 2022/3/23.
//

#import <XCTest/XCTest.h>

@interface MXLoggerDemoUITests : XCTestCase

@end

@implementation MXLoggerDemoUITests

- (void)setUp {
    self.continueAfterFailure = NO;
}

- (void)snap:(XCUIApplication *)app name:(NSString *)name {
    XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:[XCUIScreen.mainScreen screenshot]];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

- (void)testExample {
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch];
}

/// 走一遍演示主流程: 首页 -> 演示主页 -> 写入日志 -> 文件列表 -> 日志查看器
- (void)testDemoNavigation {
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch];

    [NSThread sleepForTimeInterval:1];
    [self snap:app name:@"00-landing"];

    [app.buttons[@"进入演示"] tap];
    [NSThread sleepForTimeInterval:2];
    [self snap:app name:@"01-home"];

    // 写入几条不同等级的日志
    [app.tables.staticTexts[@"写入 Debug 日志"] tap];
    [NSThread sleepForTimeInterval:1];
    [app.tables.staticTexts[@"写入 Info 日志"] tap];
    [NSThread sleepForTimeInterval:1];
    [app.tables.staticTexts[@"写入 Error 日志"] tap];
    [NSThread sleepForTimeInterval:0.3];
    [self snap:app name:@"02-home-toast"];
    [app.tables.staticTexts[@"写入网络请求日志"] tap];
    [NSThread sleepForTimeInterval:2];

    // 多线程并发写入 + 自动校验
    [app.tables.staticTexts[@"多线程并发写入"] tap];
    XCUIElement *alert = app.alerts.firstMatch;
    XCTAssertTrue([alert waitForExistenceWithTimeout:60], @"并发校验弹窗未出现");
    [self snap:app name:@"02b-concurrent-verify"];
    XCTAssertTrue([alert.label containsString:@"通过"], @"并发校验未通过: %@", alert.label);
    [alert.buttons[@"好"] tap];
    [NSThread sleepForTimeInterval:1];

    // 进入文件列表
    XCUIElement *browse = app.tables.staticTexts[@"浏览日志文件"];
    [browse tap];
    [NSThread sleepForTimeInterval:2];
    [self snap:app name:@"03-file-list"];

    // 进入日志查看器
    XCUIElement *firstCell = [app.tables.cells elementBoundByIndex:0];
    if (firstCell.exists) {
        [firstCell tap];
    }
    [NSThread sleepForTimeInterval:3];
    [self snap:app name:@"04-viewer"];
}

/// 在桌面上找到 App 图标并截图(验证 AppIcon 生效)
- (void)testSpringboardIcon {
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch];

    XCUIApplication *springboard = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.apple.springboard"];
    [springboard activate];
    [NSThread sleepForTimeInterval:1];

    XCUIElement *icon = springboard.icons[@"MXLoggerDemo"];
    for (int i = 0; i < 3; i++) {
        if (icon.exists && icon.isHittable) break;
        [springboard swipeLeft];
        [NSThread sleepForTimeInterval:1];
    }
    XCTAssertTrue(icon.exists, @"桌面未找到 MXLoggerDemo 图标");

    XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:[springboard screenshot]];
    attachment.name = @"springboard-icon";
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

- (void)testLaunchPerformance {
    if (@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)) {
        [self measureWithMetrics:@[[[XCTApplicationLaunchMetric alloc] init]] block:^{
            [[[XCUIApplication alloc] init] launch];
        }];
    }
}

@end
