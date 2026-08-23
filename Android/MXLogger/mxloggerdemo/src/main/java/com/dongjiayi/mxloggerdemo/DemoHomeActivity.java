package com.dongjiayi.mxloggerdemo;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.view.LayoutInflater;
import android.view.MenuItem;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.widget.SwitchCompat;
import androidx.appcompat.widget.Toolbar;
import androidx.core.content.ContextCompat;

import com.dongjiayi.mxlogger.MXLogger;
import com.dongjiayi.mxlogger.MXStoragePolicyType;

import org.json.JSONObject;

import java.io.File;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Random;
import java.util.concurrent.CountDownLatch;

/**
 * MXLogger 全功能演示主页 (与 iOS demo 对齐)
 * 覆盖的 API:
 *  - 构造(namespace/storagePolicy/fileHeader/cryptKey/iv) 与 destroy
 *  - debug/info/warn/error/fatal/log 以及 loggerKey 静态写入
 *  - setLevel / setConsoleEnable / setEnable / setMaxDiskAge / setMaxDiskSize
 *  - getLogSize / getDiskCachePath / getLoggerKey / getErrorDesc
 *  - logFiles / selectWithFilePath
 *  - removeExpireData / removeBeforeAllData / removeAll
 */
public class DemoHomeActivity extends BaseDemoActivity {

    static final String NS = "com.djy.mxlogger";
    static final String CRYPT_KEY = "abcdefgabcdefgob";
    static final String IV = "abcdefgabcdefgcc";

    /** demo 内共享 logger 实例(文件列表/查看器使用) */
    static MXLogger sharedLogger;

    private MXLogger logger;
    private long writeCount = 0;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final Random random = new Random();

