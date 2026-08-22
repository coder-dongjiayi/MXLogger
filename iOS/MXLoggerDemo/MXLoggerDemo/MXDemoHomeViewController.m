//
//  MXDemoHomeViewController.m
//  MXLoggerDemo
//
//  MXLogger 全功能演示主页
//  覆盖的 API:
//   - initializeWithNamespace:storagePolicy:fileName:fileHeader:cryptKey:iv:
//   - destroyWithNamespace: / valueForLoggerKey:
//   - debug/info/warn/error/fatal WithName:msg:tag:
//   - logWithLevel:name:msg:tag:
//   - +infoWithLoggerKey:... 等类方法写入
//   - level / consoleEnable / enable / shouldRemoveExpiredDataWhenEnterBackground
//   - maxDiskAge / maxDiskSize / logSize / diskCachePath / loggerKey
//   - logFiles / errorDesc
//   - removeExpireData / removeBeforeAllData / removeAllData
//

#import "MXDemoHomeViewController.h"
#import "MXDemoActionCell.h"
#import "MXDemoL10n.h"
#import "MXLogFileListViewController.h"
#import <MXLogger/MXLogger.h>

static NSString * const kMXDemoNamespace = @"com.djy.mxlogger";
static NSString * const kMXDemoCryptKey  = @"abcdefgabcdefgob";
static NSString * const kMXDemoIV        = @"abcdefgabcdefgcc";

typedef NS_ENUM(NSInteger, MXDemoRowStyle) {
    MXDemoRowStyleAction = 0,   // 普通点击
    MXDemoRowStyleSwitch,       // 开关
    MXDemoRowStylePush,         // 跳转
};

@interface MXDemoRow : NSObject
@property (nonatomic, copy) NSString *icon;          // SF Symbol 名称
@property (nonatomic, strong) UIColor *tint;         // 图标底色
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *subtitle;
@property (nonatomic, copy, nullable) NSString *value;
@property (nonatomic, assign) MXDemoRowStyle style;
@property (nonatomic, assign) BOOL switchOn;
@property (nonatomic, copy, nullable) void (^action)(MXDemoRow *row);
@property (nonatomic, copy, nullable) void (^switchAction)(BOOL isOn);
@end
@implementation MXDemoRow
+ (instancetype)rowWithIcon:(NSString *)icon tint:(UIColor *)tint title:(NSString *)title subtitle:(NSString *)subtitle {
    MXDemoRow *row = [MXDemoRow new];
    row.icon = icon;
    row.tint = tint;
    row.title = title;
    row.subtitle = subtitle;
    return row;
}
@end

@interface MXDemoSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *footer;
@property (nonatomic, copy) NSArray<MXDemoRow *> *rows;
@end
@implementation MXDemoSection
@end

@interface MXDemoHomeViewController () <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UIView *cardView;
@property (weak, nonatomic) IBOutlet UILabel *namespaceLabel;
@property (weak, nonatomic) IBOutlet UILabel *sizeValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *filesValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *levelValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *policyValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *sizeCaptionLabel;
@property (weak, nonatomic) IBOutlet UILabel *filesCaptionLabel;
@property (weak, nonatomic) IBOutlet UILabel *levelCaptionLabel;
@property (weak, nonatomic) IBOutlet UILabel *policyCaptionLabel;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic, strong) MXLogger *logger;
@property (nonatomic, copy) NSArray<MXDemoSection *> *sections;

@property (nonatomic, copy) NSString *perfResult;      // 10万条写入耗时
@property (nonatomic, assign) NSUInteger writeCount;   // 本次会话写入条数

@end

@implementation MXDemoHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.backButtonTitle = @"";

    [self setupLogger];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 56;
    [self.tableView registerNib:[UINib nibWithNibName:@"MXDemoActionCell" bundle:nil]
         forCellReuseIdentifier:MXDemoActionCellReuseId];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[MXDemoL10n switchButtonTitle]
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(toggleLanguage)];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(languageDidChange)
                                                 name:MXDemoLanguageDidChangeNotification
                                               object:nil];

    [self applyLocalization];
    [self buildSections];
    /// 这里不调 refreshStatus: viewWillAppear 紧接着一定会调一次，
    /// 在 push 动画开始前多做一趟目录遍历纯属浪费
    /// refreshStatus is not called here: viewWillAppear always calls it right after, so an
    /// extra directory walk before the push animation starts is pure waste
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshStatus];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [MXLogger destroyWithNamespace:kMXDemoNamespace];
}

#pragma mark - 多语言

- (void)toggleLanguage {
    [MXDemoL10n toggleLanguage];
}

- (void)languageDidChange {
    [self applyLocalization];
    [self buildSections];
    [self.tableView reloadData];
    [self refreshStatus];
}

