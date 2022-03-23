package com.blingabc.blinglogger;

public class NativeLib {

    // Used to load the 'blinglogger' library on application startup.
    static {
        System.loadLibrary("blinglogger");
    }

    /**
     * A native method that is implemented by the 'blinglogger' native library,
     * which is packaged with this application.
     */
    public native String stringFromJNI();
}