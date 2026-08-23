package com.dongjiayi.mxlogger;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;

import org.junit.Test;

/**
 * MXStoragePolicyType 本地JVM单元测试
 * (不依赖native库, 其余API的测试见androidTest/MXLoggerInstrumentedTest)
 */
public class MXStoragePolicyTypeTest {

    @Test
    public void containsFourPolicies() {
        assertEquals(4, MXStoragePolicyType.values().length);
    }

    @Test
    public void orderMatchesIosAndFlutterEnum() {
        // 顺序与iOS的MXStoragePolicyType / Flutter的MXStoragePolicyType一一对应
        assertArrayEquals(new MXStoragePolicyType[]{
                MXStoragePolicyType.YYYY_MM_DD,
                MXStoragePolicyType.YYYY_MM_DD_HH,
                MXStoragePolicyType.YYYY_WW,
                MXStoragePolicyType.YYYY_MM,
        }, MXStoragePolicyType.values());
    }
}