// 语言相关的静态文案统一在这里应用，语言切换后重新调用即可
- (void)applyLocalization {
    self.title = MXDemoStr(@"home.title");
    self.navigationItem.rightBarButtonItem.title = [MXDemoL10n switchButtonTitle];
    self.sizeCaptionLabel.text = MXDemoStr(@"home.card.size");
    self.filesCaptionLabel.text = MXDemoStr(@"home.card.files");
    self.levelCaptionLabel.text = MXDemoStr(@"home.card.level");
    self.policyCaptionLabel.text = MXDemoStr(@"home.card.policy");
}

#pragma mark - Logger

- (void)setupLogger {
    // 文件头信息: 文件创建时会写入，一般放 App 版本、设备等业务信息
    NSDictionary *headerInfo = @{
        @"platform" : @"iOS",
        @"appVersion" : [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"] ?: @"1.0",
        @"systemVersion" : [UIDevice currentDevice].systemVersion,
        @"device" : [UIDevice currentDevice].model,
    };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:headerInfo options:0 error:NULL];
    NSString *fileHeader = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    // 按小时分片存储 + AES CFB-128 加密
    // 也可以使用其他构造器:
    //  [MXLogger initializeWithNamespace:ns]                              最简初始化
    //  [MXLogger initializeWithNamespace:ns fileHeader:header]            带文件头
    //  [MXLogger initializeWithNamespace:ns cryptKey:key iv:iv fileHeader:header] 加密
    //  [[MXLogger alloc] initWithNamespace:ns ...]                        实例构造器(不进入全局表)
    self.logger = [MXLogger initializeWithNamespace:kMXDemoNamespace
                                      storagePolicy:MXStoragePolicyYYYYMMDDHH
                                           fileName:nil
                                         fileHeader:fileHeader
                                           cryptKey:kMXDemoCryptKey
                                                 iv:kMXDemoIV];

    self.logger.maxDiskAge = 60 * 60 * 24 * 7;      // 日志最多保留 7 天
    self.logger.maxDiskSize = 1024 * 1024 * 10;     // 日志最多占用 10 MB
    self.logger.consoleEnable = YES;                // 控制台同步输出(发布环境建议关闭)
    self.logger.level = 0;                          // 0:debug 全部写入
    self.logger.shouldRemoveExpiredDataWhenEnterBackground = YES;
}

#pragma mark - Sections

