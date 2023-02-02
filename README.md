
[![license](https://img.shields.io/badge/license-BSD_3-brightgreen.svg?style=flat)](https://github.com/coder-dongjiayi/MXLogger/blob/main/LICENSE.TXT)    [![Platform](https://img.shields.io/badge/Platform-%20iOS%20%7C%20Android%20%7C%20Flutter-brightgreen.svg)](https://github.com/coder-dongjiayi/MXLogger)

<p align="center" >
<img src="./icon/logo_400.png" alt="MXLogger"  title="MXLogger" style="zoom:20%;" />
</p>

# MXLogger
MXLogger is a multi-platform collect logs library base on mmap. Support ios Android and Flutter。The core code use c/c++. Use the ffi call on the Flutter,Performance is almost identical to native. Data serialization uses Google's open source flat_buffers implementation, which is efficient and stable.

中文说明请点击[这里](./README_CN.md)

###  Structure
<img src="./icon/jiegoutu.jpg" alt="jiegoutu" style="zoom:30%;" />
Currently, the MXLogger mainly solves log writing and log analysis problems.The log reporting time is determined by the service,The MXLogger has opened the log path. It needs to develop the file uploading code that calls the native platform and sends it to its own server。

# Performance Test
> Test environment

* iphone11, System version 14.6

* Each piece of data is about 134 bytes and loops for 100,000 times

* Test 10 times and take an average

* Setting Xcode Build Configuration is release

> result
 * 0.13s

 # Log viewing
   * To parse the generated binary data, I wrote an accompanying parsing tool that you can view[mxlogger_analyzer](./mxlogger_analyzer.dmg),It looks something like this。
   [video link](https://user-images.githubusercontent.com/9606416/215237658-4f99fc51-4610-48c5-8803-daaf86400bf3.mp4)

https://user-images.githubusercontent.com/9606416/215237658-4f99fc51-4610-48c5-8803-daaf86400bf3.mp4
 * If you're using a Mac you can just download the [client](https://github.com/coder-dongjiayi/MXLogger/blob/main/mxlogger_analyzer.dmg)。If you are using windows, you may need to configure the Flutter environment yourself, compile the source code for mxlogger_analyzer and package the exe file。
 *  If your project is Project Flutter，you can dependence[mxlogger_analyzer_lib](https://pub.flutter-io.cn/packages/mxlogger_analyzer_lib)
 ```
 dependencies:
   mxlogger_analyzer_lib:^1.0.2

 ```


  ```dart
   MXAnalyzer.showDebug(
                      _navigatorStateKey.currentState!.overlay!,
                      diskcachePath: _mxLogger.diskcachePath,
                      cryptKey: _mxLogger.cryptKey,
                      iv: _mxLogger.iv,
                      databasePath: "you database path")
  ```
   It looks something like this [video link](https://user-images.githubusercontent.com/9606416/215238043-e7199344-ba26-42a6-b8f3-421035cdb46a.mp4)

https://user-images.githubusercontent.com/9606416/215238043-e7199344-ba26-42a6-b8f3-421035cdb46a.mp4


# Install

## iOS

``` pod 'MXLogger', '~> 1.2.3'```

## Android

``` implementation 'io.github.coder-dongjiayi:mxlogger:1.2.3'```

### Flutter

```
dependencies:
  flutter_mxlogger: ^last
```

### notice
Do not set the log storage directory in a directory that may be cleaned up by the system, such as library/cache in ios. MXLogger does not check whether the directory exists every time it writes data, but only creates it at startup. If the log files are cleaned up by the system while the app is running, The program does not report errors or flash back, but the log is not logged either

* iOS

  ```objective-c
  MXLogger * logger =  [MXLogger initializeWithNamespace:@"com.youdomain.logger.space",storagePolicy:MXStoragePolicyYYYYMMDD];
  logger.maxDiskAge = 60*60*24*7; // a week
  logger.maxDiskSize = 1024 * 1024 * 10; // 10M
  logger.fileLevel = 0;// If the file write level is lower than this level, the log file will not be written to the file
  
  [logger debug:@"mxlogger" msg:@"this is debug" tag:@"network,action"];
  [logger info:@"mxlogger" msg:@"this is info" tag:@"request"];
  [logger warn:@"mxlogger" msg:@"this is warn" tag:@"step"];
  [logger error:@"mxlogger" msg:@"this is error" tag:@"action"];
  [logger fatal:@"mxlogger" msg:@"this is fatal" tag:@"reponse"];
  ```


* Android

  ```java
  MXLogger logger = new MXLogger(this.getContext(),"com.djy.mxlogger");
  logger.maxDiskAge = 60*60*24*7; // a week
  logger.maxDiskSize = 1024 * 1024 * 10; // 10M
  logger.debug("request","mxlogger","this is debug",tag:"tag1,tag2,tag3");
  logger.info("response","mxlogger","this is info");
  logger.warn("tag","mxlogger","this is warn");
  logger.error("404","mxlogger","this is error");
  logger.fatal("200","mxlogger","this is fatal");
  ```

  

* Flutter

  ```dart
   MXLogger logger = await MXLogger.initialize(
          nameSpace: "flutter.mxlogger",
          storagePolicy: MXStoragePolicyType.yyyy_MM_dd,
          cryptKey: "abcuioqbsdguijlk",
          iv: "bccuioqbsdguijiv");
  
   logger.setMaxDiskAge(60*60*24*7);
   logger.setMaxDiskSize(1024*1024*10);
   logger.setFileLevel(0);
  
   logger.debug("this is debug ", name: "mxlogger", tag: "tag1,tag2,tag3");
   logger.info("this is info", name: "mxlogger", tag: "w");
   logger.warn("this is  warn", name: "mxlogger", tag: "w");
   logger.error("this is  error", name: "mxlogger", tag: "e");
   logger.fatal("this fatal", name: "mxlogger", tag: "f");
  
  ```











