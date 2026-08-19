package com.dongjiayi.mxloggerdemo;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/** demo 公共工具 */
final class DemoUtil {

    static final String[] LEVEL_NAMES = {"Debug", "Info", "Warn", "Error", "Fatal"};
    static final String[] LEVEL_BADGES = {"DEBUG", "INFO", "WARN", "ERROR", "FATAL"};
    static final int[] LEVEL_COLORS = {
            R.color.level_debug, R.color.level_info, R.color.level_warn,
            R.color.level_error, R.color.level_fatal};

    static String levelName(int level) {
        return (level >= 0 && level < LEVEL_NAMES.length) ? LEVEL_NAMES[level] : "Debug";
    }

    static String byteText(long bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format(Locale.US, "%.1f KB", bytes / 1024.0);
        return String.format(Locale.US, "%.2f MB", bytes / 1024.0 / 1024.0);
    }

    /**
     * 时间戳格式化。
     * 日志记录的 timestamp 是微秒(core 用 time_stamp_microseconds 写入)，
     * logFiles 的 create/last_timestamp 是秒(来自文件系统)，按量级自动识别。
     */
    static String dateText(String timestamp, String pattern) {
        double value;
        try {
            value = Double.parseDouble(timestamp);
        } catch (Exception e) {
            return timestamp == null ? "-" : timestamp;
        }
        if (value <= 0) return "-";
        double seconds = value;
        if (value > 1e14) seconds = value / 1e6;        // 微秒
        else if (value > 1e11) seconds = value / 1e3;   // 毫秒
        SimpleDateFormat format = new SimpleDateFormat(pattern, Locale.US);
        return format.format(new Date((long) (seconds * 1000)));
    }

    private DemoUtil() {
    }
}