- (void)buildSections {
    __weak typeof(self) weakSelf = self;

    // ---------- 日志写入 ----------
    MXDemoSection *writeSection = [MXDemoSection new];
    writeSection.title = MXDemoStr(@"home.section.write");
    writeSection.footer = MXDemoStr(@"home.section.write.footer");

    NSArray *levelMeta = @[
        @[@"ant.fill",                     UIColor.systemGrayColor,   @"debugWithName:msg:tag:"],
        @[@"info.circle.fill",             UIColor.systemBlueColor,   @"infoWithName:msg:tag:"],
        @[@"exclamationmark.triangle.fill",UIColor.systemOrangeColor, @"warnWithName:msg:tag:"],
        @[@"xmark.octagon.fill",           UIColor.systemRedColor,    @"errorWithName:msg:tag:"],
        @[@"flame.fill",                   UIColor.systemPurpleColor, @"fatalWithName:msg:tag:"],
    ];
    NSMutableArray *writeRows = [NSMutableArray array];
    [levelMeta enumerateObjectsUsingBlock:^(NSArray *meta, NSUInteger level, BOOL *stop) {
        NSString *title = [NSString stringWithFormat:MXDemoStr(@"home.write.level.title"), [self levelName:level]];
        MXDemoRow *row = [MXDemoRow rowWithIcon:meta[0] tint:meta[1] title:title subtitle:meta[2]];
        row.action = ^(MXDemoRow *r) { [weakSelf writeLogWithLevel:level]; };
        [writeRows addObject:row];
    }];

    MXDemoRow *jsonRow = [MXDemoRow rowWithIcon:@"network" tint:UIColor.systemTealColor
                                          title:MXDemoStr(@"home.write.network.title")
                                       subtitle:MXDemoStr(@"home.write.network.subtitle")];
    jsonRow.action = ^(MXDemoRow *r) { [weakSelf writeNetworkLog]; };
    [writeRows addObject:jsonRow];

    MXDemoRow *customRow = [MXDemoRow rowWithIcon:@"dial.max.fill" tint:UIColor.systemIndigoColor
                                            title:MXDemoStr(@"home.write.custom.title")
                                         subtitle:MXDemoStr(@"home.write.custom.subtitle")];
    customRow.action = ^(MXDemoRow *r) { [weakSelf writeCustomLevelLog]; };
    [writeRows addObject:customRow];

    MXDemoRow *keyRow = [MXDemoRow rowWithIcon:@"key.fill" tint:UIColor.systemBrownColor
                                         title:MXDemoStr(@"home.write.key.title")
                                      subtitle:MXDemoStr(@"home.write.key.subtitle")];
    keyRow.action = ^(MXDemoRow *r) { [weakSelf writeByLoggerKey]; };
    [writeRows addObject:keyRow];
    writeSection.rows = writeRows;

    // ---------- 配置 ----------
    MXDemoSection *configSection = [MXDemoSection new];
    configSection.title = MXDemoStr(@"home.section.config");
    configSection.footer = MXDemoStr(@"home.section.config.footer");

    MXDemoRow *levelRow = [MXDemoRow rowWithIcon:@"slider.horizontal.3" tint:UIColor.systemBlueColor
                                           title:MXDemoStr(@"home.config.level.title")
                                        subtitle:MXDemoStr(@"home.config.level.subtitle")];
    levelRow.value = [self levelName:self.logger.level];
    levelRow.action = ^(MXDemoRow *r) { [weakSelf pickLevelForRow:r]; };

    MXDemoRow *consoleRow = [MXDemoRow rowWithIcon:@"terminal.fill" tint:UIColor.systemGrayColor
                                             title:MXDemoStr(@"home.config.console.title")
                                          subtitle:MXDemoStr(@"home.config.console.subtitle")];
    consoleRow.style = MXDemoRowStyleSwitch;
    consoleRow.switchOn = self.logger.consoleEnable;
    consoleRow.switchAction = ^(BOOL isOn) {
        weakSelf.logger.consoleEnable = isOn;
        [weakSelf toast:MXDemoStr(isOn ? @"toast.console.on" : @"toast.console.off")];
    };

    MXDemoRow *enableRow = [MXDemoRow rowWithIcon:@"power" tint:UIColor.systemGreenColor
                                            title:MXDemoStr(@"home.config.enable.title")
                                         subtitle:MXDemoStr(@"home.config.enable.subtitle")];
    enableRow.style = MXDemoRowStyleSwitch;
    enableRow.switchOn = YES;
    enableRow.switchAction = ^(BOOL isOn) {
        weakSelf.logger.enable = isOn;
        [weakSelf toast:MXDemoStr(isOn ? @"toast.enable.on" : @"toast.enable.off")];
    };

    MXDemoRow *backgroundRow = [MXDemoRow rowWithIcon:@"moon.zzz.fill" tint:UIColor.systemIndigoColor
                                                title:MXDemoStr(@"home.config.background.title")
                                             subtitle:@"shouldRemoveExpiredDataWhenEnterBackground"];
    backgroundRow.style = MXDemoRowStyleSwitch;
    backgroundRow.switchOn = self.logger.shouldRemoveExpiredDataWhenEnterBackground;
    backgroundRow.switchAction = ^(BOOL isOn) {
        weakSelf.logger.shouldRemoveExpiredDataWhenEnterBackground = isOn;
    };

    MXDemoRow *ageRow = [MXDemoRow rowWithIcon:@"clock.badge.exclamationmark" tint:UIColor.systemOrangeColor
                                         title:MXDemoStr(@"home.config.age.title")
                                      subtitle:MXDemoStr(@"home.config.age.subtitle")];
    ageRow.value = [self diskAgeText:self.logger.maxDiskAge];
    ageRow.action = ^(MXDemoRow *r) { [weakSelf pickDiskAgeForRow:r]; };

    MXDemoRow *sizeRow = [MXDemoRow rowWithIcon:@"externaldrive.fill.badge.exclamationmark" tint:UIColor.systemPinkColor
                                          title:MXDemoStr(@"home.config.size.title")
                                       subtitle:MXDemoStr(@"home.config.size.subtitle")];
    sizeRow.value = [self diskSizeText:self.logger.maxDiskSize];
    sizeRow.action = ^(MXDemoRow *r) { [weakSelf pickDiskSizeForRow:r]; };

    configSection.rows = @[levelRow, consoleRow, enableRow, backgroundRow, ageRow, sizeRow];

    // ---------- 性能测试 ----------
    MXDemoSection *perfSection = [MXDemoSection new];
    perfSection.title = MXDemoStr(@"home.section.perf");
    perfSection.footer = MXDemoStr(@"home.section.perf.footer");

    MXDemoRow *perfRow = [MXDemoRow rowWithIcon:@"speedometer" tint:UIColor.systemGreenColor
                                          title:MXDemoStr(@"home.perf.bench.title")
                                       subtitle:MXDemoStr(@"home.perf.bench.subtitle")];
    perfRow.value = self.perfResult;
    perfRow.action = ^(MXDemoRow *r) { [weakSelf runBenchmark:r]; };

    MXDemoRow *threadRow = [MXDemoRow rowWithIcon:@"cpu" tint:UIColor.systemTealColor
                                            title:MXDemoStr(@"home.perf.thread.title")
                                         subtitle:MXDemoStr(@"home.perf.thread.subtitle")];
    threadRow.action = ^(MXDemoRow *r) { [weakSelf runConcurrentWrite]; };
    perfSection.rows = @[perfRow, threadRow];

    // ---------- 文件管理 ----------
    MXDemoSection *fileSection = [MXDemoSection new];
    fileSection.title = MXDemoStr(@"home.section.file");

    MXDemoRow *browseRow = [MXDemoRow rowWithIcon:@"folder.fill" tint:UIColor.systemBlueColor
                                            title:MXDemoStr(@"home.file.browse.title")
                                         subtitle:MXDemoStr(@"home.file.browse.subtitle")];
    browseRow.style = MXDemoRowStylePush;
    browseRow.action = ^(MXDemoRow *r) { [weakSelf openFileList]; };

    MXDemoRow *expireRow = [MXDemoRow rowWithIcon:@"clock.arrow.circlepath" tint:UIColor.systemOrangeColor
                                            title:MXDemoStr(@"home.file.expire.title")
                                         subtitle:@"removeExpireData"];
    expireRow.action = ^(MXDemoRow *r) {
        [weakSelf.logger removeExpireData];
        [weakSelf toast:MXDemoStr(@"toast.expire.done")];
        [weakSelf refreshStatus];
    };

    MXDemoRow *beforeRow = [MXDemoRow rowWithIcon:@"trash.slash.fill" tint:UIColor.systemYellowColor
                                            title:MXDemoStr(@"home.file.before.title")
                                         subtitle:MXDemoStr(@"home.file.before.subtitle")];
    beforeRow.action = ^(MXDemoRow *r) {
        [weakSelf.logger removeBeforeAllData];
        [weakSelf toast:MXDemoStr(@"toast.before.done")];
        [weakSelf refreshStatus];
    };

    MXDemoRow *allRow = [MXDemoRow rowWithIcon:@"trash.fill" tint:UIColor.systemRedColor
                                         title:MXDemoStr(@"home.file.all.title")
                                      subtitle:@"removeAllData"];
    allRow.action = ^(MXDemoRow *r) { [weakSelf confirmRemoveAll]; };
    fileSection.rows = @[browseRow, expireRow, beforeRow, allRow];

    // ---------- 实例信息 ----------
    MXDemoSection *infoSection = [MXDemoSection new];
    infoSection.title = MXDemoStr(@"home.section.info");
    infoSection.footer = MXDemoStr(@"home.section.info.footer");

    MXDemoRow *keyInfoRow = [MXDemoRow rowWithIcon:@"number" tint:UIColor.systemIndigoColor
                                             title:@"loggerKey" subtitle:self.logger.loggerKey];
    keyInfoRow.action = ^(MXDemoRow *r) {
        UIPasteboard.generalPasteboard.string = weakSelf.logger.loggerKey;
        [weakSelf toast:MXDemoStr(@"toast.key.copied")];
    };

    MXDemoRow *pathRow = [MXDemoRow rowWithIcon:@"folder.badge.gearshape" tint:UIColor.systemGrayColor
                                          title:MXDemoStr(@"home.info.path.title") subtitle:self.logger.diskCachePath];
    pathRow.action = ^(MXDemoRow *r) {
        UIPasteboard.generalPasteboard.string = weakSelf.logger.diskCachePath;
        [weakSelf toast:MXDemoStr(@"toast.path.copied")];
    };

    MXDemoRow *errorRow = [MXDemoRow rowWithIcon:@"exclamationmark.bubble.fill" tint:UIColor.systemOrangeColor
                                           title:MXDemoStr(@"home.info.error.title")
                                        subtitle:MXDemoStr(@"home.info.error.subtitle")];
    errorRow.action = ^(MXDemoRow *r) {
        NSString *desc = [weakSelf.logger errorDesc];
        [weakSelf alertWithTitle:@"errorDesc" message:desc.length > 0 ? desc : MXDemoStr(@"alert.no.error")];
    };

    MXDemoRow *rebuildRow = [MXDemoRow rowWithIcon:@"arrow.triangle.2.circlepath" tint:UIColor.systemRedColor
                                             title:MXDemoStr(@"home.info.rebuild.title")
                                          subtitle:MXDemoStr(@"home.info.rebuild.subtitle")];
    rebuildRow.action = ^(MXDemoRow *r) {
        [MXLogger destroyWithNamespace:kMXDemoNamespace];
        [weakSelf setupLogger];
        [weakSelf buildSections];
        [weakSelf.tableView reloadData];
        [weakSelf refreshStatus];
        [weakSelf toast:MXDemoStr(@"toast.rebuild.done")];
    };
    infoSection.rows = @[keyInfoRow, pathRow, errorRow, rebuildRow];

    self.sections = @[writeSection, configSection, perfSection, fileSection, infoSection];
}

