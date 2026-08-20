package com.dongjiayi.mxloggerdemo;

import android.content.Context;

import androidx.appcompat.app.AppCompatActivity;

/** 页面基类: 按 demo 语言偏好包装 Context 语言变化后回到前台时自动重建 */
abstract class BaseDemoActivity extends AppCompatActivity {

    private String appliedLanguage;

    @Override
    protected void attachBaseContext(Context newBase) {
        appliedLanguage = DemoL10n.current(newBase);
        super.attachBaseContext(DemoL10n.wrap(newBase));
    }

    @Override
    protected void onResume() {
        super.onResume();
        // 在其他页面切换了语言 回到本页时按新语言重建
        if (!DemoL10n.current(this).equals(appliedLanguage)) recreate();
    }
}
