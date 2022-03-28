package com.dongjiayi.mxloggerdemo;

import android.app.Application;

import androidx.lifecycle.ProcessLifecycleOwner;

import com.dongjiayi.mxlogger.MXLogger;

public class MyApplication extends Application {
    @Override
    public void onCreate() {
        super.onCreate();
        ProcessLifecycleOwner.get().getLifecycle().addObserver(new MXLogger());
    }
}