#pragma mark - 写入动作

- (void)writeLogWithLevel:(NSInteger)level {
    NSString *name = @"mxlogger";
    NSString *tag = @"demo";
    NSString *msg = [NSString stringWithFormat:MXDemoStr(@"log.msg.fmt"),
                     (unsigned long)(self.writeCount + 1),
                     [self levelName:level],
                     [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                    dateStyle:NSDateFormatterNoStyle
                                                    timeStyle:NSDateFormatterMediumStyle]];
    NSInteger result = 0;
    switch (level) {
        case 0: result = [self.logger debugWithName:name msg:msg tag:tag]; break;
        case 1: result = [self.logger infoWithName:name msg:msg tag:tag]; break;
        case 2: result = [self.logger warnWithName:name msg:msg tag:tag]; break;
        case 3: result = [self.logger errorWithName:name msg:msg tag:tag]; break;
        case 4: result = [self.logger fatalWithName:name msg:msg tag:tag]; break;
        default: break;
    }
    [self handleWriteResult:result successText:[NSString stringWithFormat:MXDemoStr(@"toast.write.success"), [self levelName:level]]];
}

- (void)writeNetworkLog {
    NSDictionary *request = @{
        @"uri" : @"https://api.example.com/v1/login",
        @"method" : @"POST",
        @"statusCode" : @200,
        @"costTime" : @"183ms",
        @"requestHeaders" : @{@"content-type" : @"application/json", @"token" : @"eyJhbGciOi..."},
        @"requestBody" : @{@"mobile" : @"188****8888"},
        @"response" : @{@"code" : @0, @"msg" : @"ok"},
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:request options:NSJSONWritingPrettyPrinted error:NULL];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSInteger result = [self.logger infoWithName:@"network" msg:json tag:@"request"];
    [self handleWriteResult:result successText:MXDemoStr(@"toast.network.success")];
}

