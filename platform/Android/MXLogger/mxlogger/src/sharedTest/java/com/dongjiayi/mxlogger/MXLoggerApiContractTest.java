package com.dongjiayi.mxlogger;

import android.content.Context;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.io.ByteArrayOutputStream;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.regex.Pattern;
import static org.junit.Assert.*;

/** The same API assertions run with real JNI/Core on a device and on the host. */
public abstract class MXLoggerApiContractTest {
    private static final String KEY = "0123456789abcdef";
    private static final String IV = "abcdef0123456789";
    private final List<String> tokens = new ArrayList<>();
    private final List<File> directories = new ArrayList<>();
    private Context context;
    private File rootDir;

    protected abstract Context testContext();

    @Before public void createContext() {
        context = testContext();
        rootDir = new File(context.getFilesDir(), "mxlogger_contract_" + UUID.randomUUID());
        assertTrue(rootDir.mkdirs());
    }

    @After public void releaseLoggers() {
        for (String token : tokens) MXLogger.destroy(token);
        for (File directory : directories) delete(directory);
        delete(rootDir);
    }

    private String namespace() { return "com.test.host." + UUID.randomUUID(); }
    private MXLogger track(MXLogger logger) {
        assertNotNull(logger);
        assertNotNull(logger.getLoggerToken());
        tokens.add(logger.getLoggerToken());
        directories.add(new File(logger.getDiskCachePath()));
        return logger;
    }
    private MXLogger create(boolean encrypted) {
        return track(new MXLogger(context, namespace(), rootDir.getAbsolutePath(),
                MXStoragePolicyType.YYYY_MM_DD, "api", null, encrypted ? KEY : null, encrypted ? IV : null));
    }
    private File current(MXLogger logger) {
        File[] files = new File(logger.getDiskCachePath()).listFiles((dir, name) -> name.endsWith(".mx"));
        assertNotNull(files); assertEquals(1, files.length);
        return files[0];
    }
    private void field(String json, String name, String value) {
        assertTrue(json, Pattern.compile("\"" + name + "\"\\s*:\\s*\"" + Pattern.quote(value) + "\"").matcher(json).find());
    }
    private String[] read(MXLogger logger, boolean encrypted) {
        return MXLogger.selectWithFilePath(current(logger).getAbsolutePath(), encrypted ? KEY : null, encrypted ? IV : null);
    }

    private void write(File file, byte[] bytes) throws Exception {
        try (FileOutputStream out = new FileOutputStream(file)) { out.write(bytes); }
    }
    private byte[] bytes(File file) throws Exception {
        try (FileInputStream in = new FileInputStream(file); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[4096]; int count;
            while ((count = in.read(buffer)) != -1) out.write(buffer, 0, count);
            return out.toByteArray();
        }
    }
    private void delete(File file) {
        if (file == null || !file.exists()) return;
        File[] children = file.listFiles();
        if (children != null) for (File child : children) delete(child);
        assertTrue("Cannot remove test fixture " + file, file.delete());
    }

    @Test public void versionAndEveryFactoryAndConstructorOverload() {
        assertEquals("2.3.0", MXLogger.coreVersion());
        String ns = namespace();
        MXLogger full = track(MXLogger.initialize(context, ns, rootDir.getAbsolutePath(),
                null, "factory", "header", null, null));
        assertSame(full, MXLogger.initialize(context, ns, rootDir.getAbsolutePath(),
                null, "factory", "ignored second header", null, null));
        MXLogger[] loggers = {
                full,
                track(MXLogger.initialize(context, namespace(), "header")),
                track(MXLogger.initialize(context, namespace(), "header", KEY, IV)),
                track(new MXLogger(context, namespace(), "header")),
                track(new MXLogger(context, namespace(), "header", KEY, IV)),
                track(new MXLogger(context, "header", namespace(), rootDir.getAbsolutePath()))
        };
        for (int index = 0; index < loggers.length; index++) {
            MXLogger logger = loggers[index];
            assertEquals(0, logger.info("api", "overload", "body"));
            assertTrue(new File(logger.getDiskCachePath()).isDirectory());
            boolean encrypted = index == 2 || index == 4;
            String[] rows = read(logger, encrypted);
            assertEquals(2, rows.length);
            field(rows[0], "msg", "body");
            field(rows[1], "msg", "header");
        }
    }

