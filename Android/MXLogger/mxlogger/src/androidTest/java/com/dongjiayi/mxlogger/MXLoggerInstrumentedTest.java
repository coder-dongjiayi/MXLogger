package com.dongjiayi.mxlogger;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNotSame;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertTrue;

import android.content.Context;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.UUID;

/**
 * MXLogger Java API 设备端单元测试 (需要真机或模拟器)
 *
 * 运行: ./gradlew :mxlogger:connectedDefaultCppDebugAndroidTest
 *
 * 说明: Java层没有日志解析API, 内容断言通过直接解析日志文件的
 * 二进制结构完成: 文件头4字节(小端uint32)为数据区末尾偏移,
 * 之后每条记录为 [4字节长度][flatbuffers数据] 的TLV结构;
 * flatbuffers内的字符串是原始UTF-8, 明文写入时可直接按字节搜索。
 */
@RunWith(AndroidJUnit4.class)
public class MXLoggerInstrumentedTest {

    private static final String CRYPT_KEY = "abcdefg123456789";
    private static final String IV = "0123456789abcdef";

    private static int nsCounter = 0;

    private Context context;
    private File rootDir;

    @Before
    public void setUp() {
        context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        rootDir = new File(context.getFilesDir(), "mxlogger_tests_" + UUID.randomUUID());
        assertTrue(rootDir.mkdirs());
    }

    // ------------------------------------------------------------------
    // helpers

    private String uniqueNs() {
        return "com.test.mxlogger.android.ns" + (nsCounter++);
    }

    private File newDir(String tag) {
        File dir = new File(rootDir, tag + nsCounter);
        //noinspection ResultOfMethodCallIgnored
        dir.mkdirs();
        return dir;
    }

    private MXLogger newLogger() {
        return new MXLogger(context, uniqueNs(), newDir("d").getAbsolutePath(),
                MXStoragePolicyType.YYYY_MM_DD, null, null, null, null);
    }

    /** 当前正在写入的日志文件 (目录中唯一的.mx文件) */
    private File currentLogFile(MXLogger logger) {
        File dir = new File(logger.getDiskCachePath());
        File[] files = dir.listFiles((d, name) -> name.endsWith(".mx"));
        assertNotNull("应该已生成日志文件", files);
        assertEquals("目录中应只有一个日志文件", 1, files.length);
        return files[0];
    }

    private static byte[] readAll(File f) throws IOException {
        try (FileInputStream in = new FileInputStream(f)) {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
            return out.toByteArray();
        }
    }

    private static long uint32LE(byte[] b, int pos) {
        return (b[pos] & 0xFFL) | ((b[pos + 1] & 0xFFL) << 8)
                | ((b[pos + 2] & 0xFFL) << 16) | ((b[pos + 3] & 0xFFL) << 24);
    }

    /** 按TLV结构统计文件中的记录条数 */
    private static int recordCount(File f) throws IOException {
        byte[] bytes = readAll(f);
        if (bytes.length < 4) return 0;
        long dataEnd = uint32LE(bytes, 0);
        int pos = 4;
        int count = 0;
        while (pos <= dataEnd && pos + 4 <= bytes.length) {
            long len = uint32LE(bytes, pos);
            if (len == 0 || pos + 4 + len > bytes.length) break;
            pos += 4 + (int) len;
            count++;
        }
        return count;
    }

    /** 明文写入时 flatbuffers 内的字符串是原始UTF-8, 可直接按字节搜索 */
    private static boolean fileContains(File f, String needle) throws IOException {
        byte[] haystack = readAll(f);
        byte[] target = needle.getBytes(StandardCharsets.UTF_8);
        outer:
        for (int i = 0; i + target.length <= haystack.length; i++) {
            for (int j = 0; j < target.length; j++) {
                if (haystack[i + j] != target[j]) continue outer;
            }
            return true;
        }
        return false;
    }

    private File fakeOldFile(MXLogger logger, int sizeBytes) throws IOException {
        File f = new File(logger.getDiskCachePath(), "2020-01-01_log.mx");
        byte[] data = new byte[sizeBytes];
        try (java.io.FileOutputStream out = new java.io.FileOutputStream(f)) {
            out.write(data);
        }
        assertTrue(f.setLastModified(1577836800000L)); // 2020-01-01
        return f;
    }

    // ------------------------------------------------------------------
    // 初始化与属性

