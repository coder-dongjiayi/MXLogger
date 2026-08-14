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
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic, strong) MXLogger *logger;
@property (nonatomic, copy) NSArray<MXDemoSection *> *sections;

@property (nonatomic, copy) NSString *perfResult;      // 10万条写入耗时
@property (nonatomic, assign) NSUInteger writeCount;   // 本次会话写入条数

@end

@implementation MXDemoHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"MXLogger Demo";
    self.navigationItem.backButtonTitle = @"";

    [self setupLogger];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 56;
    [self.tableView registerNib:[UINib nibWithNibName:@"MXDemoActionCell" bundle:nil]
         forCellReuseIdentifier:MXDemoActionCellReuseId];

    [self buildSections];
    [self refreshStatus];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshStatus];
}

- (void)dealloc {
    [MXLogger destroyWithNamespace:kMXDemoNamespace];
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
    writeSection.title = @"日志写入";
    writeSection.footer = @"每个等级对应一个实例方法，返回 0 表示写入成功。";

    NSArray *levelMeta = @[
        @[@"ant.fill",                     UIColor.systemGrayColor,   @"写入 Debug 日志", @"debugWithName:msg:tag:"],
        @[@"info.circle.fill",             UIColor.systemBlueColor,   @"写入 Info 日志",  @"infoWithName:msg:tag:"],
        @[@"exclamationmark.triangle.fill",UIColor.systemOrangeColor, @"写入 Warn 日志",  @"warnWithName:msg:tag:"],
        @[@"xmark.octagon.fill",           UIColor.systemRedColor,    @"写入 Error 日志", @"errorWithName:msg:tag:"],
        @[@"flame.fill",                   UIColor.systemPurpleColor, @"写入 Fatal 日志", @"fatalWithName:msg:tag:"],
    ];
    NSMutableArray *writeRows = [NSMutableArray array];
    [levelMeta enumerateObjectsUsingBlock:^(NSArray *meta, NSUInteger level, BOOL *stop) {
        MXDemoRow *row = [MXDemoRow rowWithIcon:meta[0] tint:meta[1] title:meta[2] subtitle:meta[3]];
        row.action = ^(MXDemoRow *r) { [weakSelf writeLogWithLevel:level]; };
        [writeRows addObject:row];
    }];

    MXDemoRow *jsonRow = [MXDemoRow rowWithIcon:@"network" tint:UIColor.systemTealColor
                                          title:@"写入网络请求日志" subtitle:@"msg 为 JSON 字符串，tag = request"];
    jsonRow.action = ^(MXDemoRow *r) { [weakSelf writeNetworkLog]; };
    [writeRows addObject:jsonRow];

    MXDemoRow *customRow = [MXDemoRow rowWithIcon:@"dial.max.fill" tint:UIColor.systemIndigoColor
                                            title:@"logWithLevel: 通用写入" subtitle:@"自定义等级写入，本例 level = 3 (error)"];
    customRow.action = ^(MXDemoRow *r) { [weakSelf writeCustomLevelLog]; };
    [writeRows addObject:customRow];

    MXDemoRow *keyRow = [MXDemoRow rowWithIcon:@"key.fill" tint:UIColor.systemBrownColor
                                         title:@"通过 loggerKey 写入" subtitle:@"组件化场景：只传 key 不传对象，+infoWithLoggerKey:"];
    keyRow.action = ^(MXDemoRow *r) { [weakSelf writeByLoggerKey]; };
    [writeRows addObject:keyRow];
    writeSection.rows = writeRows;

    // ---------- 配置 ----------
    MXDemoSection *configSection = [MXDemoSection new];
    configSection.title = @"配置";
    configSection.footer = @"level 只影响磁盘写入；开启 consoleEnable 后控制台仍输出全部日志。";

    MXDemoRow *levelRow = [MXDemoRow rowWithIcon:@"slider.horizontal.3" tint:UIColor.systemBlueColor
                                           title:@"写入等级 level" subtitle:@"低于该等级的日志不写入文件"];
    levelRow.value = [self levelName:self.logger.level];
    levelRow.action = ^(MXDemoRow *r) { [weakSelf pickLevelForRow:r]; };

    MXDemoRow *consoleRow = [MXDemoRow rowWithIcon:@"terminal.fill" tint:UIColor.systemGrayColor
                                             title:@"控制台打印 consoleEnable" subtitle:@"影响写入性能，发布环境建议关闭"];
    consoleRow.style = MXDemoRowStyleSwitch;
    consoleRow.switchOn = self.logger.consoleEnable;
    consoleRow.switchAction = ^(BOOL isOn) {
        weakSelf.logger.consoleEnable = isOn;
        [weakSelf toast:isOn ? @"已开启控制台打印" : @"已关闭控制台打印"];
    };

    MXDemoRow *enableRow = [MXDemoRow rowWithIcon:@"power" tint:UIColor.systemGreenColor
                                            title:@"日志总开关 enable" subtitle:@"关闭后所有日志停止写入"];
    enableRow.style = MXDemoRowStyleSwitch;
    enableRow.switchOn = YES;
    enableRow.switchAction = ^(BOOL isOn) {
        weakSelf.logger.enable = isOn;
        [weakSelf toast:isOn ? @"日志已启用" : @"日志已禁用"];
    };

    MXDemoRow *backgroundRow = [MXDemoRow rowWithIcon:@"moon.zzz.fill" tint:UIColor.systemIndigoColor
                                                title:@"进入后台清理过期文件" subtitle:@"shouldRemoveExpiredDataWhenEnterBackground"];
    backgroundRow.style = MXDemoRowStyleSwitch;
    backgroundRow.switchOn = self.logger.shouldRemoveExpiredDataWhenEnterBackground;
    backgroundRow.switchAction = ^(BOOL isOn) {
        weakSelf.logger.shouldRemoveExpiredDataWhenEnterBackground = isOn;
    };

    MXDemoRow *ageRow = [MXDemoRow rowWithIcon:@"clock.badge.exclamationmark" tint:UIColor.systemOrangeColor
                                         title:@"有效期 maxDiskAge" subtitle:@"超期文件将被清理，0 为无限制"];
    ageRow.value = [self diskAgeText:self.logger.maxDiskAge];
    ageRow.action = ^(MXDemoRow *r) { [weakSelf pickDiskAgeForRow:r]; };

    MXDemoRow *sizeRow = [MXDemoRow rowWithIcon:@"externaldrive.fill.badge.exclamationmark" tint:UIColor.systemPinkColor
                                          title:@"容量上限 maxDiskSize" subtitle:@"超过上限按时间从旧到新清理，0 为无限制"];
    sizeRow.value = [self diskSizeText:self.logger.maxDiskSize];
    sizeRow.action = ^(MXDemoRow *r) { [weakSelf pickDiskSizeForRow:r]; };

    configSection.rows = @[levelRow, consoleRow, enableRow, backgroundRow, ageRow, sizeRow];

    // ---------- 性能测试 ----------
    MXDemoSection *perfSection = [MXDemoSection new];
    perfSection.title = @"性能测试";
    perfSection.footer = @"性能测试前建议关闭 consoleEnable，控制台输出会显著拖慢写入。";

    MXDemoRow *perfRow = [MXDemoRow rowWithIcon:@"speedometer" tint:UIColor.systemGreenColor
                                          title:@"连续写入 100,000 条" subtitle:@"单条约 136 字节，统计总耗时"];
    perfRow.action = ^(MXDemoRow *r) { [weakSelf runBenchmark:r]; };

    MXDemoRow *threadRow = [MXDemoRow rowWithIcon:@"cpu" tint:UIColor.systemTealColor
                                            title:@"多线程并发写入" subtitle:@"主线程 + 3 个 QoS 队列并发写入，完成后自动校验条数与顺序"];
    threadRow.action = ^(MXDemoRow *r) { [weakSelf runConcurrentWrite]; };
    perfSection.rows = @[perfRow, threadRow];

    // ---------- 文件管理 ----------
    MXDemoSection *fileSection = [MXDemoSection new];
    fileSection.title = @"文件管理";

    MXDemoRow *browseRow = [MXDemoRow rowWithIcon:@"folder.fill" tint:UIColor.systemBlueColor
                                            title:@"浏览日志文件" subtitle:@"logFiles + selectWithDiskCacheFilePath: 解析"];
    browseRow.style = MXDemoRowStylePush;
    browseRow.action = ^(MXDemoRow *r) { [weakSelf openFileList]; };

    MXDemoRow *expireRow = [MXDemoRow rowWithIcon:@"clock.arrow.circlepath" tint:UIColor.systemOrangeColor
                                            title:@"清理过期文件" subtitle:@"removeExpireData"];
    expireRow.action = ^(MXDemoRow *r) {
        [weakSelf.logger removeExpireData];
        [weakSelf toast:@"已清理过期文件"];
        [weakSelf refreshStatus];
    };

    MXDemoRow *beforeRow = [MXDemoRow rowWithIcon:@"trash.slash.fill" tint:UIColor.systemYellowColor
                                            title:@"清理历史文件" subtitle:@"removeBeforeAllData，保留当前写入中的文件"];
    beforeRow.action = ^(MXDemoRow *r) {
        [weakSelf.logger removeBeforeAllData];
        [weakSelf toast:@"已清理历史文件"];
        [weakSelf refreshStatus];
    };

    MXDemoRow *allRow = [MXDemoRow rowWithIcon:@"trash.fill" tint:UIColor.systemRedColor
                                         title:@"清空全部日志" subtitle:@"removeAllData"];
    allRow.action = ^(MXDemoRow *r) { [weakSelf confirmRemoveAll]; };
    fileSection.rows = @[browseRow, expireRow, beforeRow, allRow];

    // ---------- 实例信息 ----------
    MXDemoSection *infoSection = [MXDemoSection new];
    infoSection.title = @"实例信息";
    infoSection.footer = @"loggerKey = md5(namespace + directory)，跨模块通过 valueForLoggerKey: 找回实例。";

    MXDemoRow *keyInfoRow = [MXDemoRow rowWithIcon:@"number" tint:UIColor.systemIndigoColor
                                             title:@"loggerKey" subtitle:self.logger.loggerKey];
    keyInfoRow.action = ^(MXDemoRow *r) {
        UIPasteboard.generalPasteboard.string = weakSelf.logger.loggerKey;
        [weakSelf toast:@"loggerKey 已复制"];
    };

    MXDemoRow *pathRow = [MXDemoRow rowWithIcon:@"folder.badge.gearshape" tint:UIColor.systemGrayColor
                                          title:@"缓存目录 diskCachePath" subtitle:self.logger.diskCachePath];
    pathRow.action = ^(MXDemoRow *r) {
        UIPasteboard.generalPasteboard.string = weakSelf.logger.diskCachePath;
        [weakSelf toast:@"路径已复制"];
    };

    MXDemoRow *errorRow = [MXDemoRow rowWithIcon:@"exclamationmark.bubble.fill" tint:UIColor.systemOrangeColor
                                           title:@"查看最近错误 errorDesc" subtitle:@"写入返回非 0 时的错误描述"];
    errorRow.action = ^(MXDemoRow *r) {
        NSString *desc = [weakSelf.logger errorDesc];
        [weakSelf alertWithTitle:@"errorDesc" message:desc.length > 0 ? desc : @"暂无错误"];
    };

    MXDemoRow *rebuildRow = [MXDemoRow rowWithIcon:@"arrow.triangle.2.circlepath" tint:UIColor.systemRedColor
                                             title:@"销毁并重建实例" subtitle:@"destroyWithNamespace: 后重新 initialize"];
    rebuildRow.action = ^(MXDemoRow *r) {
        [MXLogger destroyWithNamespace:kMXDemoNamespace];
        [weakSelf setupLogger];
        [weakSelf buildSections];
        [weakSelf.tableView reloadData];
        [weakSelf refreshStatus];
        [weakSelf toast:@"实例已重建"];
    };
    infoSection.rows = @[keyInfoRow, pathRow, errorRow, rebuildRow];

    self.sections = @[writeSection, configSection, perfSection, fileSection, infoSection];
}