    @Test public void allLevelsMetadataAndPlainEncryptedReadback() throws Exception {
        for (boolean encrypted : new boolean[]{false, true}) {
            MXLogger logger = create(encrypted);
            assertEquals(0, logger.debug("tag", "name", "debug"));
            assertEquals(0, logger.info("tag", "name", "info"));
            assertEquals(0, logger.warn("tag", "name", "warn"));
            assertEquals(0, logger.error("tag", "name", "error"));
            assertEquals(0, logger.fatal("tag", "name", "fatal"));
            assertEquals(0, logger.log(null, 1, null, "generic 中文"));
            assertEquals(0, MXLogger.log(logger.getLoggerToken(), "token", 2, "static", "token"));
            String[] rows = read(logger, encrypted);
            assertEquals(7, rows.length);
            field(rows[0], "msg", "token"); field(rows[0], "level", "2");
            field(rows[1], "msg", "generic 中文");
            field(rows[6], "msg", "debug"); field(rows[6], "tag", "tag");
            for (String row : rows) field(row, "error_code", "0");
            String[] metadata = logger.logFiles();
            assertEquals(1, metadata.length);
            field(metadata[0], "name", current(logger).getName());
            assertTrue(metadata[0].contains("last_timestamp"));
            assertTrue(metadata[0].contains("create_timestamp"));
            assertTrue(logger.getLogSize() > 0);
            assertTrue(logger.getErrorDesc().isEmpty());
            if (encrypted) {
                String[] wrong = MXLogger.selectWithFilePath(current(logger).getAbsolutePath(), "wrong", IV);
                assertEquals(rows.length, wrong.length);
                for (String row : wrong) field(row, "error_code", "1");
                assertFalse(new String(bytes(current(logger)), StandardCharsets.UTF_8).contains("generic 中文"));
            }
        }
        String[] absent = MXLogger.selectWithFilePath(new File(rootDir, "absent.mx").getAbsolutePath(), null, null);
        assertTrue(absent == null || absent.length == 0);
    }

    @SuppressWarnings("deprecation")
    @Test public void sharedConfigurationAndDisabledWrites() {
        MXLogger logger = create(false);
        assertTrue(logger.isEnable()); assertFalse(logger.isConsoleEnable());
        assertEquals(0, logger.getLevel()); assertEquals(0, logger.getMaxDiskAge()); assertEquals(0, logger.getMaxDiskSize());
        assertEquals(logger.getLoggerToken(), logger.getLoggerKey());
        logger.setEnable(false);
        logger.setLevel(3); logger.setConsoleEnable(true);
        logger.setMaxDiskAge(7200); logger.setMaxDiskSize(1234567);
        assertFalse(logger.isEnable()); assertTrue(logger.isConsoleEnable());
        assertEquals(3, logger.getLevel()); assertEquals(7200, logger.getMaxDiskAge()); assertEquals(1234567, logger.getMaxDiskSize());
        assertEquals(0, logger.fatal(null, null, "disabled"));
        assertEquals(0, read(logger, false).length);
        logger.setEnable(true); logger.setConsoleEnable(false);
        assertEquals(0, logger.info(null, null, "filtered"));
        assertEquals(0, logger.error(null, null, "stored"));
        assertEquals(1, read(logger, false).length);
        field(read(logger, false)[0], "msg", "stored");
    }

    @Test public void cleanupPreservesCurrentAndRemovesInactiveFiles() throws Exception {
        MXLogger logger = create(false);
        logger.info("api", "cleanup", "keep");
        File active = current(logger);
        File inactive = new File(active.getParentFile(), "inactive.mx");
        write(inactive, new byte[128]);
        assertTrue(inactive.setLastModified(0));
        logger.setMaxDiskAge(60); logger.removeExpireData();
        assertFalse(inactive.exists()); assertTrue(active.exists());
        write(inactive, new byte[128]);
        logger.setMaxDiskAge(0); logger.setMaxDiskSize(1); logger.removeExpireData();
        assertFalse(inactive.exists()); assertTrue(active.exists());
        write(inactive, new byte[128]); logger.removeBeforeAllData();
        assertFalse(inactive.exists()); assertTrue(active.exists());
        write(inactive, new byte[128]); logger.removeAll();
        assertFalse(inactive.exists()); assertTrue(active.exists());
        assertEquals(1, read(logger, false).length);
        logger.info(null, null, "after cleanup");
        assertEquals(2, read(logger, false).length);
    }

    @Test public void bothDestroyOverloadsInvalidateOldObjectsAndReopenSafely() {
        for (boolean byToken : new boolean[]{false, true}) {
            String ns = namespace();
            MXLogger logger = track(new MXLogger(context, ns, "header"));
            logger.info(null, null, "before");
            if (byToken) MXLogger.destroy(logger.getLoggerToken()); else MXLogger.destroy(context, ns, null);
            assertEquals(-4, logger.log(null, 1, null, "ignored"));
            assertNull(logger.getLoggerToken()); assertFalse(logger.isEnable());
            assertEquals(0, logger.getLogSize()); assertEquals("", logger.getDiskCachePath());
            assertFalse(logger.getErrorDesc().isEmpty());
            logger.setEnable(true); logger.setConsoleEnable(true); logger.setLevel(4);
            logger.setMaxDiskAge(1); logger.setMaxDiskSize(1);
            logger.removeExpireData(); logger.removeBeforeAllData(); logger.removeAll();
            MXLogger next = track(new MXLogger(context, ns, "ignored duplicate header"));
            next.info(null, null, "after");
            assertEquals(3, read(next, false).length);
            assertEquals(0, MXLogger.log("unknown-token", null, 1, null, "ignored"));
        }
    }
}