    @Test
    public void loggerKeyIs32CharsAndStable() {
        String ns = uniqueNs();
        String dir = newDir("key").getAbsolutePath();
        MXLogger a = new MXLogger(context, ns, dir,
                MXStoragePolicyType.YYYY_MM_DD, null, null, null, null);
        assertNotNull(a.getLoggerKey());
        assertEquals(32, a.getLoggerKey().length());

        // 同 namespace+directory -> 同key
        MXLogger b = new MXLogger(context, ns, dir,
                MXStoragePolicyType.YYYY_MM_DD, null, null, null, null);
        assertEquals(a.getLoggerKey(), b.getLoggerKey());

        // 不同 namespace -> 不同key
        MXLogger c = newLogger();
        assertNotEquals(a.getLoggerKey(), c.getLoggerKey());
    }

    @Test
    public void sharedInstancesSeeSameConfiguration() {
        // 回归: 配置曾按Java对象缓存, 共享同一native对象的第二个实例读到过期默认值;
        // 现在getter直查native, 任一实例的修改对所有实例实时可见
        String ns = uniqueNs();
        String dir = newDir("share").getAbsolutePath();
        MXLogger a = new MXLogger(context, ns, dir,
                MXStoragePolicyType.YYYY_MM_DD, null, null, null, null);
        MXLogger b = new MXLogger(context, ns, dir,
                MXStoragePolicyType.YYYY_MM_DD, null, null, null, null);

        a.setLevel(3);
        a.setConsoleEnable(true);
        a.setMaxDiskAge(3600);
        a.setMaxDiskSize(2048);
        a.setEnable(false);

        assertEquals("level应对共享实例实时一致", 3, b.getLevel());
        assertTrue(b.isConsoleEnable());
        assertEquals(3600, b.getMaxDiskAge());
        assertEquals(2048, b.getMaxDiskSize());
        assertFalse("enable应对共享实例实时一致", b.isEnable());

        a.setEnable(true);
        a.setConsoleEnable(false);
    }

    @Test
    public void initializeFactoryReturnsSameInstance() {
        // initialize工厂: 同nameSpace+directory复用同一个Java实例(与iOS/Flutter对齐)
        String ns = uniqueNs();
        String dir = newDir("factory").getAbsolutePath();
        MXLogger a = MXLogger.initialize(context, ns, dir,
                MXStoragePolicyType.YYYY_MM_DD, null, null, null, null);
        MXLogger b = MXLogger.initialize(context, ns, dir,
                MXStoragePolicyType.YYYY_MM_DD, null, null, null, null);
        assertSame("同参数initialize应返回同一个Java实例", a, b);

        MXLogger c = MXLogger.initialize(context, uniqueNs(), null,
                MXStoragePolicyType.YYYY_MM_DD, null, null, null, null);
        assertNotSame(a, c);
    }

    @Test
    public void destroyInvalidatesAllJavaInstances() throws IOException {
        // 回归: destroy后旧实例的句柄必须失效, 后续调用安全短路而不是use-after-free
        String ns = uniqueNs();
        String dir = newDir("invalidate").getAbsolutePath();
        MXLogger a = new MXLogger(context, ns, dir,
                MXStoragePolicyType.YYYY_MM_DD, null, null, null, null);
        MXLogger b = new MXLogger(context, ns, dir,
                MXStoragePolicyType.YYYY_MM_DD, null, null, null, null);
        assertEquals(0, a.info("t", "n", "before"));

        MXLogger.destroy(context, ns, dir);

        // -4: 无效句柄; 所有读写都不得触碰已释放的native对象
        assertEquals(-4, a.info("t", "n", "after"));
        assertEquals(-4, b.info("t", "n", "after"));
        assertFalse(a.isEnable());
        assertEquals(0, a.getLogSize());
        a.removeExpireData();
        b.removeAll();
    }

    @Test
    public void diskCachePathContainsDirectoryAndNamespace() {
        String ns = uniqueNs();
        String dir = newDir("path").getAbsolutePath();
        MXLogger logger = new MXLogger(context, ns, dir,
                MXStoragePolicyType.YYYY_MM_DD, null, null, null, null);
        assertTrue(logger.getDiskCachePath().contains(dir));
        assertTrue(logger.getDiskCachePath().contains(ns));
        assertTrue("初始化时应创建日志目录", new File(logger.getDiskCachePath()).isDirectory());
    }