#pragma mark - 写入动作

- (void)writeLogWithLevel:(NSInteger)level {
    NSString *name = @"mxlogger";
    NSString *tag = @"demo";
    NSString *msg = [NSString stringWithFormat:@"这是第 %lu 条 %@ 日志，写于 %@",
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
    [self handleWriteResult:result successText:[NSString stringWithFormat:@"%@ 写入成功", [self levelName:level]]];
}

- (void)writeNetworkLog {
    NSDictionary *request = @{
        @"uri" : @"https://api.example.com/v1/login",
        @"method" : @"POST",
        @"statusCode" : @200,
        @"costTime" : @"183ms",
        @"requestHeaders" : @{@"content-type" : @"application/json", @"token" : @"eyJhbGciOi..."},
        @"requestBody" : @{@"mobile" : @"188****8888"},
        @"response" : @{@"code" : @0, @"msg" : @"操作成功"},
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:request options:NSJSONWritingPrettyPrinted error:NULL];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSInteger result = [self.logger infoWithName:@"network" msg:json tag:@"request"];
    [self handleWriteResult:result successText:@"网络日志写入成功"];
}

- (void)writeCustomLevelLog {
    // logWithLevel: 是所有便捷方法的底层通用入口
    NSInteger result = [self.logger logWithLevel:3
                                            name:@"pay"
                                             msg:@"订单支付失败: code=-1009 网络连接中断"
                                             tag:@"order"];
    [self handleWriteResult:result successText:@"logWithLevel: 写入成功"];
}

- (void)writeByLoggerKey {
    // 业务组件不持有 logger 对象，只拿一个字符串 key 即可写入
    NSString *loggerKey = self.logger.loggerKey;

    // 也可以通过 key 找回实例: [MXLogger valueForLoggerKey:loggerKey]
    MXLogger *found = [MXLogger valueForLoggerKey:loggerKey];
    NSAssert(found == self.logger, @"valueForLoggerKey 应返回同一实例");

    NSInteger result = [MXLogger infoWithLoggerKey:loggerKey
                                              name:@"module.user"
                                               msg:@"子组件通过 loggerKey 写入的日志"
                                               tag:@"module"];
    [self handleWriteResult:result successText:@"loggerKey 写入成功"];
}

- (void)handleWriteResult:(NSInteger)result successText:(NSString *)text {
    if (result == 0) {
        self.writeCount += 1;
        [self toast:text];
    } else {
        // -1 扩容失败 -2 解除映射失败 -3 映射失败
        [self alertWithTitle:[NSString stringWithFormat:@"写入失败(%ld)", (long)result]
                     message:[self.logger errorDesc]];
    }
    [self refreshStatus];
}

#pragma mark - 性能测试

- (void)runBenchmark:(MXDemoRow *)row {
    BOOL consoleWasOn = self.logger.consoleEnable;
    self.logger.consoleEnable = NO; // 控制台输出会严重拖慢写入，测试期间临时关闭

    row.value = @"测试中…";
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
            row.value = [NSString stringWithFormat:@"%.0f ms", cost * 1000];
            [self.tableView reloadData];
            [self refreshStatus];
            [self toast:[NSString stringWithFormat:@"10 万条写入耗时 %.0f ms", cost * 1000]];
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

    [self toast:@"并发写入中…"];
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
                    msg = [NSString stringWithFormat:@"#%05ld %@ 长消息: %@", (long)i, tag,
                           [@"" stringByPaddingToLength:600 withString:@"payload-" startingAtIndex:0]];
                } else {
                    msg = [NSString stringWithFormat:@"#%05ld %@ 并发写入", (long)i, tag];
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
            NSString *msg = [NSString stringWithFormat:@"#%05ld main 并发写入", (long)i];
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
    [self toast:@"写入完成，正在解析校验…"];
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
            [report appendFormat:@"%@: %ld/%ld 条 %@\n", tag,
             (unsigned long)sequence.count, (long)expectCount,
             (countOK && orderOK) ? @"✓ 顺序完整" : (countOK ? @"✗ 顺序异常" : @"✗ 条数缺失")];
        }
        [report appendFormat:@"\n文件共 %lu 条，校验来源 %lu 个", (unsigned long)records.count, (unsigned long)tags.count];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self alertWithTitle:allPass ? @"✅ 并发校验通过" : @"❌ 并发校验失败"
                         message:report];
        });
    });
}

