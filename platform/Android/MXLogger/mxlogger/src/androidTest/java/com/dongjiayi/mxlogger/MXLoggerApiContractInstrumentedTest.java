package com.dongjiayi.mxlogger;

import android.content.Context;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.runner.RunWith;

@RunWith(AndroidJUnit4.class)
public class MXLoggerApiContractInstrumentedTest extends MXLoggerApiContractTest {
    @Override protected Context testContext() {
        return InstrumentationRegistry.getInstrumentation().getTargetContext();
    }
}
