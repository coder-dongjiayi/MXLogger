package com.dongjiayi.mxlogger;

public enum MXStoragePolicyType {
    /**
     * 按天存储 对应文件名: 2023-01-11_filename.mx
     */
    YYYY_MM_DD,
    /**
     * 按小时存储 对应文件名: 2023-01-11-15_filename.mx
     */
    YYYY_MM_DD_HH,
    /**
     * 按周存储 对应文件名: 2023-01-02w_filename.mx（02w是指一年中的第2周）
     */
    YYYY_WW,
    /**
     * 按月存储 对应文件名: 2023-01_filename.mx
     */
    YYYY_MM
}