    private TextView statSize, statFiles, statLevel, statPolicy, namespaceLabel;
    private LinearLayout sectionsContainer;
    private TextView levelValueView;
    private TextView benchmarkValueView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_demo_home);

        Toolbar toolbar = findViewById(R.id.toolbar);
        toolbar.setNavigationOnClickListener(v -> finish());
        MenuItem langItem = toolbar.getMenu().add(getString(R.string.lang_switch));
        langItem.setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS);
        langItem.setOnMenuItemClickListener(item -> {
            DemoL10n.toggle(this);
            recreate();
            return true;
        });

        statSize = findViewById(R.id.statSize);
        statFiles = findViewById(R.id.statFiles);
        statLevel = findViewById(R.id.statLevel);
        statPolicy = findViewById(R.id.statPolicy);
        namespaceLabel = findViewById(R.id.namespaceLabel);
        sectionsContainer = findViewById(R.id.sectionsContainer);

        setupLogger();
        buildSections();
        refreshStatus();
    }

    @Override
    protected void onResume() {
        super.onResume();
        refreshStatus();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        sharedLogger = null;
        MXLogger.destroy(this, NS, null);
    }

    // ---------------- logger ----------------

    private void setupLogger() {
        // 文件头信息: 文件创建时写入 一般放App版本/系统版本等业务信息
        String fileHeader;
        try {
            JSONObject header = new JSONObject();
            header.put("platform", "Android");
            header.put("appVersion", getPackageManager().getPackageInfo(getPackageName(), 0).versionName);
            header.put("systemVersion", android.os.Build.VERSION.RELEASE);
            header.put("device", android.os.Build.MODEL);
            fileHeader = header.toString();
        } catch (Exception e) {
            fileHeader = null;
        }

        // 按小时分片 + AES CFB-128 加密 (与 iOS demo 一致)
        logger = new MXLogger(this, NS, null, MXStoragePolicyType.YYYY_MM_DD_HH,
                null, fileHeader, CRYPT_KEY, IV);
        logger.setMaxDiskAge(60L * 60 * 24 * 7);       // 日志最多保留 7 天
        logger.setMaxDiskSize(1024L * 1024 * 10);      // 日志最多占用 10 MB
        logger.setConsoleEnable(true);                 // 控制台输出(发布环境建议关闭)
        logger.setLevel(0);                            // 0:debug 全部写入
        sharedLogger = logger;
    }

    private void refreshStatus() {
        statSize.setText(DemoUtil.byteText(logger.getLogSize()));
        String[] files = logger.logFiles();
        statFiles.setText(String.valueOf(files == null ? 0 : files.length));
        statLevel.setText(DemoUtil.levelName(logger.getLevel()));
        statPolicy.setText(R.string.home_card_policy_hourly);
        namespaceLabel.setText(getString(R.string.home_card_namespace_fmt, NS));
    }

    // ---------------- sections ----------------

    private void buildSections() {
        sectionsContainer.removeAllViews();

        // ---------- 日志写入 ----------
        addSectionHeader(getString(R.string.home_section_write));
        LinearLayout write = addSectionCard();
        int[] levelIcons = {R.drawable.ic_bug, R.drawable.ic_info, R.drawable.ic_warn, R.drawable.ic_error, R.drawable.ic_flame};
        String[] levelMethods = {"debug(tag, name, msg)", "info(tag, name, msg)", "warn(tag, name, msg)", "error(tag, name, msg)", "fatal(tag, name, msg)"};
        for (int level = 0; level <= 4; level++) {
            final int lv = level;
            addRow(write, levelIcons[level], DemoUtil.LEVEL_COLORS[level],
                    getString(R.string.home_write_level_title, DemoUtil.levelName(level)), levelMethods[level],
                    null, false, () -> writeLog(lv));
        }
        addRow(write, R.drawable.ic_network, R.color.tint_teal,
                getString(R.string.home_write_network_title), getString(R.string.home_write_network_subtitle),
                null, false, this::writeNetworkLog);
        addRow(write, R.drawable.ic_dial, R.color.tint_indigo,
                getString(R.string.home_write_custom_title), getString(R.string.home_write_custom_subtitle),
                null, false, this::writeCustomLevelLog);
        addRow(write, R.drawable.ic_key, R.color.tint_brown,
                getString(R.string.home_write_key_title), getString(R.string.home_write_key_subtitle),
                null, false, this::writeByLoggerKey);
        addSectionFooter(getString(R.string.home_section_write_footer));

        // ---------- 配置 ----------
        addSectionHeader(getString(R.string.home_section_config));
        LinearLayout config = addSectionCard();
        levelValueView = addRow(config, R.drawable.ic_dial, R.color.tint_blue,
                getString(R.string.home_config_level_title), getString(R.string.home_config_level_subtitle),
                DemoUtil.levelName(logger.getLevel()), false, this::pickLevel);
        addSwitchRow(config, R.drawable.ic_terminal, R.color.tint_gray,
                getString(R.string.home_config_console_title), getString(R.string.home_config_console_subtitle),
                logger.isConsoleEnable(), isOn -> {
                    logger.setConsoleEnable(isOn);
                    toast(getString(isOn ? R.string.toast_console_on : R.string.toast_console_off));
                });
        addSwitchRow(config, R.drawable.ic_power, R.color.tint_green,
                getString(R.string.home_config_enable_title), getString(R.string.home_config_enable_subtitle),
                logger.isEnable(), isOn -> {
                    logger.setEnable(isOn);
                    toast(getString(isOn ? R.string.toast_enable_on : R.string.toast_enable_off));
                });
        TextView ageValue = addRow(config, R.drawable.ic_clock, R.color.tint_orange,
                getString(R.string.home_config_age_title), getString(R.string.home_config_age_subtitle),
                diskAgeText(logger.getMaxDiskAge()), false, null);
        setRowClick(ageValue, () -> pickDiskAge(ageValue));
        TextView sizeValue = addRow(config, R.drawable.ic_storage, R.color.tint_pink,
                getString(R.string.home_config_size_title), getString(R.string.home_config_size_subtitle),
                diskSizeText(logger.getMaxDiskSize()), false, null);
        setRowClick(sizeValue, () -> pickDiskSize(sizeValue));
        addSectionFooter(getString(R.string.home_section_config_footer));

        // ---------- 性能测试 ----------
        addSectionHeader(getString(R.string.home_section_perf));
        LinearLayout perf = addSectionCard();
        benchmarkValueView = addRow(perf, R.drawable.ic_speed, R.color.tint_green,
                getString(R.string.home_perf_bench_title), getString(R.string.home_perf_bench_subtitle),
                null, false, this::runBenchmark);
        addRow(perf, R.drawable.ic_cpu, R.color.tint_teal,
                getString(R.string.home_perf_thread_title), getString(R.string.home_perf_thread_subtitle),
                null, false, this::runConcurrentWrite);
        addSectionFooter(getString(R.string.home_section_perf_footer));

        // ---------- 文件管理 ----------
        addSectionHeader(getString(R.string.home_section_file));
        LinearLayout file = addSectionCard();
        addRow(file, R.drawable.ic_folder, R.color.tint_blue,
                getString(R.string.home_file_browse_title), getString(R.string.home_file_browse_subtitle),
                null, true,
                () -> startActivity(new Intent(this, LogFileListActivity.class)));
        addRow(file, R.drawable.ic_history, R.color.tint_orange,
                getString(R.string.home_file_expire_title), "removeExpireData()", null, false, () -> {
                    logger.removeExpireData();
                    toast(getString(R.string.toast_expire_done));
                    refreshStatus();
                });
        addRow(file, R.drawable.ic_trash_keep, R.color.tint_yellow,
                getString(R.string.home_file_before_title), getString(R.string.home_file_before_subtitle),
                null, false, () -> {
                    logger.removeBeforeAllData();
                    toast(getString(R.string.toast_before_done));
                    refreshStatus();
                });
        addRow(file, R.drawable.ic_trash, R.color.tint_red,
                getString(R.string.home_file_all_title), "removeAll()", null, false, this::confirmRemoveAll);

        // ---------- 实例信息 ----------
        addSectionHeader(getString(R.string.home_section_info));
        LinearLayout info = addSectionCard();
        addRow(info, R.drawable.ic_hash, R.color.tint_indigo,
                "loggerKey", logger.getLoggerKey(), null, false, () -> {
                    copyToClipboard(logger.getLoggerKey());
                    toast(getString(R.string.toast_key_copied));
                });
        addRow(info, R.drawable.ic_gear, R.color.tint_gray,
                getString(R.string.home_info_path_title), logger.getDiskCachePath(), null, false, () -> {
                    copyToClipboard(logger.getDiskCachePath());
                    toast(getString(R.string.toast_path_copied));
                });
        addRow(info, R.drawable.ic_bubble, R.color.tint_orange,
                getString(R.string.home_info_error_title), getString(R.string.home_info_error_subtitle),
                null, false, () -> {
                    String desc = logger.getErrorDesc();
                    alert("errorDesc", desc == null || desc.length() == 0 ? getString(R.string.alert_no_error) : desc);
                });
        addRow(info, R.drawable.ic_refresh, R.color.tint_red,
                getString(R.string.home_info_rebuild_title), getString(R.string.home_info_rebuild_subtitle),
                null, false, () -> {
                    MXLogger.destroy(this, NS, null);
                    setupLogger();
                    buildSections();
                    refreshStatus();
                    toast(getString(R.string.toast_rebuild_done));
                });
        addSectionFooter(getString(R.string.home_section_info_footer));
    }

    // ---------------- 写入动作 ----------------

    private void writeLog(int level) {
        String name = "mxlogger";
        String tag = "demo";
        String msg = getString(R.string.log_msg_fmt,
                writeCount + 1, DemoUtil.levelName(level),
                DemoUtil.dateText(String.valueOf(System.currentTimeMillis() / 1000.0), "HH:mm:ss"));
        int result;
        switch (level) {
            case 1: result = logger.info(tag, name, msg); break;
            case 2: result = logger.warn(tag, name, msg); break;
            case 3: result = logger.error(tag, name, msg); break;
            case 4: result = logger.fatal(tag, name, msg); break;
            default: result = logger.debug(tag, name, msg); break;
        }
        handleWriteResult(result, getString(R.string.toast_write_success, DemoUtil.levelName(level)));
    }

    private void writeNetworkLog() {
        try {
            JSONObject body = new JSONObject();
            body.put("uri", "https://api.example.com/v1/login");
            body.put("method", "POST");
            body.put("statusCode", 200);
            body.put("costTime", "183ms");
            body.put("requestBody", new JSONObject().put("mobile", "188****8888"));
            body.put("response", new JSONObject().put("code", 0).put("msg", "ok"));
            int result = logger.info("request", "network", body.toString(2));
            handleWriteResult(result, getString(R.string.toast_network_success));
        } catch (Exception ignored) {
        }
    }

    private void writeCustomLevelLog() {
        // log() 是所有便捷方法的底层通用入口
        int result = logger.log("order", 3, "pay", getString(R.string.log_pay_msg));
        handleWriteResult(result, getString(R.string.toast_custom_success));
    }

    private void writeByLoggerKey() {
        // 业务组件不持有 logger 对象，只拿一个字符串 key 即可写入
        String loggerKey = logger.getLoggerKey();
        int result = MXLogger.log(loggerKey, "module", 1, "module.user", getString(R.string.log_module_msg));
        handleWriteResult(result, getString(R.string.toast_key_success));
    }

    private void handleWriteResult(int result, String successText) {
        if (result == 0) {
            writeCount++;
            toast(successText);
        } else {
            // -1 扩容失败 -2 解除映射失败 -3 映射失败
            alert(getString(R.string.alert_write_failed, result), logger.getErrorDesc());
        }
        refreshStatus();
    }

    // ---------------- 性能测试 ----------------

    private void runBenchmark() {
        benchmarkValueView.setText(R.string.home_perf_bench_running);
        benchmarkValueView.setVisibility(View.VISIBLE);
        final boolean consoleWasOn = logger.isConsoleEnable();
        logger.setConsoleEnable(false); // 控制台输出会严重拖慢写入 测试期间临时关闭

        new Thread(() -> {
            long start = SystemClock.elapsedRealtime();
            for (int i = 1; i <= 100000; i++) {
                // 每条日志带序号 方便在查看器里核对写入顺序和完整性
                logger.info("perf", "benchmark",
                        String.format(Locale.US, "[%06d] This is a benchmark loooooooooooooooooooooooooooooog", i));
            }
            final long cost = SystemClock.elapsedRealtime() - start;
            mainHandler.post(() -> {
                logger.setConsoleEnable(consoleWasOn);
                writeCount += 100000;
                benchmarkValueView.setText(String.format(Locale.US, "%d ms", cost));
                refreshStatus();
                toast(getString(R.string.toast_bench_done, cost));
            });
        }).start();
    }

    /**
     * 模拟真实 App 的多线程日志来源: 主线程(UI事件) + 3个不同优先级的工作线程。
     * 每条日志带 "#序号"，写入期间随机让出CPU、穿插 logFiles 读取，
     * 结束后解析当前日志文件 逐来源校验条数与顺序。
     */
    private void runConcurrentWrite() {
        final boolean consoleWasOn = logger.isConsoleEnable();
        logger.setConsoleEnable(false);

        // 每轮用随机 runName 作为 name 字段 避免与历史数据混淆
        final String runName = String.format(Locale.US, "mt-%08x", random.nextInt());
        final Map<String, Integer> expected = new LinkedHashMap<>();
        final String[][] sources = {
                {"thread-max", String.valueOf(Thread.MAX_PRIORITY)},
                {"thread-norm", String.valueOf(Thread.NORM_PRIORITY)},
                {"thread-min", String.valueOf(Thread.MIN_PRIORITY)},
        };
        final int perThread = 1000;
        final int mainCount = 200; // 主线程写少一些 避免长时间卡 UI
        for (String[] source : sources) expected.put(source[0], perThread);
        expected.put("main", mainCount);

        toast(getString(R.string.toast_concurrent_running));
        final CountDownLatch latch = new CountDownLatch(sources.length + 1);

        StringBuilder padding = new StringBuilder();
        while (padding.length() < 600) padding.append("payload-");
        final String longPayload = padding.toString();

        for (String[] source : sources) {
            final String tag = source[0];
            Thread thread = new Thread(() -> {
                for (int i = 1; i <= perThread; i++) {
                    String msg;
                    if (i % 100 == 0) {
                        // 混入长消息 覆盖 mmap 扩容/跨页写入等边界
                        msg = String.format(Locale.US, "#%05d %s long message: %s", i, tag, longPayload);
                    } else {
                        msg = String.format(Locale.US, "#%05d %s concurrent write", i, tag);
                    }
                    logger.info(tag, runName, msg);
                    try {
                        // 随机让出CPU 拉长并发重叠窗口 让调度交错更接近真实
                        if (i % 50 == 0) Thread.sleep(0, random.nextInt(400000));
                    } catch (InterruptedException ignored) {
                    }
                    // 边写边读 覆盖"写入与查询并发"的场景
                    if (i % 250 == 0) logger.logFiles();
                }
                latch.countDown();
            });
            thread.setPriority(Integer.parseInt(source[1]));
            thread.start();
        }

        // 主线程来源: 模拟 UI 事件里打日志
        mainHandler.post(() -> {
            for (int i = 1; i <= mainCount; i++) {
                logger.info("main", runName, String.format(Locale.US, "#%05d main concurrent write", i));
            }
            latch.countDown();
        });

        new Thread(() -> {
            try {
                latch.await();
            } catch (InterruptedException ignored) {
            }
            mainHandler.post(() -> {
                logger.setConsoleEnable(consoleWasOn);
                int total = 0;
                for (int count : expected.values()) total += count;
                writeCount += total;
                refreshStatus();
                verifyConcurrentRun(runName, expected);
            });
        }).start();
    }

    /** 解析当前日志文件 按来源校验: 条数是否等于预期、序号顺序是否保持(解析结果最新在前 因此应严格递减) */
    private void verifyConcurrentRun(final String runName, final Map<String, Integer> expected) {
        toast(getString(R.string.toast_concurrent_verifying));
        new Thread(() -> {
            try {
                // 找到最后更新的文件(当前写入中的文件)
                String[] files = logger.logFiles();
                String latestName = null;
                double latestTm = -1;
                for (String json : files) {
                    JSONObject file = new JSONObject(json);
                    double tm = file.optDouble("last_timestamp", 0);
                    if (tm > latestTm) {
                        latestTm = tm;
                        latestName = file.optString("name");
                    }
                }
                String path = new File(logger.getDiskCachePath(), latestName == null ? "" : latestName).getAbsolutePath();
                String[] records = MXLogger.selectWithFilePath(path, CRYPT_KEY, IV);

                // 按 tag 收集本轮日志的序号(保持解析返回的先后顺序)
                Map<String, List<Integer>> seqs = new LinkedHashMap<>();
                if (records != null) {
                    for (String json : records) {
                        JSONObject record = new JSONObject(json);
                        if (!runName.equals(record.optString("name"))) continue;
                        String msg = record.optString("msg");
                        if (!msg.startsWith("#")) continue;
                        int space = msg.indexOf(' ');
                        if (space <= 1) continue;
                        int seq;
                        try {
                            seq = Integer.parseInt(msg.substring(1, space));
                        } catch (NumberFormatException e) {
                            continue;
                        }
                        String tag = record.optString("tag");
                        List<Integer> list = seqs.get(tag);
                        if (list == null) {
                            list = new ArrayList<>();
                            seqs.put(tag, list);
                        }
                        list.add(seq);
                    }
                }

                boolean allPass = true;
                StringBuilder report = new StringBuilder();
                for (Map.Entry<String, Integer> entry : expected.entrySet()) {
                    String tag = entry.getKey();
                    int expectCount = entry.getValue();
                    List<Integer> sequence = seqs.containsKey(tag) ? seqs.get(tag) : new ArrayList<>();

                    boolean countOK = sequence.size() == expectCount;
                    boolean orderOK = countOK;
                    if (countOK) {
                        // 解析结果最新在前 单来源序号应严格递减: N, N-1, ..., 1
                        int next = expectCount;
                        for (int seq : sequence) {
                            if (seq != next--) {
                                orderOK = false;
                                break;
                            }
                        }
                    }
                    if (!countOK || !orderOK) allPass = false;
                    String status = (countOK && orderOK) ? getString(R.string.verify_line_ok)
                            : (countOK ? getString(R.string.verify_line_order) : getString(R.string.verify_line_missing));
                    report.append(getString(R.string.verify_line_fmt, tag, sequence.size(), expectCount, status));
                }
                report.append(getString(R.string.verify_summary_fmt,
                        records == null ? 0 : records.length, expected.size()));

                final boolean pass = allPass;
                final String message = report.toString();
                mainHandler.post(() -> alert(getString(pass ? R.string.verify_pass_title : R.string.verify_fail_title), message));
            } catch (Exception e) {
                mainHandler.post(() -> alert(getString(R.string.alert_verify_error), String.valueOf(e)));
            }
        }).start();
    }

    // ---------------- 配置动作 ----------------

    private void pickLevel() {
        new AlertDialog.Builder(this)
                .setTitle(getString(R.string.home_config_level_title))
                .setItems(new String[]{"Debug (0)", "Info (1)", "Warn (2)", "Error (3)", "Fatal (4)"}, (dialog, which) -> {
                    logger.setLevel(which);
                    levelValueView.setText(DemoUtil.levelName(which));
                    refreshStatus();
                })
                .show();
    }

    private void pickDiskAge(TextView valueView) {
        final String[] titles = {getString(R.string.duration_1min), getString(R.string.duration_1hour),
                getString(R.string.duration_1day), getString(R.string.duration_7days),
                getString(R.string.common_unlimited)};
        final long[] values = {60, 3600, 86400, 604800, 0};
        new AlertDialog.Builder(this)
                .setTitle("maxDiskAge")
                .setItems(titles, (dialog, which) -> {
                    logger.setMaxDiskAge(values[which]);
                    valueView.setText(titles[which]);
                })
                .show();
    }

    private void pickDiskSize(TextView valueView) {
        final String[] titles = {"1 MB", "10 MB", "100 MB", getString(R.string.common_unlimited)};
        final long[] values = {1024 * 1024, 1024 * 1024 * 10, 1024 * 1024 * 100, 0};
        new AlertDialog.Builder(this)
                .setTitle("maxDiskSize")
                .setItems(titles, (dialog, which) -> {
                    logger.setMaxDiskSize(values[which]);
                    valueView.setText(titles[which]);
                })
                .show();
    }

    private void confirmRemoveAll() {
        new AlertDialog.Builder(this)
                .setTitle(getString(R.string.alert_removeall_title))
                .setMessage(getString(R.string.alert_removeall_message))
                .setNegativeButton(getString(R.string.common_cancel), null)
                .setPositiveButton(getString(R.string.common_remove), (dialog, which) -> {
                    logger.removeAll();
                    writeCount = 0;
                    refreshStatus();
                    toast(getString(R.string.toast_removeall_done));
                })
                .show();
    }

    // ---------------- UI helpers ----------------

    private void addSectionHeader(String title) {
        TextView view = new TextView(this);
        view.setText(title);
        view.setTextSize(13);
        view.setTextColor(ContextCompat.getColor(this, R.color.text_secondary));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        params.setMargins(dp(20), dp(20), dp(20), dp(6));
        sectionsContainer.addView(view, params);
    }

    private void addSectionFooter(String text) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextSize(12);
        view.setTextColor(ContextCompat.getColor(this, R.color.text_tertiary));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        params.setMargins(dp(20), dp(6), dp(20), 0);
        sectionsContainer.addView(view, params);
    }

    private LinearLayout addSectionCard() {
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setBackgroundResource(R.drawable.bg_group_card);
        card.setClipToOutline(true);
        sectionsContainer.addView(card, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));
        return card;
    }

    /** 添加一行 返回 value TextView(用于后续更新文案) */
    private TextView addRow(LinearLayout card, int iconRes, int tintRes, String title,
                            String subtitle, String value, boolean chevron, Runnable onClick) {
        if (card.getChildCount() > 0) addDivider(card);
        View row = LayoutInflater.from(this).inflate(R.layout.item_action, card, false);
        FrameLayout tile = row.findViewById(R.id.iconTile);
        ImageView icon = row.findViewById(R.id.icon);
        TextView titleView = row.findViewById(R.id.title);
        TextView subtitleView = row.findViewById(R.id.subtitle);
        TextView valueView = row.findViewById(R.id.value);
        View chevronView = row.findViewById(R.id.chevron);

        tile.getBackground().mutate().setTint(ContextCompat.getColor(this, tintRes));
        icon.setImageResource(iconRes);
        titleView.setText(title);
        if (subtitle != null && subtitle.length() > 0) {
            subtitleView.setText(subtitle);
            subtitleView.setVisibility(View.VISIBLE);
        }
        if (value != null) {
            valueView.setText(value);
            valueView.setVisibility(View.VISIBLE);
        }
        chevronView.setVisibility(chevron ? View.VISIBLE : View.GONE);
        if (onClick != null) row.setOnClickListener(v -> onClick.run());
        card.addView(row);
        valueView.setTag(row);
        return valueView;
    }

    /** value TextView 反查所在行并绑定点击 */
    private void setRowClick(TextView valueView, Runnable onClick) {
        View row = (View) valueView.getTag();
        if (row != null) row.setOnClickListener(v -> onClick.run());
        valueView.setVisibility(View.VISIBLE);
    }

    private interface OnSwitchChanged {
        void onChanged(boolean isOn);
    }

    private void addSwitchRow(LinearLayout card, int iconRes, int tintRes, String title,
                              String subtitle, boolean checked, OnSwitchChanged onChanged) {
        TextView valueView = addRow(card, iconRes, tintRes, title, subtitle, null, false, null);
        View row = (View) valueView.getTag();
        SwitchCompat switcher = row.findViewById(R.id.switcher);
        switcher.setVisibility(View.VISIBLE);
        switcher.setChecked(checked);
        switcher.setOnCheckedChangeListener((button, isOn) -> onChanged.onChanged(isOn));
    }

    private void addDivider(LinearLayout card) {
        View divider = new View(this);
        divider.setBackgroundColor(ContextCompat.getColor(this, R.color.divider));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, Math.max(1, dp(1) / 2));
        params.setMarginStart(dp(58));
        card.addView(divider, params);
    }

    private String diskAgeText(long seconds) {
        if (seconds == 0) return getString(R.string.common_unlimited);
        if (seconds < 3600) return getString(R.string.duration_minutes_fmt, seconds / 60);
        if (seconds < 86400) return getString(R.string.duration_hours_fmt, seconds / 3600);
        return getString(R.string.duration_days_fmt, seconds / 86400);
    }

    private String diskSizeText(long bytes) {
        return bytes == 0 ? getString(R.string.common_unlimited) : DemoUtil.byteText(bytes);
    }

    private void copyToClipboard(String text) {
        ClipboardManager manager = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        manager.setPrimaryClip(ClipData.newPlainText("mxlogger", text));
    }

    private void alert(String title, String message) {
        new AlertDialog.Builder(this)
                .setTitle(title)
                .setMessage(message)
                .setPositiveButton(getString(R.string.common_ok), null)
                .show();
    }

    private void toast(String text) {
        Toast.makeText(this, text, Toast.LENGTH_SHORT).show();
    }

    private int dp(int value) {
        return Math.round(getResources().getDisplayMetrics().density * value);
    }
}