- (void)writeCustomLevelLog {
    // logWithLevel: 是所有便捷方法的底层通用入口
    NSInteger result = [self.logger logWithLevel:3
                                            name:@"pay"
                                             msg:MXDemoStr(@"log.pay.msg")
                                             tag:@"order"];
    [self handleWriteResult:result successText:MXDemoStr(@"toast.custom.success")];
}

- (void)writeByLoggerKey {
    // 业务组件不持有 logger 对象，只拿一个字符串 key 即可写入
    NSString *loggerKey = self.logger.loggerKey;

    // 也可以通过 key 找回实例: [MXLogger valueForLoggerKey:loggerKey]
    MXLogger *found = [MXLogger valueForLoggerKey:loggerKey];
    NSAssert(found == self.logger, @"valueForLoggerKey 应返回同一实例");

    NSInteger result = [MXLogger infoWithLoggerKey:loggerKey
                                              name:@"module.user"
                                               msg:MXDemoStr(@"log.module.msg")
                                               tag:@"module"];
    [self handleWriteResult:result successText:MXDemoStr(@"toast.key.success")];
}

- (void)handleWriteResult:(NSInteger)result successText:(NSString *)text {
    if (result == 0) {
        self.writeCount += 1;
        [self toast:text];
    } else {
        // -1 扩容失败 -2 解除映射失败 -3 映射失败
        [self alertWithTitle:[NSString stringWithFormat:MXDemoStr(@"alert.write.failed"), (long)result]
                     message:[self.logger errorDesc]];
    }
    [self refreshStatus];
}

#pragma mark - 性能测试

- (void)runBenchmark:(MXDemoRow *)row {
    BOOL consoleWasOn = self.logger.consoleEnable;
    self.logger.consoleEnable = NO; // 控制台输出会严重拖慢写入，测试期间临时关闭

    row.value = MXDemoStr(@"home.perf.bench.running");
    [self.tableView reloadData];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        for (NSInteger i = 0; i < 100000; i++) {
            // 每条日志带序号，方便在查看器里核对写入顺序和完整性
            NSString *msg = [NSString stringWithFormat:@"[%06ld] This is a benchmark loooooooooooooooooooooooooooooog", (long)(i + 1)];
            [self.logger infoWithName:@"benchmark" msg:msg tag:@"perf"];
        }
        CFAbsoluteTime cost = CFAbsoluteTimeGetCurrent() - start;

        dispatch_async(dispatch_get_main_queue(), ^{
            self.logger.consoleEnable = consoleWasOn;
            self.writeCount += 100000;
            self.perfResult = [NSString stringWithFormat:@"%.0f ms", cost * 1000];
            row.value = self.perfResult;
            [self.tableView reloadData];
            [self refreshStatus];
            [self toast:[NSString stringWithFormat:MXDemoStr(@"toast.bench.done"), cost * 1000]];
        });
    });
}

