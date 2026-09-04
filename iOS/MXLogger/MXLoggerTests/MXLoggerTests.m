//
//  MXLoggerTests.m
//  MXLoggerTests
//
//  MXLogger ObjC API 单元测试
//  覆盖: 初始化/实例复用/写入/解析往返(明文+AES加密)/等级过滤/开关/
//       文件命名策略/清理策略/loggerKey类方法族/销毁/文件列表/错误信息
//

#import <XCTest/XCTest.h>
#import <MXLogger/MXLogger.h>

/// 与写入端约定的16字节加密参数
static NSString *const kCryptKey = @"abcdefg123456789";
static NSString *const kIv = @"0123456789abcdef";
/// 文件头记录的固定name(与analyzer/Flutter端约定一致)
static NSString *const kFileHeaderName = @"com.djy.mxlogger.fileHeader";

static NSInteger ns_counter = 0;

@interface MXLoggerTests : XCTestCase
@property (nonatomic, copy) NSString *rootDir;
@end

@implementation MXLoggerTests

- (void)setUp {
    self.rootDir = [NSTemporaryDirectory()
        stringByAppendingPathComponent:
            [NSString stringWithFormat:@"mxlogger_tests_%@", NSUUID.UUID.UUIDString]];
    [NSFileManager.defaultManager createDirectoryAtPath:self.rootDir
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
}

- (void)tearDown {
    [NSFileManager.defaultManager removeItemAtPath:self.rootDir error:nil];
}

#pragma mark - helpers

/// 每个用例独立namespace, 避免全局实例字典串扰
- (NSString *)uniqueNs {
    return [NSString stringWithFormat:@"com.test.mxlogger.ios.ns%ld", (long)ns_counter++];
}

- (NSString *)newDir:(NSString *)tag {
    NSString *dir = [self.rootDir stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"%@%ld", tag, (long)ns_counter]];
    [NSFileManager.defaultManager createDirectoryAtPath:dir
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
    return dir;
}

- (MXLogger *)newLogger {
    return [MXLogger initializeWithNamespace:[self uniqueNs]
                          diskCacheDirectory:[self newDir:@"d"]
                               storagePolicy:MXStoragePolicyYYYYMMDD
                                    fileName:nil
                                  fileHeader:nil
                                    cryptKey:nil
                                          iv:nil];
}

/// 当前正在写入的日志文件完整路径
- (NSString *)currentLogFile:(MXLogger *)logger {
    NSArray<NSDictionary *> *files = [logger logFiles];
    XCTAssertTrue(files.count > 0, @"应该已生成日志文件");
    return [logger.diskCachePath stringByAppendingPathComponent:files.firstObject[@"name"]];
}

/// 读回当前文件全部记录
/// 注意: selectWithDiskCacheFilePath 返回倒序(最新在前, 为展示场景设计),
/// 这里反转为写入顺序, 方便按时间先后断言
- (NSArray<NSDictionary *> *)readBack:(MXLogger *)logger
                             cryptKey:(NSString *)cryptKey
                                   iv:(NSString *)iv {
    NSArray *reversed = [MXLogger selectWithDiskCacheFilePath:[self currentLogFile:logger]
                                                     cryptKey:cryptKey
                                                           iv:iv];
    return reversed.reverseObjectEnumerator.allObjects;
}

/// 在日志目录伪造一个旧文件(旧修改时间), 模拟历史日志
- (NSString *)fakeOldFileFor:(MXLogger *)logger size:(NSUInteger)size {
    NSString *path = [logger.diskCachePath stringByAppendingPathComponent:@"2020-01-01_log.mx"];
    NSMutableData *data = [NSMutableData dataWithLength:size];
    [data writeToFile:path atomically:YES];
    NSDate *old = [NSDate dateWithTimeIntervalSince1970:1577836800]; // 2020-01-01
    [NSFileManager.defaultManager setAttributes:@{NSFileModificationDate : old}
                                   ofItemAtPath:path
                                          error:nil];
    return path;
}

- (BOOL)fileExists:(NSString *)path {
    return [NSFileManager.defaultManager fileExistsAtPath:path];
}

#pragma mark - 初始化与属性

- (void)testLoggerKeyIs32CharMd5AndStable {
    NSString *ns = [self uniqueNs];
    NSString *dir = [self newDir:@"key"];
    MXLogger *a = [MXLogger initializeWithNamespace:ns diskCacheDirectory:dir
                                      storagePolicy:MXStoragePolicyYYYYMMDD
                                           fileName:nil fileHeader:nil cryptKey:nil iv:nil];
    XCTAssertEqual(a.loggerKey.length, (NSUInteger)32);

    // 同namespace+directory 复用同一个实例(全局字典)
    MXLogger *b = [MXLogger initializeWithNamespace:ns diskCacheDirectory:dir
                                      storagePolicy:MXStoragePolicyYYYYMMDD
                                           fileName:nil fileHeader:nil cryptKey:nil iv:nil];
    XCTAssertEqual(a, b, @"同key应返回同一实例");

    // 不同namespace -> 不同key
    MXLogger *c = [MXLogger initializeWithNamespace:[self uniqueNs] diskCacheDirectory:dir
                                      storagePolicy:MXStoragePolicyYYYYMMDD
                                           fileName:nil fileHeader:nil cryptKey:nil iv:nil];
    XCTAssertNotEqualObjects(c.loggerKey, a.loggerKey);
    [MXLogger destroyWithLoggerKey:c.loggerKey];
    [MXLogger destroyWithNamespace:ns diskCacheDirectory:dir];
}

- (void)testDiskCachePathContainsDirectoryAndNamespace {
    NSString *ns = [self uniqueNs];
    NSString *dir = [self newDir:@"path"];
    MXLogger *logger = [MXLogger initializeWithNamespace:ns diskCacheDirectory:dir
                                           storagePolicy:MXStoragePolicyYYYYMMDD
                                                fileName:nil fileHeader:nil cryptKey:nil iv:nil];
    XCTAssertTrue([logger.diskCachePath containsString:dir]);
    XCTAssertTrue([logger.diskCachePath containsString:ns]);
    XCTAssertTrue([self fileExists:logger.diskCachePath], @"初始化时应创建日志目录");
}

- (void)testDefaultDirectoryInitializerVariants {
    // 各简写工厂方法都能正常创建(默认Library目录)
    NSString *ns1 = [self uniqueNs];
    MXLogger *l1 = [MXLogger initializeWithNamespace:ns1];
    XCTAssertNotNil(l1);
    XCTAssertEqual([l1 debugWithName:@"n" msg:@"m" tag:@"t"], (NSInteger)0);
    [MXLogger destroyWithNamespace:ns1];

    NSString *ns2 = [self uniqueNs];
    MXLogger *l2 = [MXLogger initializeWithNamespace:ns2 fileHeader:@"hdr"];
    XCTAssertNotNil(l2);
    [MXLogger destroyWithNamespace:ns2];

    NSString *ns3 = [self uniqueNs];
    MXLogger *l3 = [MXLogger initializeWithNamespace:ns3 cryptKey:kCryptKey iv:kIv fileHeader:nil];
    XCTAssertNotNil(l3);
    [MXLogger destroyWithNamespace:ns3];
}

- (void)testErrorDescIsEmptyWhenNoError {
    MXLogger *logger = [self newLogger];
    NSString *desc = [logger errorDesc];
    XCTAssertTrue(desc == nil || desc.length == 0);
}

#pragma mark - 写入与解析往返(明文)

- (void)testFiveLevelsWriteAndReadBack {
    MXLogger *logger = [self newLogger];
    XCTAssertEqual([logger debugWithName:@"n0" msg:@"d-msg" tag:@"t0"], (NSInteger)0);
    XCTAssertEqual([logger infoWithName:@"n1" msg:@"i-msg" tag:@"t1"], (NSInteger)0);
    XCTAssertEqual([logger warnWithName:@"n2" msg:@"w-msg" tag:@"t2"], (NSInteger)0);
    XCTAssertEqual([logger errorWithName:@"n3" msg:@"e-msg" tag:@"t3"], (NSInteger)0);
    XCTAssertEqual([logger fatalWithName:@"n4" msg:@"f-msg" tag:@"t4"], (NSInteger)0);

    NSArray<NSDictionary *> *records = [self readBack:logger cryptKey:nil iv:nil];
    XCTAssertEqual(records.count, (NSUInteger)5);
    NSArray *msgs = @[ @"d-msg", @"i-msg", @"w-msg", @"e-msg", @"f-msg" ];
    for (NSUInteger i = 0; i < 5; i++) {
        NSDictionary *r = records[i];
        NSString *expectedLevel = [NSString stringWithFormat:@"%lu", (unsigned long)i];
        NSString *expectedName = [NSString stringWithFormat:@"n%lu", (unsigned long)i];
        NSString *expectedTag = [NSString stringWithFormat:@"t%lu", (unsigned long)i];
        XCTAssertEqualObjects(r[@"error_code"], @"0");
        XCTAssertEqualObjects(r[@"level"], expectedLevel);
        XCTAssertEqualObjects(r[@"msg"], msgs[i]);
        XCTAssertEqualObjects(r[@"name"], expectedName);
        XCTAssertEqualObjects(r[@"tag"], expectedTag);
        XCTAssertTrue([r[@"timestamp"] longLongValue] > 0);
    }
}

- (void)testNilNameTagAndUnicodeRoundtrip {
    MXLogger *logger = [self newLogger];
    NSString *cn = @"中文消息🚀 \"引号\" \n换行";
    [logger logWithLevel:1 name:nil msg:@"plain" tag:nil];
    [logger logWithLevel:1 name:@"net" msg:cn tag:@"标签1,标签2"];

    NSArray<NSDictionary *> *records = [self readBack:logger cryptKey:nil iv:nil];
    XCTAssertEqual(records.count, (NSUInteger)2);
    // name为nil时core写入默认name "mxlogger"
    XCTAssertEqualObjects(records[0][@"name"], @"mxlogger");
    XCTAssertEqualObjects(records[0][@"tag"], @"");
    XCTAssertEqualObjects(records[1][@"msg"], cn);
    XCTAssertEqualObjects(records[1][@"tag"], @"标签1,标签2");
}

- (void)testBulkWrite1000NoLoss {
    MXLogger *logger = [self newLogger];
    for (int i = 0; i < 1000; i++) {
        NSString *msg = [NSString stringWithFormat:@"bulk-%d", i];
        NSInteger r = [logger infoWithName:nil msg:msg tag:nil];
        XCTAssertEqual(r, (NSInteger)0);
    }
    NSArray<NSDictionary *> *records = [self readBack:logger cryptKey:nil iv:nil];
    XCTAssertEqual(records.count, (NSUInteger)1000);
    XCTAssertEqualObjects(records.firstObject[@"msg"], @"bulk-0");
    XCTAssertEqualObjects(records.lastObject[@"msg"], @"bulk-999");
}

- (void)testLogSizeGreaterThanZeroAfterWrite {
    MXLogger *logger = [self newLogger];
    [logger infoWithName:nil msg:@"hello" tag:nil];
    XCTAssertTrue(logger.logSize > 0);
}

#pragma mark - AES加密往返

- (void)testEncryptedRoundtrip {
    MXLogger *logger = [MXLogger initializeWithNamespace:[self uniqueNs]
                                      diskCacheDirectory:[self newDir:@"enc"]
                                           storagePolicy:MXStoragePolicyYYYYMMDD
                                                fileName:nil fileHeader:nil
                                                cryptKey:kCryptKey iv:kIv];
    [logger infoWithName:@"enc" msg:@"secret-中文-message" tag:@"aes"];

    NSArray<NSDictionary *> *ok = [self readBack:logger cryptKey:kCryptKey iv:kIv];
    XCTAssertEqual(ok.count, (NSUInteger)1);
    XCTAssertEqualObjects(ok.firstObject[@"error_code"], @"0");
    XCTAssertEqualObjects(ok.firstObject[@"msg"], @"secret-中文-message");
}

- (void)testEncryptedWithDefaultIvUsesKey {
    MXLogger *logger = [MXLogger initializeWithNamespace:[self uniqueNs]
                                      diskCacheDirectory:[self newDir:@"enc2"]
                                           storagePolicy:MXStoragePolicyYYYYMMDD
                                                fileName:nil fileHeader:nil
                                                cryptKey:kCryptKey iv:nil];
    [logger infoWithName:nil msg:@"no-iv-message" tag:nil];

    NSArray<NSDictionary *> *ok = [self readBack:logger cryptKey:kCryptKey iv:nil];
    XCTAssertEqualObjects(ok.firstObject[@"error_code"], @"0");
    XCTAssertEqualObjects(ok.firstObject[@"msg"], @"no-iv-message");
}

- (void)testWrongKeyMarksErrorCode1NotCrash {
    MXLogger *logger = [MXLogger initializeWithNamespace:[self uniqueNs]
                                      diskCacheDirectory:[self newDir:@"enc3"]
                                           storagePolicy:MXStoragePolicyYYYYMMDD
                                                fileName:nil fileHeader:nil
                                                cryptKey:kCryptKey iv:kIv];
    [logger infoWithName:nil msg:@"secret" tag:nil];

    NSArray<NSDictionary *> *bad = [self readBack:logger cryptKey:@"0000000000000000" iv:kIv];
    XCTAssertEqual(bad.count, (NSUInteger)1);
    XCTAssertEqualObjects(bad.firstObject[@"error_code"], @"1");
}

#pragma mark - selectWithDiskCacheFilePath 边界

- (void)testSelectNonexistentFileReturnsEmpty {
    NSArray *r = [MXLogger selectWithDiskCacheFilePath:
                      [self.rootDir stringByAppendingPathComponent:@"not_exists.mx"]
                                              cryptKey:nil iv:nil];
    XCTAssertEqual(r.count, (NSUInteger)0);
}

- (void)testSelectRepeatedCallsStable {
    MXLogger *logger = [self newLogger];
    [logger infoWithName:nil msg:@"stable" tag:nil];
    NSString *file = [self currentLogFile:logger];
    for (int i = 0; i < 100; i++) {
        NSArray<NSDictionary *> *r = [MXLogger selectWithDiskCacheFilePath:file cryptKey:nil iv:nil];
        XCTAssertEqual(r.count, (NSUInteger)1);
        XCTAssertEqualObjects(r.firstObject[@"msg"], @"stable");
    }
}

#pragma mark - fileHeader

- (void)testFileHeaderIsFirstRecord {
    MXLogger *logger = [MXLogger initializeWithNamespace:[self uniqueNs]
                                      diskCacheDirectory:[self newDir:@"hdr"]
                                           storagePolicy:MXStoragePolicyYYYYMMDD
                                                fileName:nil
                                              fileHeader:@"app=1.0.0;platform=ios"
                                                cryptKey:nil iv:nil];
    [logger infoWithName:nil msg:@"normal" tag:nil];

    NSArray<NSDictionary *> *records = [self readBack:logger cryptKey:nil iv:nil];
    XCTAssertEqual(records.count, (NSUInteger)2);
    XCTAssertEqualObjects(records.firstObject[@"name"], kFileHeaderName);
    XCTAssertEqualObjects(records.firstObject[@"msg"], @"app=1.0.0;platform=ios");
    XCTAssertEqualObjects(records.lastObject[@"msg"], @"normal");
}

#pragma mark - 存储策略文件命名

- (NSString *)dateStringWithFormat:(NSString *)fmt {
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.dateFormat = fmt;
    return [f stringFromDate:NSDate.date];
}

- (void)testStoragePolicyFileNames {
    NSString *day = [self dateStringWithFormat:@"yyyy-MM-dd"];
    NSString *month = [self dateStringWithFormat:@"yyyy-MM"];

    // 按天(默认) 默认fileName=log
    MXLogger *daily = [MXLogger initializeWithNamespace:[self uniqueNs]
                                     diskCacheDirectory:[self newDir:@"sp1"]
                                          storagePolicy:MXStoragePolicyYYYYMMDD
                                               fileName:nil fileHeader:nil cryptKey:nil iv:nil];
    [daily infoWithName:nil msg:@"x" tag:nil];
    NSString *expectedDaily = [NSString stringWithFormat:@"%@_log.mx", day];
    XCTAssertEqualObjects([daily logFiles].firstObject[@"name"], expectedDaily);

    // 按小时 自定义fileName
    MXLogger *hourly = [MXLogger initializeWithNamespace:[self uniqueNs]
                                      diskCacheDirectory:[self newDir:@"sp2"]
                                           storagePolicy:MXStoragePolicyYYYYMMDDHH
                                                fileName:@"hourly" fileHeader:nil cryptKey:nil iv:nil];
    [hourly infoWithName:nil msg:@"x" tag:nil];
    NSString *hourlyName = [hourly logFiles].firstObject[@"name"];
    XCTAssertTrue([hourlyName hasPrefix:[day stringByAppendingString:@"-"]]);
    XCTAssertTrue([hourlyName hasSuffix:@"_hourly.mx"]);

    // 按周
    MXLogger *weekly = [MXLogger initializeWithNamespace:[self uniqueNs]
                                      diskCacheDirectory:[self newDir:@"sp3"]
                                           storagePolicy:MXStoragePolicyYYYYWW
                                                fileName:nil fileHeader:nil cryptKey:nil iv:nil];
    [weekly infoWithName:nil msg:@"x" tag:nil];
    NSString *weeklyName = [weekly logFiles].firstObject[@"name"];
    XCTAssertTrue([weeklyName containsString:@"w"]);
    XCTAssertTrue([weeklyName hasSuffix:@"_log.mx"]);

    // 按月
    MXLogger *monthly = [MXLogger initializeWithNamespace:[self uniqueNs]
                                       diskCacheDirectory:[self newDir:@"sp4"]
                                            storagePolicy:MXStoragePolicyYYYYMM
                                                 fileName:nil fileHeader:nil cryptKey:nil iv:nil];
    [monthly infoWithName:nil msg:@"x" tag:nil];
    NSString *expectedMonthly = [NSString stringWithFormat:@"%@_log.mx", month];
    XCTAssertEqualObjects([monthly logFiles].firstObject[@"name"], expectedMonthly);
}

#pragma mark - level 等级过滤

- (void)testLevelFiltering {
    MXLogger *logger = [self newLogger];
    logger.level = 2; // 只允许 warn(2)/error(3)/fatal(4)

    [logger debugWithName:nil msg:@"filtered-0" tag:nil];
    [logger infoWithName:nil msg:@"filtered-1" tag:nil];
    [logger warnWithName:nil msg:@"kept-2" tag:nil];
    [logger errorWithName:nil msg:@"kept-3" tag:nil];
    [logger fatalWithName:nil msg:@"kept-4" tag:nil];

    NSArray<NSDictionary *> *records = [self readBack:logger cryptKey:nil iv:nil];
    XCTAssertEqual(records.count, (NSUInteger)3);
    XCTAssertEqualObjects(records[0][@"msg"], @"kept-2");
    XCTAssertEqualObjects(records[2][@"msg"], @"kept-4");

    logger.level = 0;
    [logger debugWithName:nil msg:@"back" tag:nil];
    XCTAssertEqual([self readBack:logger cryptKey:nil iv:nil].count, (NSUInteger)4);
}

#pragma mark - enable / consoleEnable

- (void)testEnableToggle {
    MXLogger *logger = [self newLogger];
    [logger infoWithName:nil msg:@"before" tag:nil];
    NSString *file = [self currentLogFile:logger];

    logger.enable = NO;
    [logger infoWithName:nil msg:@"while-disabled" tag:nil];
    XCTAssertEqual([MXLogger selectWithDiskCacheFilePath:file cryptKey:nil iv:nil].count,
                   (NSUInteger)1, @"禁用期间的日志不应落盘");

    logger.enable = YES;
    [logger infoWithName:nil msg:@"after" tag:nil];
    XCTAssertEqual([MXLogger selectWithDiskCacheFilePath:file cryptKey:nil iv:nil].count,
                   (NSUInteger)2);
}

- (void)testConsoleEnableDoesNotAffectFileWrite {
    MXLogger *logger = [self newLogger];
    logger.consoleEnable = YES;
    [logger infoWithName:nil msg:@"with-console" tag:nil];
    logger.consoleEnable = NO;
    [logger infoWithName:nil msg:@"without-console" tag:nil];
    XCTAssertEqual([self readBack:logger cryptKey:nil iv:nil].count, (NSUInteger)2);
}

#pragma mark - 清理策略

- (void)testRemoveExpireDataByAge {
    MXLogger *logger = [self newLogger];
    [logger infoWithName:nil msg:@"current" tag:nil];
    NSString *old = [self fakeOldFileFor:logger size:100];

    logger.maxDiskAge = 60 * 60 * 24; // 1天
    [logger removeExpireData];

    XCTAssertFalse([self fileExists:old], @"2020年的旧文件应被清理");
    XCTAssertEqualObjects([self readBack:logger cryptKey:nil iv:nil].firstObject[@"msg"],
                          @"current", @"当前写入文件不能被删");
}

- (void)testRemoveExpireDataBySize {
    MXLogger *logger = [self newLogger];
    [logger infoWithName:nil msg:@"current" tag:nil];
    NSString *old = [self fakeOldFileFor:logger size:1024 * 1024];

    logger.maxDiskSize = 1024; // 1KB 上限
    [logger removeExpireData];

    XCTAssertFalse([self fileExists:old], @"超限时最旧文件应被删除");
    XCTAssertEqualObjects([self readBack:logger cryptKey:nil iv:nil].firstObject[@"msg"], @"current");
}

- (void)testRemoveExpireDataNoLimitKeepsFiles {
    MXLogger *logger = [self newLogger];
    [logger infoWithName:nil msg:@"current" tag:nil];
    NSString *old = [self fakeOldFileFor:logger size:100];

    [logger removeExpireData];
    XCTAssertTrue([self fileExists:old], @"未设置限制时不应删除文件");
}

- (void)testRemoveBeforeAllData {
    MXLogger *logger = [self newLogger];
    [logger infoWithName:nil msg:@"current" tag:nil];
    NSString *old = [self fakeOldFileFor:logger size:100];

    [logger removeBeforeAllData];

    XCTAssertFalse([self fileExists:old]);
    XCTAssertEqualObjects([self readBack:logger cryptKey:nil iv:nil].firstObject[@"msg"], @"current");
}

- (void)testRemoveAllData {
    MXLogger *logger = [self newLogger];
    [logger infoWithName:nil msg:@"a" tag:nil];
    NSString *old = [self fakeOldFileFor:logger size:100];

    [logger removeAllData];

    XCTAssertFalse([self fileExists:old]);
    XCTAssertEqual([logger logFiles].count, (NSUInteger)0, @"removeAllData删除全部文件且不重建");
    // 删除后继续写入不崩溃(README语义: 数据不再落盘)
    XCTAssertEqual([logger infoWithName:nil msg:@"after-clear" tag:nil], (NSInteger)0);
}

#pragma mark - logFiles

- (void)testLogFilesMetadata {
    MXLogger *logger = [self newLogger];
    [logger infoWithName:nil msg:@"hello" tag:nil];

    NSArray<NSDictionary *> *files = [logger logFiles];
    XCTAssertEqual(files.count, (NSUInteger)1);
    NSDictionary *f = files.firstObject;
    XCTAssertTrue([f[@"name"] hasSuffix:@".mx"]);
    XCTAssertTrue([f[@"size"] longLongValue] > 0);
    XCTAssertTrue([f[@"create_timestamp"] longLongValue] > 0);
    XCTAssertTrue([f[@"last_timestamp"] longLongValue] >= [f[@"create_timestamp"] longLongValue]);
}

#pragma mark - loggerKey 类方法族

- (void)testClassMethodsWriteViaLoggerKey {
    MXLogger *logger = [self newLogger];
    NSString *key = logger.loggerKey;

    XCTAssertEqual([MXLogger debugWithLoggerKey:key name:@"kn" msg:@"k0" tag:@"kt"], (NSInteger)0);
    XCTAssertEqual([MXLogger infoWithLoggerKey:key name:nil msg:@"k1" tag:nil], (NSInteger)0);
    XCTAssertEqual([MXLogger warnWithLoggerKey:key name:nil msg:@"k2" tag:nil], (NSInteger)0);
    XCTAssertEqual([MXLogger errorWithLoggerKey:key name:nil msg:@"k3" tag:nil], (NSInteger)0);
    XCTAssertEqual([MXLogger fatalWithLoggerKey:key name:nil msg:@"k4" tag:nil], (NSInteger)0);

    NSArray<NSDictionary *> *records = [self readBack:logger cryptKey:nil iv:nil];
    XCTAssertEqual(records.count, (NSUInteger)5);
    for (NSUInteger i = 0; i < 5; i++) {
        NSString *expectedLevel = [NSString stringWithFormat:@"%lu", (unsigned long)i];
        NSString *expectedMsg = [NSString stringWithFormat:@"k%lu", (unsigned long)i];
        XCTAssertEqualObjects(records[i][@"level"], expectedLevel);
        XCTAssertEqualObjects(records[i][@"msg"], expectedMsg);
    }
    XCTAssertEqualObjects(records.firstObject[@"name"], @"kn");
    XCTAssertEqualObjects(records.firstObject[@"tag"], @"kt");
}

- (void)testValueForLoggerKey {
    MXLogger *logger = [self newLogger];
    XCTAssertEqual([MXLogger valueForLoggerKey:logger.loggerKey], logger);
    XCTAssertNil([MXLogger valueForLoggerKey:@"ffffffffffffffffffffffffffffffff"],
                 @"不存在的key应返回nil");
}

- (void)testClassMethodWithUnknownLoggerKeyIsSafe {
    // ObjC对nil发消息安全返回0, 不应崩溃
    NSInteger r = [MXLogger infoWithLoggerKey:@"ffffffffffffffffffffffffffffffff"
                                         name:nil msg:@"m" tag:nil];
    XCTAssertEqual(r, (NSInteger)0);
}

#pragma mark - 销毁与重建

- (void)testDestroyAndReopenAppendsNotOverwrite {
    NSString *ns = [self uniqueNs];
    NSString *dir = [self newDir:@"destroy"];
    MXLogger *logger = [MXLogger initializeWithNamespace:ns diskCacheDirectory:dir
                                           storagePolicy:MXStoragePolicyYYYYMMDD
                                                fileName:nil fileHeader:nil cryptKey:nil iv:nil];
    [logger infoWithName:nil msg:@"first" tag:nil];
    NSString *file = [self currentLogFile:logger];

    [MXLogger destroyWithNamespace:ns diskCacheDirectory:dir];

    MXLogger *reopened = [MXLogger initializeWithNamespace:ns diskCacheDirectory:dir
                                             storagePolicy:MXStoragePolicyYYYYMMDD
                                                  fileName:nil fileHeader:nil cryptKey:nil iv:nil];
    [reopened infoWithName:nil msg:@"second" tag:nil];

    // select返回倒序: 最新的"second"在前
    NSArray<NSDictionary *> *records = [MXLogger selectWithDiskCacheFilePath:file cryptKey:nil iv:nil];
    XCTAssertEqual(records.count, (NSUInteger)2, @"destroy再重开不应覆盖已有数据");
    XCTAssertEqualObjects(records.firstObject[@"msg"], @"second");
    XCTAssertEqualObjects(records.lastObject[@"msg"], @"first");
    [MXLogger destroyWithNamespace:ns diskCacheDirectory:dir];
}

- (void)testDestroyWithLoggerKey {
    NSString *ns = [self uniqueNs];
    NSString *dir = [self newDir:@"destroy2"];
    MXLogger *logger = [MXLogger initializeWithNamespace:ns diskCacheDirectory:dir
                                           storagePolicy:MXStoragePolicyYYYYMMDD
                                                fileName:nil fileHeader:nil cryptKey:nil iv:nil];
    NSString *key = logger.loggerKey;
    [logger infoWithName:nil msg:@"x" tag:nil];

    [MXLogger destroyWithLoggerKey:key];
    XCTAssertNil([MXLogger valueForLoggerKey:key], @"销毁后key应查不到实例");

    MXLogger *reopened = [MXLogger initializeWithNamespace:ns diskCacheDirectory:dir
                                             storagePolicy:MXStoragePolicyYYYYMMDD
                                                  fileName:nil fileHeader:nil cryptKey:nil iv:nil];
    XCTAssertEqualObjects(reopened.loggerKey, key);
    [reopened infoWithName:nil msg:@"y" tag:nil];
    XCTAssertEqual([self readBack:reopened cryptKey:nil iv:nil].count, (NSUInteger)2);
    [MXLogger destroyWithLoggerKey:key];
}

#pragma mark - 多实例隔离

- (void)testMultiInstanceIsolation {
    MXLogger *a = [self newLogger];
    MXLogger *b = [self newLogger];

    [a infoWithName:nil msg:@"only-a" tag:nil];
    [b infoWithName:nil msg:@"only-b-1" tag:nil];
    [b infoWithName:nil msg:@"only-b-2" tag:nil];

    XCTAssertEqual([self readBack:a cryptKey:nil iv:nil].count, (NSUInteger)1);
    XCTAssertEqual([self readBack:b cryptKey:nil iv:nil].count, (NSUInteger)2);
}

#pragma mark - 性能

- (void)testWritePerformance {
    MXLogger *logger = [self newLogger];
    logger.consoleEnable = NO;
    [self measureBlock:^{
        for (int i = 0; i < 10000; i++) {
            [logger infoWithName:@"perf"
                             msg:@"performance test message 134 bytes ................"
                             tag:@"perf"];
        }
    }];
}

@end
