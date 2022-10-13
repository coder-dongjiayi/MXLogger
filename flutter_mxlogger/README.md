# flutter_mxlogger

MXLogger 是基于mmap内存映射机制的跨平台日志库，支持AES CFB 128位加密，支持iOS Android Flutter。核心代码使用C/C++实现， Flutter端通过ffi调用，性能几乎与原生一致。 底层序列化使用Google开源的flat_buffers实现，高效稳定。更多关于MXLogger的说明请前往[github](https://github.com/coder-dongjiayi/MXLogger)查看




# 快速开始

```dart
MXLogger logger = await MXLogger.initialize(
        nameSpace: "flutter.mxlogger",
        storagePolicy: "yyyy_MM_dd_HH",
        cryptKey: "abcuioqbsdguijlk",
        iv: "bccuioqbsdguijiv");

 logger.setMaxDiskAge(60*60*24*7); // one week
 logger.setMaxDiskSize(1024*1024*10); // 10M
 logger.setFileLevel(0); 

 logger.debug("this is debug message", name: "mxlogger", tag: "net,response");
 logger.info("this is info message", name: "mxlogger", tag: "tag1,tag2,tag3");
 logger.warn("this is warn message", name: "mxlogger", tag: "tag1,tag2,tag3");
 logger.error("this is error message", name: "mxlogger", tag: "tag1,tag2,tag3");
 logger.fatal("this is fatal message", name: "mxlogger", tag: "tag1,tag2,tag3");
```

# 解析日志文件

产出的二进制文件可以使用 [mxlogger_analyzer](https://github.com/coder-dongjiayi/MXLogger/blob/main/mxlogger_analyzer.dmg) 进行解析，前往[github](https://github.com/coder-dongjiayi/MXLogger) 查看更多关于解析器的说明