// 模拟真实 App 的多线程日志来源：主线程(UI 事件) + 不同 QoS 的 global queue(网络回调/后台任务)。
// 每条日志带 "#序号"，写入期间随机 usleep 扰动调度、穿插 logFiles 读取，
// 结束后解析当前日志文件，逐来源校验条数与顺序，给出可信的并发安全结论。
- (void)runConcurrentWrite {
    BOOL consoleWasOn = self.logger.consoleEnable;
    self.logger.consoleEnable = NO;

    // 每轮用随机 runName 作为 name 字段，避免与历史数据混淆
    NSString *runName = [NSString stringWithFormat:@"mt-%08x", arc4random()];

    NSArray<NSArray *> *sources = @[
        @[@"qos-userInteractive", @(QOS_CLASS_USER_INTERACTIVE), @1000],
        @[@"qos-default",         @(QOS_CLASS_DEFAULT),          @1000],
        @[@"qos-background",      @(QOS_CLASS_BACKGROUND),       @1000],
    ];
    NSInteger mainCount = 200; // 主线程写少一些，避免长时间卡 UI

    NSMutableDictionary<NSString *, NSNumber *> *expected = [NSMutableDictionary dictionary];
    for (NSArray *source in sources) expected[source[0]] = source[2];
    expected[@"main"] = @(mainCount);

    [self toast:MXDemoStr(@"toast.concurrent.running")];
    dispatch_group_t group = dispatch_group_create();

    for (NSArray *source in sources) {
        NSString *tag = source[0];
        qos_class_t qos = (qos_class_t)[source[1] unsignedIntValue];
        NSInteger total = [source[2] integerValue];

        dispatch_group_async(group, dispatch_get_global_queue(qos, 0), ^{
            for (NSInteger i = 1; i <= total; i++) {
                NSString *msg;
                if (i % 100 == 0) {
                    // 混入长消息，覆盖 mmap 扩容/跨页写入等边界
                    msg = [NSString stringWithFormat:@"#%05ld %@ long message: %@", (long)i, tag,
                           [@"" stringByPaddingToLength:600 withString:@"payload-" startingAtIndex:0]];
                } else {
                    msg = [NSString stringWithFormat:@"#%05ld %@ concurrent write", (long)i, tag];
                }
                [self.logger infoWithName:runName msg:msg tag:tag];

                // 随机让出 CPU，拉长并发重叠窗口，让调度交错更接近真实
                if (i % 50 == 0) usleep(arc4random_uniform(500));
                // 边写边读，覆盖"写入与查询并发"的场景
                if (i % 250 == 0) (void)[self.logger logFiles];
            }
        });
    }

    // 主线程来源：模拟 UI 事件里打日志
    dispatch_group_enter(group);
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NSInteger i = 1; i <= mainCount; i++) {
            NSString *msg = [NSString stringWithFormat:@"#%05ld main concurrent write", (long)i];
            [self.logger infoWithName:runName msg:msg tag:@"main"];
        }
        dispatch_group_leave(group);
    });

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        self.logger.consoleEnable = consoleWasOn;
        NSInteger total = 0;
        for (NSNumber *count in expected.allValues) total += count.integerValue;
        self.writeCount += total;
        [self refreshStatus];
        [self verifyConcurrentRunName:runName expected:expected];
    });
}

