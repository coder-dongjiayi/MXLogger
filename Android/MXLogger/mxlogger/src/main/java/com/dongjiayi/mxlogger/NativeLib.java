package com.dongjiayi.mxlogger;

public class NativeLib {

    // Used to load the 'mxlogger' library on application startup.
    static {
        System.loadLibrary("mxlogger");
    }

    /**
     * A native method that is implemented by the 'mxlogger' native library,
     * which is packaged with this application.
     */
    public native String stringFromJNI();
}