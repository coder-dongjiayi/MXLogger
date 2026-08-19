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
import android.view.View;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
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
public class DemoHomeActivity extends AppCompatActivity {

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
        statPolicy.setText("按小时");
        namespaceLabel.setText(NS + " · AES-CFB 128 加密");
    }

    // ---------------- sections ----------------

    private void buildSections() {
        sectionsContainer.removeAllViews();

        // ---------- 日志写入 ----------
        addSectionHeader("日志写入");
        LinearLayout write = addSectionCard();
        int[] levelIcons = {R.drawable.ic_bug, R.drawable.ic_info, R.drawable.ic_warn, R.drawable.ic_error, R.drawable.ic_flame};
        String[] levelMethods = {"debug(tag, name, msg)", "info(tag, name, msg)", "warn(tag, name, msg)", "error(tag, name, msg)", "fatal(tag, name, msg)"};
        for (int level = 0; level <= 4; level++) {
            final int lv = level;
            addRow(write, levelIcons[level], DemoUtil.LEVEL_COLORS[level],
                    "写入 " + DemoUtil.levelName(level) + " 日志", levelMethods[level],
                    null, false, () -> writeLog(lv));
        }
        addRow(write, R.drawable.ic_network, R.color.tint_teal,
                "写入网络请求日志", "msg 为 JSON 字符串，tag = request", null, false, this::writeNetworkLog);
        addRow(write, R.drawable.ic_dial, R.color.tint_indigo,
                "log() 通用写入", "自定义等级写入，本例 level = 3 (error)", null, false, this::writeCustomLevelLog);
        addRow(write, R.drawable.ic_key, R.color.tint_brown,
                "通过 loggerKey 写入", "组件化场景：只传 key 不传对象，MXLogger.log(loggerKey, …)", null, false, this::writeByLoggerKey);
        addSectionFooter("每个等级对应一个实例方法，返回 0 表示写入成功。");

        // ---------- 配置 ----------
        addSectionHeader("配置");
        LinearLayout config = addSectionCard();
        levelValueView = addRow(config, R.drawable.ic_dial, R.color.tint_blue,
                "写入等级 level", "低于该等级的日志不写入文件", DemoUtil.levelName(logger.getLevel()), false, this::pickLevel);
        addSwitchRow(config, R.drawable.ic_terminal, R.color.tint_gray,
                "控制台打印 consoleEnable", "影响写入性能，发布环境建议关闭", logger.isConsoleEnable(), isOn -> {
                    logger.setConsoleEnable(isOn);
                    toast(isOn ? "已开启控制台打印" : "已关闭控制台打印");
                });
        addSwitchRow(config, R.drawable.ic_power, R.color.tint_green,
                "日志总开关 enable", "关闭后所有日志停止写入", logger.isEnable(), isOn -> {
                    logger.setEnable(isOn);
                    toast(isOn ? "日志已启用" : "日志已禁用");
                });
        TextView ageValue = addRow(config, R.drawable.ic_clock, R.color.tint_orange,
                "有效期 maxDiskAge", "超期文件将被清理，0 为无限制", diskAgeText(logger.getMaxDiskAge()), false, null);
        setRowClick(ageValue, () -> pickDiskAge(ageValue));
        TextView sizeValue = addRow(config, R.drawable.ic_storage, R.color.tint_pink,
                "容量上限 maxDiskSize", "超过上限按时间从旧到新清理，0 为无限制", diskSizeText(logger.getMaxDiskSize()), false, null);
        setRowClick(sizeValue, () -> pickDiskSize(sizeValue));
        addSectionFooter("level 只影响磁盘写入；开启 consoleEnable 后控制台仍输出全部日志。");

        // ---------- 性能测试 ----------
        addSectionHeader("性能测试");
        LinearLayout perf = addSectionCard();
        benchmarkValueView = addRow(perf, R.drawable.ic_speed, R.color.tint_green,
                "连续写入 100,000 条", "每条带递增序号，统计总耗时", null, false, this::runBenchmark);
        addRow(perf, R.drawable.ic_cpu, R.color.tint_teal,
                "多线程并发写入", "主线程 + 3 个优先级线程并发写入，完成后自动校验条数与顺序", null, false, this::runConcurrentWrite);
        addSectionFooter("性能测试前建议关闭 consoleEnable，控制台输出会显著拖慢写入。");

        // ---------- 文件管理 ----------
        addSectionHeader("文件管理");
        LinearLayout file = addSectionCard();
        addRow(file, R.drawable.ic_folder, R.color.tint_blue,
                "浏览日志文件", "logFiles + selectWithFilePath 解析", null, true,
                () -> startActivity(new Intent(this, LogFileListActivity.class)));
        addRow(file, R.drawable.ic_history, R.color.tint_orange,
                "清理过期文件", "removeExpireData()", null, false, () -> {
                    logger.removeExpireData();
                    toast("已清理过期文件");
                    refreshStatus();
                });
        addRow(file, R.drawable.ic_trash_keep, R.color.tint_yellow,
                "清理历史文件", "removeBeforeAllData()，保留当前写入中的文件", null, false, () -> {
                    logger.removeBeforeAllData();
                    toast("已清理历史文件");
                    refreshStatus();
                });
        addRow(file, R.drawable.ic_trash, R.color.tint_red,
                "清空全部日志", "removeAll()", null, false, this::confirmRemoveAll);

        // ---------- 实例信息 ----------
        addSectionHeader("实例信息");
        LinearLayout info = addSectionCard();
        addRow(info, R.drawable.ic_hash, R.color.tint_indigo,
                "loggerKey", logger.getLoggerKey(), null, false, () -> {
                    copyToClipboard(logger.getLoggerKey());
                    toast("loggerKey 已复制");
                });
        addRow(info, R.drawable.ic_gear, R.color.tint_gray,
                "缓存目录 diskCachePath", logger.getDiskCachePath(), null, false, () -> {
                    copyToClipboard(logger.getDiskCachePath());
                    toast("路径已复制");
                });
        addRow(info, R.drawable.ic_bubble, R.color.tint_orange,
                "查看最近错误 errorDesc", "写入返回非 0 时的错误描述", null, false, () -> {
                    String desc = logger.getErrorDesc();
                    alert("errorDesc", desc == null || desc.length() == 0 ? "暂无错误" : desc);
                });
        addRow(info, R.drawable.ic_refresh, R.color.tint_red,
                "销毁并重建实例", "destroy() 后重新构造", null, false, () -> {
                    MXLogger.destroy(this, NS, null);
                    setupLogger();
                    buildSections();
                    refreshStatus();
                    toast("实例已重建");
                });
        addSectionFooter("loggerKey = md5(namespace + directory)，跨模块只传这个 key 即可写入。");
    }

    // ---------------- 写入动作 ----------------

    private void writeLog(int level) {
        String name = "mxlogger";
        String tag = "demo";
        String msg = String.format(Locale.US, "这是第 %d 条 %s 日志，写于 %s",
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
        handleWriteResult(result, DemoUtil.levelName(level) + " 写入成功");
    }

    private void writeNetworkLog() {
        try {
            JSONObject body = new JSONObject();
            body.put("uri", "https://api.example.com/v1/login");
            body.put("method", "POST");
            body.put("statusCode", 200);
            body.put("costTime", "183ms");
            body.put("requestBody", new JSONObject().put("mobile", "188****8888"));
            body.put("response", new JSONObject().put("code", 0).put("msg", "操作成功"));
            int result = logger.info("request", "network", body.toString(2));
            handleWriteResult(result, "网络日志写入成功");
        } catch (Exception ignored) {
        }
    }

    private void writeCustomLevelLog() {
        // log() 是所有便捷方法的底层通用入口
        int result = logger.log("order", 3, "pay", "订单支付失败: code=-1009 网络连接中断");
        handleWriteResult(result, "log() 写入成功");
    }

    private void writeByLoggerKey() {
        // 业务组件不持有 logger 对象，只拿一个字符串 key 即可写入
        String loggerKey = logger.getLoggerKey();
        int result = MXLogger.log(loggerKey, "module", 1, "module.user", "子组件通过 loggerKey 写入的日志");
        handleWriteResult(result, "loggerKey 写入成功");
    }

    private void handleWriteResult(int result, String successText) {
        if (result == 0) {
            writeCount++;
            toast(successText);
        } else {
            // -1 扩容失败 -2 解除映射失败 -3 映射失败
            alert("写入失败(" + result + ")", logger.getErrorDesc());
        }
        refreshStatus();
    }

    // ---------------- 性能测试 ----------------

    private void runBenchmark() {
        benchmarkValueView.setText("测试中…");
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
                benchmarkValueView.setText(cost + " ms");
                refreshStatus();
                toast("10 万条写入耗时 " + cost + " ms");
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

        toast("并发写入中…");
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
                        msg = String.format(Locale.US, "#%05d %s 长消息: %s", i, tag, longPayload);
                    } else {
                        msg = String.format(Locale.US, "#%05d %s 并发写入", i, tag);
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
                logger.info("main", runName, String.format(Locale.US, "#%05d main 并发写入", i));
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
        toast("写入完成，正在解析校验…");
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
                    report.append(String.format(Locale.US, "%s: %d/%d 条 %s\n", tag, sequence.size(), expectCount,
                            (countOK && orderOK) ? "✓ 顺序完整" : (countOK ? "✗ 顺序异常" : "✗ 条数缺失")));
                }
                report.append(String.format(Locale.US, "\n文件共 %d 条，校验来源 %d 个",
                        records == null ? 0 : records.length, expected.size()));

                final boolean pass = allPass;
                final String message = report.toString();
                mainHandler.post(() -> alert(pass ? "✅ 并发校验通过" : "❌ 并发校验失败", message));
            } catch (Exception e) {
                mainHandler.post(() -> alert("校验异常", String.valueOf(e)));
            }
        }).start();
    }

    // ---------------- 配置动作 ----------------

    private void pickLevel() {
        new AlertDialog.Builder(this)
                .setTitle("写入等级 level")
                .setItems(new String[]{"Debug (0)", "Info (1)", "Warn (2)", "Error (3)", "Fatal (4)"}, (dialog, which) -> {
                    logger.setLevel(which);
                    levelValueView.setText(DemoUtil.levelName(which));
                    refreshStatus();
                })
                .show();
    }

    private void pickDiskAge(TextView valueView) {
        final String[] titles = {"1 分钟", "1 小时", "1 天", "7 天", "无限制"};
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
        final String[] titles = {"1 MB", "10 MB", "100 MB", "无限制"};
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
                .setTitle("清空全部日志？")
                .setMessage("removeAll() 将删除所有日志文件，且不可恢复。")
                .setNegativeButton("取消", null)
                .setPositiveButton("清空", (dialog, which) -> {
                    logger.removeAll();
                    writeCount = 0;
                    refreshStatus();
                    toast("日志已清空");
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
        if (seconds == 0) return "无限制";
        if (seconds < 3600) return (seconds / 60) + " 分钟";
        if (seconds < 86400) return (seconds / 3600) + " 小时";
        return (seconds / 86400) + " 天";
    }

    private String diskSizeText(long bytes) {
        return bytes == 0 ? "无限制" : DemoUtil.byteText(bytes);
    }

    private void copyToClipboard(String text) {
        ClipboardManager manager = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        manager.setPrimaryClip(ClipData.newPlainText("mxlogger", text));
    }

    private void alert(String title, String message) {
        new AlertDialog.Builder(this)
                .setTitle(title)
                .setMessage(message)
                .setPositiveButton("好", null)
                .show();
    }

    private void toast(String text) {
        Toast.makeText(this, text, Toast.LENGTH_SHORT).show();
    }

    private int dp(int value) {
        return Math.round(getResources().getDisplayMetrics().density * value);
    }
}
