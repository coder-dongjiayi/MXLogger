package com.dongjiayi.mxlogger;

import android.content.Context;
import android.content.ContextWrapper;
import org.junit.Assume;
import org.junit.BeforeClass;
import org.junit.Rule;
import org.junit.rules.TemporaryFolder;
import java.io.File;

/** Real JNI/Core; only Android OS services use AGP's mockable android.jar. */
public class MXLoggerHostApiTest extends MXLoggerApiContractTest {
    @Rule public TemporaryFolder temporary = new TemporaryFolder();
    @BeforeClass public static void requireHostJni() {
        Assume.assumeTrue("Run scripts/verify_android_api_host.sh for native API tests",
                System.getenv("MXLOGGER_JNI_TEST_LIBRARY_DIR") != null);
    }
    @Override protected Context testContext() {
        return new ContextWrapper(null) {
            @Override public File getFilesDir() { return temporary.getRoot(); }
        };
    }
}