    @Test
    public void defaultDirectoryConstructorsWork() throws IOException {
        // 便捷构造(默认filesDir目录)都可正常创建并写入
        String ns1 = uniqueNs();
        MXLogger l1 = new MXLogger(context, ns1, "header");
        assertEquals(0, l1.info("t", "n", "m"));
        MXLogger.destroy(context, ns1, null);

        String ns2 = uniqueNs();
        MXLogger l2 = new MXLogger(context, ns2, "header", CRYPT_KEY, IV);
        assertEquals(0, l2.info("t", "n", "m"));
        MXLogger.destroy(context, ns2, null);
    }

    @Test
    public void errorDescIsEmptyWhenNoError() {
        MXLogger logger = newLogger();
        String desc = logger.getErrorDesc();
        assertTrue(desc == null || desc.isEmpty());
    }

    // ------------------------------------------------------------------
    // 写入 (含 enable 默认值回归验证)

    @Test
    public void enableDefaultsToTrueAndWritesByDefault() throws IOException {
        // 回归: enable字段默认必须为true, 否则不调用setEnable(true)就不写日志
        MXLogger logger = newLogger();
        assertTrue("enable默认应为true", logger.isEnable());
        assertEquals(0, logger.info("tag", "name", "default-write"));
        assertEquals(1, recordCount(currentLogFile(logger)));
    }

    @Test
    public void fiveLevelsWriteAndContentPersisted() throws IOException {
        MXLogger logger = newLogger();
        assertEquals(0, logger.debug("t0", "n0", "d-msg"));
        assertEquals(0, logger.info("t1", "n1", "i-msg"));
        assertEquals(0, logger.warn("t2", "n2", "w-msg"));
        assertEquals(0, logger.error("t3", "n3", "e-msg"));
        assertEquals(0, logger.fatal("t4", "n4", "f-msg"));

        File file = currentLogFile(logger);
        assertEquals(5, recordCount(file));
        assertTrue(fileContains(file, "d-msg"));
        assertTrue(fileContains(file, "f-msg"));
        assertTrue(fileContains(file, "n2"));
        assertTrue(fileContains(file, "t3"));
    }

    @Test
    public void unicodeContentPersisted() throws IOException {
        MXLogger logger = newLogger();
        String cn = "中文消息🚀引号换行";
        assertEquals(0, logger.info("标签1,标签2", null, cn));
        File file = currentLogFile(logger);
        assertEquals(1, recordCount(file));
        assertTrue(fileContains(file, cn));
        assertTrue(fileContains(file, "标签1,标签2"));
    }

    @Test
    public void bulkWrite1000NoLoss() throws IOException {
        MXLogger logger = newLogger();
        for (int i = 0; i < 1000; i++) {
            assertEquals(0, logger.info(null, null, "bulk-" + i));
        }
        File file = currentLogFile(logger);
        assertEquals(1000, recordCount(file));
        assertTrue(fileContains(file, "bulk-0"));
        assertTrue(fileContains(file, "bulk-999"));
    }

    @Test
    public void logSizeGreaterThanZeroAfterWrite() {
        MXLogger logger = newLogger();
        assertEquals(0, logger.info(null, null, "hello"));
        assertTrue(logger.getLogSize() > 0);
    }

    // ------------------------------------------------------------------
    // enable / level / consoleEnable

    @Test
    public void setEnableFalseStopsWriting() throws IOException {
        MXLogger logger = newLogger();
        assertEquals(0, logger.info(null, null, "before"));
        File file = currentLogFile(logger);
        assertEquals(1, recordCount(file));

        logger.setEnable(false);
        assertFalse(logger.isEnable());
        assertEquals(0, logger.info(null, null, "while-disabled"));
        assertEquals("禁用期间的日志不应落盘", 1, recordCount(file));

        logger.setEnable(true);
        assertEquals(0, logger.info(null, null, "after"));
        assertEquals(2, recordCount(file));
    }

    @Test
    public void levelFiltering() throws IOException {
        MXLogger logger = newLogger();
        logger.setLevel(2); // 只允许 warn(2)/error(3)/fatal(4)
        assertEquals(2, logger.getLevel());

        logger.debug(null, null, "filtered-0");
        logger.info(null, null, "filtered-1");
        logger.warn(null, null, "kept-2");

        File file = currentLogFile(logger);
        assertEquals(1, recordCount(file));
        assertTrue(fileContains(file, "kept-2"));
        assertFalse(fileContains(file, "filtered-0"));

        logger.setLevel(0);
        logger.debug(null, null, "back");
        assertEquals(2, recordCount(file));
    }

