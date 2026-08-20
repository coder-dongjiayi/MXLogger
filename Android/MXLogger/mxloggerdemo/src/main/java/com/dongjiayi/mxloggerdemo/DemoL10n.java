package com.dongjiayi.mxloggerdemo;

import android.content.Context;
import android.content.res.Configuration;
import java.util.Locale;

/**
 * demo 内置的语言管理: 默认英文 可在 App 内切换中文 与系统语言无关 (与 iOS demo 对齐)。
 * 语言包从 res/values(英文) 与 res/values-zh-rHans(中文) 读取。
 */
final class DemoL10n {

    private static final String PREF = "mxlogger_demo";
    private static final String KEY_LANGUAGE = "language";
    private static final String EN = "en";
    private static final String ZH = "zh-Hans";

    /** 当前语言: "en" 或 "zh-Hans" 默认 "en" */
    static String current(Context context) {
        String language = context.getSharedPreferences(PREF, Context.MODE_PRIVATE)
                .getString(KEY_LANGUAGE, EN);
        return ZH.equals(language) ? ZH : EN;
    }

    /** 切换到另一种语言 调用方随后 recreate() 生效 */
    static void toggle(Context context) {
        String next = ZH.equals(current(context)) ? EN : ZH;
        context.getSharedPreferences(PREF, Context.MODE_PRIVATE)
                .edit().putString(KEY_LANGUAGE, next).apply();
    }

    /** 用当前选择的语言包装 Context 供 attachBaseContext 使用 */
    static Context wrap(Context base) {
        Locale locale = Locale.forLanguageTag(current(base));
        Locale.setDefault(locale);
        Configuration config = new Configuration(base.getResources().getConfiguration());
        config.setLocale(locale);
        return base.createConfigurationContext(config);
    }

    private DemoL10n() {
    }
}
