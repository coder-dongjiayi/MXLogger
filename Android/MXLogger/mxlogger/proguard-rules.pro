# Keep all native methods, their classes and any classes in their descriptors
-keepclasseswithmembers,includedescriptorclasses class com.dongjiayi.mxlogger.** {
    native <methods>;
    long nativeHandle;
    private static *** defaultDiskCacheDirectory(***);
    private static *** userCacheDirectory(***);

}