#pragma mark - 配置动作

- (void)pickLevelForRow:(MXDemoRow *)row {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"写入等级 level"
                                                                   message:@"低于该等级的日志不会写入磁盘文件"
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
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet];
}

- (void)pickDiskAgeForRow:(MXDemoRow *)row {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"maxDiskAge"
                                                                   message:@"日志文件最长保留时间"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *options = @[@[@"1 分钟", @60], @[@"1 小时", @3600], @[@"1 天", @86400], @[@"7 天", @604800], @[@"无限制", @0]];
    for (NSArray *option in options) {
        [sheet addAction:[UIAlertAction actionWithTitle:option[0] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.logger.maxDiskAge = [option[1] unsignedIntegerValue];
            row.value = option[0];
            [self.tableView reloadData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet];
}

- (void)pickDiskSizeForRow:(MXDemoRow *)row {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"maxDiskSize"
                                                                   message:@"日志文件占用磁盘上限"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *options = @[@[@"1 MB", @(1024 * 1024)], @[@"10 MB", @(1024 * 1024 * 10)],
                         @[@"100 MB", @(1024 * 1024 * 100)], @[@"无限制", @0]];
    for (NSArray *option in options) {
        [sheet addAction:[UIAlertAction actionWithTitle:option[0] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.logger.maxDiskSize = [option[1] unsignedIntegerValue];
            row.value = option[0];
            [self.tableView reloadData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清空全部日志？"
                                                                   message:@"removeAllData 将删除所有日志文件，且不可恢复。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"清空" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self.logger removeAllData];
        self.writeCount = 0;
        [self refreshStatus];
        [self toast:@"日志已清空"];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - 状态刷新

- (void)refreshStatus {
    NSUInteger logSize = self.logger.logSize;
    self.sizeValueLabel.text = [self byteText:logSize];
    self.filesValueLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)[self.logger logFiles].count];
    self.levelValueLabel.text = [self levelName:self.logger.level];
    self.policyValueLabel.text = @"按小时";
    self.namespaceLabel.text = [NSString stringWithFormat:@"%@ · AES-CFB 128 加密", kMXDemoNamespace];
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
    if (seconds == 0) return @"无限制";
    if (seconds < 3600) return [NSString stringWithFormat:@"%lu 分钟", (unsigned long)(seconds / 60)];
    if (seconds < 86400) return [NSString stringWithFormat:@"%lu 小时", (unsigned long)(seconds / 3600)];
    return [NSString stringWithFormat:@"%lu 天", (unsigned long)(seconds / 86400)];
}

- (NSString *)diskSizeText:(NSUInteger)bytes {
    if (bytes == 0) return @"无限制";
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
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
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
        UISwitch *switcher = [UISwitch new];
        switcher.on = row.switchOn;
        switcher.tag = indexPath.section * 1000 + indexPath.row;
        [switcher addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switcher;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        cell.accessoryView = nil;
        cell.accessoryType = (row.style == MXDemoRowStylePush) ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
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