// 解析当前日志文件，按来源校验: 条数是否等于预期、序号是否连续递增(单线程内顺序不被打乱)
- (void)verifyConcurrentRunName:(NSString *)runName expected:(NSDictionary<NSString *, NSNumber *> *)expected {
    [self toast:MXDemoStr(@"toast.concurrent.verifying")];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        // 找到最后更新的文件(当前写入中的文件)
        NSDictionary *latest = nil;
        double latestTm = -1;
        for (NSDictionary *file in [self.logger logFiles]) {
            double tm = [[file[@"last_timestamp"] description] doubleValue];
            if (tm > latestTm) { latestTm = tm; latest = file; }
        }
        NSString *path = [self.logger.diskCachePath stringByAppendingString:[latest[@"name"] description] ?: @""];
        NSArray<NSDictionary *> *records = [MXLogger selectWithDiskCacheFilePath:path
                                                                        cryptKey:kMXDemoCryptKey
                                                                              iv:kMXDemoIV];

        // 按 tag 收集本轮日志的序号(保持文件中的先后顺序)
        NSMutableDictionary<NSString *, NSMutableArray<NSNumber *> *> *seqs = [NSMutableDictionary dictionary];
        for (NSDictionary *record in records) {
            if (![[record[@"name"] description] isEqualToString:runName]) continue;
            NSString *msg = [record[@"msg"] description];
            if (![msg hasPrefix:@"#"]) continue;
            NSInteger seq = [[msg substringFromIndex:1] integerValue];
            NSString *tag = [record[@"tag"] description];
            NSMutableArray *array = seqs[tag] ?: (seqs[tag] = [NSMutableArray array]);
            [array addObject:@(seq)];
        }

        // 逐来源校验。注意: selectWithDiskCacheFilePath 返回"最新的在前"(倒序)，
        // 因此单个来源的序号应严格递减: N, N-1, ..., 1
        BOOL allPass = YES;
        NSMutableString *report = [NSMutableString string];
        NSArray *tags = [expected.allKeys sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *tag in tags) {
            NSInteger expectCount = expected[tag].integerValue;
            NSArray<NSNumber *> *sequence = seqs[tag] ?: @[];

            BOOL countOK = (NSInteger)sequence.count == expectCount;
            BOOL orderOK = countOK;
            NSInteger next = expectCount;
            if (countOK) {
                for (NSNumber *seq in sequence) {
                    if (seq.integerValue != next--) { orderOK = NO; break; }
                }
            }
            if (!countOK || !orderOK) allPass = NO;
            NSString *status = (countOK && orderOK) ? MXDemoStr(@"verify.line.ok")
                             : (countOK ? MXDemoStr(@"verify.line.order") : MXDemoStr(@"verify.line.missing"));
            [report appendFormat:MXDemoStr(@"verify.line.fmt"), tag,
             (unsigned long)sequence.count, (long)expectCount, status];
        }
        [report appendFormat:MXDemoStr(@"verify.summary.fmt"), (unsigned long)records.count, (unsigned long)tags.count];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self alertWithTitle:MXDemoStr(allPass ? @"verify.pass.title" : @"verify.fail.title")
                         message:report];
        });
    });
}

#pragma mark - 配置动作

