package com.dongjiayi.mxloggerdemo;

import android.app.Application;

import com.dongjiayi.mxlogger.MXLogger;

public class MyApplication extends Application {
    @Override
    public void onCreate() {
        super.onCreate();

    }

    @Override
    public void onTerminate() {
        super.onTerminate();
    }
}
