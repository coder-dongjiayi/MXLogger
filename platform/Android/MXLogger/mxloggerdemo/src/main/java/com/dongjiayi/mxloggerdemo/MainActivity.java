package com.dongjiayi.mxloggerdemo;

import android.content.Intent;
import android.os.Bundle;
import android.widget.TextView;

import com.dongjiayi.mxlogger.MXLogger;

/** 首页: logo + 简介 + 进入演示 + 语言切换 */
public class MainActivity extends BaseDemoActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        TextView subtitle = findViewById(R.id.landingSubtitle);
        subtitle.setText(getString(R.string.landing_subtitle) + "\nCore " + MXLogger.coreVersion());

        findViewById(R.id.enterButton).setOnClickListener(v ->
                startActivity(new Intent(this, DemoHomeActivity.class)));
        findViewById(R.id.langButton).setOnClickListener(v -> {
            DemoL10n.toggle(this);
            recreate();
        });
    }
}
