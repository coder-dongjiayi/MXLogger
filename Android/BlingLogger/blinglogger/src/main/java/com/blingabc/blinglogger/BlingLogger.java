package com.blingabc.blinglogger;

public class BlingLogger {
    static {
        System.loadLibrary("blinglogger");
    }
    public static native String version();
}