    @Test
    public void consoleEnableDoesNotAffectFileWrite() throws IOException {
        MXLogger logger = newLogger();
        logger.setConsoleEnable(true);
        assertTrue(logger.isConsoleEnable());
        logger.info(null, null, "with-console");
        logger.setConsoleEnable(false);
        logger.info(null, null, "without-console");
        assertEquals(2, recordCount(currentLogFile(logger)));
    }

    // ------------------------------------------------------------------
    // 加密

    @Test
    public void encryptedWritePlaintextAbsent() throws IOException {
        MXLogger logger = new MXLogger(context, uniqueNs(), newDir("enc").getAbsolutePath(),
                MXStoragePolicyType.YYYY_MM_DD, null, null, CRYPT_KEY, IV);
        String secret = "secret-plaintext-should-not-appear";
        assertEquals(0, logger.info("tag", "name", secret));

        File file = currentLogFile(logger);
        assertEquals("TLV结构不加密, 记录数应可解析", 1, recordCount(file));
        assertFalse("加密后不应出现明文", fileContains(file, secret));
    }

    // ------------------------------------------------------------------
    // fileHeader

    @Test
    public void fileHeaderWrittenAsFirstRecord() throws IOException {
        MXLogger logger = new MXLogger(context, uniqueNs(), newDir("hdr").getAbsolutePath(),
                MXStoragePolicyType.YYYY_MM_DD, null, "app=1.0.0;platform=android", null, null);
        assertEquals(0, logger.info(null, null, "normal"));

        File file = currentLogFile(logger);
        assertEquals("头记录+1条日志", 2, recordCount(file));
        assertTrue(fileContains(file, "app=1.0.0;platform=android"));
        assertTrue(fileContains(file, "com.djy.mxlogger.fileHeader"));
    }

    // ------------------------------------------------------------------
    // 存储策略文件命名

    @Test
    public void storagePolicyFileNames() {
        String day = new SimpleDateFormat("yyyy-MM-dd", Locale.US).format(new Date());
        String month = new SimpleDateFormat("yyyy-MM", Locale.US).format(new Date());

        MXLogger daily = new MXLogger(context, uniqueNs(), newDir("sp1").getAbsolutePath(),
                MXStoragePolicyType.YYYY_MM_DD, null, null, null, null);
        daily.info(null, null, "x");
        assertEquals(day + "_log.mx", currentLogFile(daily).getName());

        MXLogger hourly = new MXLogger(context, uniqueNs(), newDir("sp2").getAbsolutePath(),
                MXStoragePolicyType.YYYY_MM_DD_HH, "hourly", null, null, null);
        hourly.info(null, null, "x");
        String hourlyName = currentLogFile(hourly).getName();
        assertTrue(hourlyName.startsWith(day + "-"));
        assertTrue(hourlyName.endsWith("_hourly.mx"));

        MXLogger weekly = new MXLogger(context, uniqueNs(), newDir("sp3").getAbsolutePath(),
                MXStoragePolicyType.YYYY_WW, null, null, null, null);
        weekly.info(null, null, "x");
        String weeklyName = currentLogFile(weekly).getName();
        assertTrue(weeklyName.contains("w"));
        assertTrue(weeklyName.endsWith("_log.mx"));

        MXLogger monthly = new MXLogger(context, uniqueNs(), newDir("sp4").getAbsolutePath(),
                MXStoragePolicyType.YYYY_MM, null, null, null, null);
        monthly.info(null, null, "x");
        assertEquals(month + "_log.mx", currentLogFile(monthly).getName());
    }

    // ------------------------------------------------------------------
    // 清理策略

    @Test
    public void removeExpireDataByAge() throws IOException {
        MXLogger logger = newLogger();
        logger.info(null, null, "current");
        File old = fakeOldFile(logger, 100);

        logger.setMaxDiskAge(60 * 60 * 24); // 1天
        assertEquals(60 * 60 * 24, logger.getMaxDiskAge());
        logger.removeExpireData();

        assertFalse("2020年的旧文件应被清理", old.exists());
        assertEquals("当前写入文件不能被删", 1, recordCount(currentLogFile(logger)));
    }

