package com.dongjiayi.mxlogger;

public class MXLogger {
    static {
        System.loadLibrary("mxlogger");
    }
    public static native String version();
}