- (void)pickLevelForRow:(MXDemoRow *)row {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:MXDemoStr(@"home.config.level.title")
                                                                   message:MXDemoStr(@"picker.level.message")
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSInteger level = 0; level <= 4; level++) {
        NSString *title = [NSString stringWithFormat:@"%@ (%ld)", [self levelName:level], (long)level];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.logger.level = level;
            row.value = [self levelName:level];
            [self.tableView reloadData];
            [self refreshStatus];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:MXDemoStr(@"common.cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet];
}

- (void)pickDiskAgeForRow:(MXDemoRow *)row {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"maxDiskAge"
                                                                   message:MXDemoStr(@"picker.age.message")
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *options = @[@[MXDemoStr(@"duration.1min"), @60], @[MXDemoStr(@"duration.1hour"), @3600],
                         @[MXDemoStr(@"duration.1day"), @86400], @[MXDemoStr(@"duration.7days"), @604800],
                         @[MXDemoStr(@"common.unlimited"), @0]];
    for (NSArray *option in options) {
        [sheet addAction:[UIAlertAction actionWithTitle:option[0] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.logger.maxDiskAge = [option[1] unsignedIntegerValue];
            row.value = option[0];
            [self.tableView reloadData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:MXDemoStr(@"common.cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet];
}

- (void)pickDiskSizeForRow:(MXDemoRow *)row {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"maxDiskSize"
                                                                   message:MXDemoStr(@"picker.size.message")
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *options = @[@[@"1 MB", @(1024 * 1024)], @[@"10 MB", @(1024 * 1024 * 10)],
                         @[@"100 MB", @(1024 * 1024 * 100)], @[MXDemoStr(@"common.unlimited"), @0]];
    for (NSArray *option in options) {
        [sheet addAction:[UIAlertAction actionWithTitle:option[0] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.logger.maxDiskSize = [option[1] unsignedIntegerValue];
            row.value = option[0];
            [self.tableView reloadData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:MXDemoStr(@"common.cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet];
}

#pragma mark - 文件管理

- (void)openFileList {
    MXLogFileListViewController *controller = [[MXLogFileListViewController alloc] initWithNibName:@"MXLogFileListViewController" bundle:nil];
    controller.logger = self.logger;
    controller.cryptKey = kMXDemoCryptKey;
    controller.iv = kMXDemoIV;
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)confirmRemoveAll {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:MXDemoStr(@"alert.removeall.title")
                                                                   message:MXDemoStr(@"alert.removeall.message")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:MXDemoStr(@"common.cancel") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:MXDemoStr(@"common.remove") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self.logger removeAllData];
        self.writeCount = 0;
        [self refreshStatus];
        [self toast:MXDemoStr(@"toast.removeall.done")];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - 状态刷新

- (void)refreshStatus {
    /// logSize 和 logFiles 各自会遍历一遍日志目录，logFiles 的每项已经带 size，
    /// 所以只取 logFiles 再自己求和，省掉一趟遍历
    /// logSize and logFiles each walk the log directory, and every logFiles entry already
    /// carries its size, so only logFiles is called and the total is summed here instead
    NSArray<NSDictionary<NSString *, NSString *> *> *files = [self.logger logFiles];
    NSUInteger logSize = 0;
    for (NSDictionary<NSString *, NSString *> *file in files) {
        logSize += (NSUInteger)[file[@"size"] longLongValue];
    }
    self.sizeValueLabel.text = [self byteText:logSize];
    self.filesValueLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)files.count];
    self.levelValueLabel.text = [self levelName:self.logger.level];
    self.policyValueLabel.text = MXDemoStr(@"home.card.policy.hourly");
    self.namespaceLabel.text = [NSString stringWithFormat:MXDemoStr(@"home.card.namespace.fmt"), kMXDemoNamespace];
}

#pragma mark - Helper

- (NSString *)levelName:(NSInteger)level {
    NSArray *names = @[@"Debug", @"Info", @"Warn", @"Error", @"Fatal"];
    return (level >= 0 && level < (NSInteger)names.count) ? names[level] : @"Debug";
}

- (NSString *)byteText:(NSUInteger)bytes {
    if (bytes < 1024) return [NSString stringWithFormat:@"%lu B", (unsigned long)bytes];
    if (bytes < 1024 * 1024) return [NSString stringWithFormat:@"%.1f KB", bytes / 1024.0];
    return [NSString stringWithFormat:@"%.2f MB", bytes / 1024.0 / 1024.0];
}

- (NSString *)diskAgeText:(NSUInteger)seconds {
    if (seconds == 0) return MXDemoStr(@"common.unlimited");
    if (seconds < 3600) return [NSString stringWithFormat:MXDemoStr(@"duration.minutes.fmt"), (unsigned long)(seconds / 60)];
    if (seconds < 86400) return [NSString stringWithFormat:MXDemoStr(@"duration.hours.fmt"), (unsigned long)(seconds / 3600)];
    return [NSString stringWithFormat:MXDemoStr(@"duration.days.fmt"), (unsigned long)(seconds / 86400)];
}

- (NSString *)diskSizeText:(NSUInteger)bytes {
    if (bytes == 0) return MXDemoStr(@"common.unlimited");
    return [self byteText:bytes];
}

- (void)presentSheet:(UIAlertController *)sheet {
    // iPad 上 actionSheet 需要锚点
    sheet.popoverPresentationController.sourceView = self.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)alertWithTitle:(NSString *)title message:(nullable NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:MXDemoStr(@"common.ok") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)toast:(NSString *)text {
    UILabel *label = [UILabel new];
    label.text = [NSString stringWithFormat:@"  %@  ", text];
    label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    label.textColor = UIColor.whiteColor;
    label.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.78];
    label.textAlignment = NSTextAlignmentCenter;
    label.layer.cornerRadius = 16;
    label.clipsToBounds = YES;
    label.alpha = 0;

    [label sizeToFit];
    CGFloat width = MIN(label.bounds.size.width + 16, self.view.bounds.size.width - 48);
    label.bounds = CGRectMake(0, 0, width, 32);
    label.center = CGPointMake(self.view.center.x, self.view.bounds.size.height - 140);
    [self.view addSubview:label];

    [UIView animateWithDuration:0.2 animations:^{ label.alpha = 1; } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.25 delay:1.4 options:0 animations:^{ label.alpha = 0; } completion:^(BOOL done) {
            [label removeFromSuperview];
        }];
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sections[section].rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section].title;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return self.sections[section].footer;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MXDemoActionCell *cell = [tableView dequeueReusableCellWithIdentifier:MXDemoActionCellReuseId forIndexPath:indexPath];
    MXDemoRow *row = self.sections[indexPath.section].rows[indexPath.row];
    [cell configureWithIcon:row.icon tint:row.tint title:row.title subtitle:row.subtitle value:row.value];

    if (row.style == MXDemoRowStyleSwitch) {
        [cell applySwitchAccessoryOn:row.switchOn
                                tag:indexPath.section * 1000 + indexPath.row
                             target:self
                             action:@selector(switchChanged:)];
    } else {
        [cell applyAccessoryType:(row.style == MXDemoRowStylePush) ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone];
    }
    return cell;
}

- (void)switchChanged:(UISwitch *)sender {
    NSInteger section = sender.tag / 1000;
    NSInteger index = sender.tag % 1000;
    MXDemoRow *row = self.sections[section].rows[index];
    row.switchOn = sender.isOn;
    if (row.switchAction) row.switchAction(sender.isOn);
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    MXDemoRow *row = self.sections[indexPath.section].rows[indexPath.row];
    if (row.style != MXDemoRowStyleSwitch && row.action) row.action(row);
}

@end