    @Test
    public void removeExpireDataBySize() throws IOException {
        MXLogger logger = newLogger();
        logger.info(null, null, "current");
        File old = fakeOldFile(logger, 1024 * 1024);

        logger.setMaxDiskSize(1024); // 1KB 上限
        assertEquals(1024, logger.getMaxDiskSize());
        logger.removeExpireData();

        assertFalse("超限时最旧文件应被删除", old.exists());
        assertEquals(1, recordCount(currentLogFile(logger)));
    }

    @Test
    public void removeExpireDataNoLimitKeepsFiles() throws IOException {
        MXLogger logger = newLogger();
        logger.info(null, null, "current");
        File old = fakeOldFile(logger, 100);

        logger.removeExpireData();
        assertTrue("未设置限制时不应删除文件", old.exists());
    }

    @Test
    public void removeBeforeAllDataKeepsCurrentFile() throws IOException {
        MXLogger logger = newLogger();
        logger.info(null, null, "current");
        File old = fakeOldFile(logger, 100);

        logger.removeBeforeAllData();

        assertFalse(old.exists());
        assertEquals(1, recordCount(currentLogFile(logger)));
    }

    @Test
    public void removeAllDeletesEverything() throws IOException {
        MXLogger logger = newLogger();
        logger.info(null, null, "a");
        File old = fakeOldFile(logger, 100);
        File dir = new File(logger.getDiskCachePath());

        logger.removeAll();

        assertFalse(old.exists());
        File[] left = dir.listFiles((d, name) -> name.endsWith(".mx"));
        assertTrue("removeAll删除全部文件且不重建", left == null || left.length == 0);
        // 删除后继续写入不崩溃(README语义: 数据不再落盘)
        assertEquals(0, logger.info(null, null, "after-clear"));
    }

    // ------------------------------------------------------------------
    // loggerKey 静态写入

    @Test
    public void staticLogViaLoggerKey() throws IOException {
        MXLogger logger = newLogger();
        String key = logger.getLoggerKey();

        assertEquals(0, MXLogger.log(key, "kt", 1, "kn", "via-key"));

        File file = currentLogFile(logger);
        assertEquals(1, recordCount(file));
        assertTrue(fileContains(file, "via-key"));
    }

    // ------------------------------------------------------------------
    // 销毁与重建

    @Test
    public void destroyAndReopenAppendsNotOverwrite() throws IOException {
        String ns = uniqueNs();
        String dir = newDir("destroy").getAbsolutePath();
        MXLogger logger = new MXLogger(context, ns, dir,
                MXStoragePolicyType.YYYY_MM_DD, null, null, null, null);
        logger.info(null, null, "first");
        File file = currentLogFile(logger);

        MXLogger.destroy(context, ns, dir);

        MXLogger reopened = new MXLogger(context, ns, dir,
                MXStoragePolicyType.YYYY_MM_DD, null, null, null, null);
        reopened.info(null, null, "second");

        assertEquals("destroy再重开不应覆盖已有数据", 2, recordCount(file));
        assertTrue(fileContains(file, "first"));
        assertTrue(fileContains(file, "second"));
        MXLogger.destroy(context, ns, dir);
    }

    @Test
    public void destroyByLoggerKeyAndReopen() throws IOException {
        String ns = uniqueNs();
        String dir = newDir("destroy2").getAbsolutePath();
        MXLogger logger = new MXLogger(context, ns, dir,
                MXStoragePolicyType.YYYY_MM_DD, null, null, null, null);
        String key = logger.getLoggerKey();
        logger.info(null, null, "x");

        MXLogger.destroy(key);

        MXLogger reopened = new MXLogger(context, ns, dir,
                MXStoragePolicyType.YYYY_MM_DD, null, null, null, null);
        assertEquals(key, reopened.getLoggerKey());
        reopened.info(null, null, "y");
        assertEquals(2, recordCount(currentLogFile(reopened)));
        MXLogger.destroy(key);
    }

    // ------------------------------------------------------------------
    // 多实例隔离

    @Test
    public void multiInstanceIsolation() throws IOException {
        MXLogger a = newLogger();
        MXLogger b = newLogger();

        a.info(null, null, "only-a");
        b.info(null, null, "only-b-1");
        b.info(null, null, "only-b-2");

        assertEquals(1, recordCount(currentLogFile(a)));
        assertEquals(2, recordCount(currentLogFile(b)));
        assertFalse(fileContains(currentLogFile(a), "only-b-1"));
    }
}
