package com.dongjiayi.mxloggerdemo;

import android.content.Intent;
import android.os.Bundle;

/** 首页: logo + 简介 + 进入演示 + 语言切换 */
public class MainActivity extends BaseDemoActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        findViewById(R.id.enterButton).setOnClickListener(v ->
                startActivity(new Intent(this, DemoHomeActivity.class)));
        findViewById(R.id.langButton).setOnClickListener(v -> {
            DemoL10n.toggle(this);
            recreate();
        });
    }
}
