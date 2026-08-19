package com.dongjiayi.mxloggerdemo;

import android.content.Intent;
import android.os.Bundle;

import androidx.appcompat.app.AppCompatActivity;

/** 首页: logo + 简介 + 进入演示 */
public class MainActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        findViewById(R.id.enterButton).setOnClickListener(v ->
                startActivity(new Intent(this, DemoHomeActivity.class)));
    }
}
