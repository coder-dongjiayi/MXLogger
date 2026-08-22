/// flutter_mxlogger 单元测试
///
/// 运行方式: 在 flutter_mxlogger 目录下执行 flutter test
///
/// 测试策略: 不 mock FFI。setUpAll 中把 Android 桥接(纯C++) + Core
/// 编译成宿主 dylib 并 DynamicLibrary.open 加载(macOS 的 dlopen 默认
/// RTLD_GLOBAL), 插件内部的 DynamicLibrary.process() 即可解析到全部
/// flutter_mxlogger_* 符号, 因此所有 FFI 接口都是真实执行、真实读写
/// 磁盘文件的。仅 MXLogger.initialize 的 MethodChannel 部分使用 mock。
///
/// 注意: 本测试依赖宿主机的 clang, 仅支持 macOS。
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mxlogger/flutter_mxlogger.dart';

/// 与写入端约定的16字节加密参数
const String kCryptKey = 'abcdefg123456789';
const String kIv = '0123456789abcdef';

/// 文件头记录的固定name(与iOS/analyzer约定一致)
const String kFileHeaderName = 'com.djy.mxlogger.fileHeader';

int _nsCounter = 0;

/// 每个用例用独立的namespace, 避免core全局实例字典串扰
String uniqueNs() => 'com.test.mxlogger.ns${_nsCounter++}';

late Directory tempRoot;

/// 新建一个隔离目录
Directory newDir(String tag) {
  final dir = Directory('${tempRoot.path}/$tag$_nsCounter')
    ..createSync(recursive: true);
  return dir;
}

/// 取当前正在写入的日志文件完整路径(通过getLogFiles拿真实文件名)
String currentLogFile(MXLogger logger) {
  final files = logger.getLogFiles();
  expect(files, isNotEmpty, reason: '应该已生成日志文件');
  return '${logger.diskcachePath}/${files.first.name}';
}

/// 读回指定logger当前文件的全部记录
/// 注意: selectLogmsg 返回倒序(最新在前, 与iOS端行为一致),
/// 这里反转为写入顺序, 方便按时间先后断言
List<Map<String, dynamic>> readBack(MXLogger logger,
    {String? cryptKey, String? iv}) {
  return MXLogger.selectLogmsg(
          diskcacheFilePath: currentLogFile(logger),
          cryptKey: cryptKey,
          iv: iv)
      .reversed
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // 编译并加载宿主测试dylib, 让 DynamicLibrary.process() 能找到符号
    final dylib = File('test/native/libmxlogger_test.dylib');
    if (!dylib.existsSync()) {
      final r = Process.runSync('bash', ['test/native/build_test_dylib.sh']);
      expect(r.exitCode, 0,
          reason: '构建测试dylib失败(需要macOS+clang):\n${r.stdout}\n${r.stderr}');
    }
    DynamicLibrary.open(dylib.absolute.path);

    tempRoot = Directory.systemTemp.createTempSync('mxlogger_test_');
  });

  tearDownAll(() {
    try {
      tempRoot.deleteSync(recursive: true);
    } catch (_) {}
  });

  // ---------------------------------------------------------------
  group('MXStoragePolicyType / MXFileEntity 纯Dart模型', () {
    test('枚举包含4种存储策略', () {
      expect(MXStoragePolicyType.values, hasLength(4));
      expect(
          MXStoragePolicyType.values.map((e) => e.name),
          containsAll(['yyyy_MM_dd', 'yyyy_MM_dd_HH', 'yyyy_ww', 'yyyy_MM']));
    });

    test('MXFileEntity 默认值与时间戳换算', () {
      final entity = MXFileEntity(
          name: 'a.mx',
          size: 128,
          createTimeStamp: 1700000000,
          lastTimeStamp: 1700000100);
      expect(entity.createTime,
          DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000));
      expect(entity.lastTime,
          DateTime.fromMillisecondsSinceEpoch(1700000100 * 1000));
      expect(entity.toString(), contains('a.mx'));

      final empty = MXFileEntity();
      expect(empty.name, isNull);
      expect(empty.size, 0);
    });
  });

  // ---------------------------------------------------------------
  group('构造与基础属性', () {
    test('构造后 loggerKey 为32位md5 且同参数稳定、异参数不同', () {
      final dir = newDir('key');
      final ns = uniqueNs();
      final a = MXLogger(nameSpace: ns, directory: dir.path);
      expect(a.loggerKey, isNotNull);
      expect(a.loggerKey!.length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(a.loggerKey!), isTrue);

      // 相同 namespace+directory -> 相同key
      final b = MXLogger(nameSpace: ns, directory: dir.path);
      expect(b.loggerKey, a.loggerKey);

      // 不同 namespace -> 不同key
      final c = MXLogger(nameSpace: uniqueNs(), directory: dir.path);
      expect(c.loggerKey, isNot(a.loggerKey));
    });

    test('diskcachePath = directory + nameSpace, diskcacheErrorPath 拼接正确',
        () {
      final dir = newDir('path');
      final ns = uniqueNs();
      final logger = MXLogger(nameSpace: ns, directory: dir.path);
      expect(logger.diskcachePath, contains(dir.path));
      expect(logger.diskcachePath, contains(ns));
      expect(logger.diskcacheErrorPath, '${logger.diskcachePath}/error.txt');
      expect(Directory(logger.diskcachePath).existsSync(), isTrue,
          reason: '初始化时应创建日志目录');
    });

    test('enable 默认为true, cryptKey/iv getter 返回构造入参', () {
      final logger = MXLogger(
          nameSpace: uniqueNs(),
          directory: newDir('prop').path,
          cryptKey: kCryptKey,
          iv: kIv);
      expect(logger.enable, isTrue);
      expect(logger.cryptKey, kCryptKey);
      expect(logger.iv, kIv);

      final plain =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('prop2').path);
      expect(plain.cryptKey, isNull);
      expect(plain.iv, isNull);
    });

    test('errorDesc 无错误时为null (覆盖get_error_desc/free_string)', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('err').path);
      expect(logger.errorDesc, isNull);
    });
  });

  // ---------------------------------------------------------------
  group('存储策略文件命名', () {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final day = '${now.year}-${two(now.month)}-${two(now.day)}';
    final month = '${now.year}-${two(now.month)}';

    test('yyyy_MM_dd(默认): 文件名为 日期_fileName.mx, 默认fileName=mxlog', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('sp1').path);
      logger.debug('hello');
      final files = logger.getLogFiles();
      expect(files.single.name, '${day}_mxlog.mx');
    });

    test('yyyy_MM_dd_HH: 文件名含小时', () {
      final logger = MXLogger(
          nameSpace: uniqueNs(),
          directory: newDir('sp2').path,
          storagePolicy: MXStoragePolicyType.yyyy_MM_dd_HH,
          fileName: 'hourly');
      logger.debug('hello');
      expect(logger.getLogFiles().single.name, startsWith('$day-'));
      expect(logger.getLogFiles().single.name, endsWith('_hourly.mx'));
    });

    test('yyyy_ww: 文件名含周序号w', () {
      final logger = MXLogger(
          nameSpace: uniqueNs(),
          directory: newDir('sp3').path,
          storagePolicy: MXStoragePolicyType.yyyy_ww);
      logger.debug('hello');
      final name = logger.getLogFiles().single.name!;
      expect(name, startsWith('${now.year}-'));
      expect(name, contains('w'));
      expect(name, endsWith('_mxlog.mx'));
    });

    test('yyyy_MM: 文件名为 年月_fileName.mx', () {
      final logger = MXLogger(
          nameSpace: uniqueNs(),
          directory: newDir('sp4').path,
          storagePolicy: MXStoragePolicyType.yyyy_MM);
      logger.debug('hello');
      expect(logger.getLogFiles().single.name, '${month}_mxlog.mx');
    });

    test('自定义fileName生效', () {
      final logger = MXLogger(
          nameSpace: uniqueNs(),
          directory: newDir('sp5').path,
          fileName: 'mylog');
      logger.debug('hello');
      expect(logger.getLogFiles().single.name, endsWith('_mylog.mx'));
    });
  });

  // ---------------------------------------------------------------
  group('日志写入与读回(未加密)', () {
    test('log 返回0, 五个等级方法写入并可完整读回', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('rw').path);

      expect(logger.debug('d-msg', name: 'n0', tag: 't0'), 0);
      expect(logger.info('i-msg', name: 'n1', tag: 't1'), 0);
      expect(logger.warn('w-msg', name: 'n2', tag: 't2'), 0);
      expect(logger.error('e-msg', name: 'n3', tag: 't3'), 0);
      expect(logger.fatal('f-msg', name: 'n4', tag: 't4'), 0);

      final records = readBack(logger);
      expect(records, hasLength(5));
      for (int i = 0; i < 5; i++) {
        final r = records[i];
        expect(r['error_code'], '0');
        expect(r['level'], '$i');
        expect(r['name'], 'n$i');
        expect(r['tag'], 't$i');
        expect(r['thread_id'], isNotNull);
        expect(r['is_main_thread'], isNotNull);
        expect(int.parse(r['timestamp'] as String), greaterThan(0));
      }
      expect(records.map((r) => r['msg']),
          ['d-msg', 'i-msg', 'w-msg', 'e-msg', 'f-msg']);
    });

    test('name/tag 可为null, 中文/emoji/长文本/JSON串正确往返', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('rw2').path);
      final longMsg = 'x' * 10000;
      const jsonMsg = '{"url":"https://a.b/c?d=1","code":200}';
      const cnMsg = '中文消息🚀 "引号" \n换行';

      logger.log(1, 'plain');
      logger.log(1, longMsg);
      logger.log(1, jsonMsg, name: 'net');
      logger.log(1, cnMsg, tag: '标签1,标签2');

      final records = readBack(logger);
      expect(records, hasLength(4));
      // name为null时core写入默认name "mxlogger"
      expect(records[0]['name'], 'mxlogger');
      expect(records[0]['tag'], '');
      expect(records[1]['msg'], longMsg);
      expect(records[2]['msg'], jsonMsg);
      expect(records[3]['msg'], cnMsg);
      expect(records[3]['tag'], '标签1,标签2');
    });

    test('批量写入1000条无丢失', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('bulk').path);
      for (int i = 0; i < 1000; i++) {
        expect(logger.info('bulk-$i'), 0);
      }
      final records = readBack(logger);
      expect(records, hasLength(1000));
      expect(records.first['msg'], 'bulk-0');
      expect(records.last['msg'], 'bulk-999');
    });

    test('logSize/getLogSize 写入后大于0', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('size').path);
      logger.info('hello');
      expect(logger.logSize, greaterThan(0));
      expect(logger.getLogSize(), logger.logSize);
    });
  });

  // ---------------------------------------------------------------
  group('加密写入与解密读回 (AES-CFB-128)', () {
    test('cryptKey+iv 加密往返', () {
      final logger = MXLogger(
          nameSpace: uniqueNs(),
          directory: newDir('enc').path,
          cryptKey: kCryptKey,
          iv: kIv);
      logger.info('secret-中文-message', name: 'enc', tag: 'aes');

      final ok = readBack(logger, cryptKey: kCryptKey, iv: kIv);
      expect(ok.single['error_code'], '0');
      expect(ok.single['msg'], 'secret-中文-message');
    });

    test('不带iv时默认使用cryptKey作为iv', () {
      final logger = MXLogger(
          nameSpace: uniqueNs(),
          directory: newDir('enc2').path,
          cryptKey: kCryptKey);
      logger.info('no-iv-message');

      final ok = readBack(logger, cryptKey: kCryptKey);
      expect(ok.single['error_code'], '0');
      expect(ok.single['msg'], 'no-iv-message');
    });

    test('错误的key解析: 记录标记error_code=1 而不是崩溃', () {
      final logger = MXLogger(
          nameSpace: uniqueNs(),
          directory: newDir('enc3').path,
          cryptKey: kCryptKey,
          iv: kIv);
      logger.info('secret');

      final bad =
          readBack(logger, cryptKey: '0000000000000000', iv: kIv);
      expect(bad, hasLength(1));
      expect(bad.single['error_code'], '1');
    });

    test('不用key解析加密文件: 同样标记error_code=1', () {
      final logger = MXLogger(
          nameSpace: uniqueNs(),
          directory: newDir('enc4').path,
          cryptKey: kCryptKey,
          iv: kIv);
      logger.info('secret');

      final bad = readBack(logger);
      expect(bad.single['error_code'], '1');
    });
  });

  // ---------------------------------------------------------------
  group('selectLogmsg 边界', () {
    test('文件不存在返回空列表', () {
      final r = MXLogger.selectLogmsg(
          diskcacheFilePath: '${tempRoot.path}/not_exists.mx');
      expect(r, isEmpty);
    });

    test('反复调用不崩溃且结果稳定 (验证free_logmsg配对释放)', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('sel').path);
      logger.info('stable');
      final file = currentLogFile(logger);
      for (int i = 0; i < 100; i++) {
        final r = MXLogger.selectLogmsg(diskcacheFilePath: file);
        expect(r.single['msg'], 'stable');
      }
    });
  });

  // ---------------------------------------------------------------
  group('fileHeader 文件头', () {
    test('传入fileHeader后第一条记录为固定name的头记录', () {
      final logger = MXLogger(
          nameSpace: uniqueNs(),
          directory: newDir('hdr').path,
          fileHeader: 'app=1.0.0;platform=test');
      logger.info('normal');

      final records = readBack(logger);
      expect(records, hasLength(2));
      expect(records.first['name'], kFileHeaderName);
      expect(records.first['msg'], 'app=1.0.0;platform=test');
      expect(records.last['msg'], 'normal');
    });
  });

  // ---------------------------------------------------------------
  group('setLevel 等级过滤', () {
    test('低于level的日志不写入, 大于等于的写入', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('lvl').path);
      logger.setLevel(2); // 只允许 warn(2)/error(3)/fatal(4)

      logger.debug('filtered-0');
      logger.info('filtered-1');
      logger.warn('kept-2');
      logger.error('kept-3');
      logger.fatal('kept-4');

      final records = readBack(logger);
      expect(records.map((r) => r['msg']), ['kept-2', 'kept-3', 'kept-4']);

      // 恢复level后低等级可写入
      logger.setLevel(0);
      logger.debug('back');
      expect(readBack(logger), hasLength(4));
    });
  });

  // ---------------------------------------------------------------
  group('setEnable 开关', () {
    test('禁用后不写入且getter返回默认值, 重新启用后恢复', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('en').path);
      logger.info('before');
      final file = currentLogFile(logger);

      logger.setEnable(false);
      expect(logger.enable, isFalse);
      expect(logger.info('while-disabled'), 0);
      expect(logger.logSize, 0, reason: 'Dart侧enable=false时logSize返回0');
      expect(logger.diskcachePath, '', reason: 'Dart侧enable=false时路径返回空串');
      expect(logger.errorDesc, isNull);
      // setLevel/setMaxDiskAge等在disable下为no-op, 调用不应崩溃
      logger.setLevel(0);
      logger.setMaxDiskAge(100);
      logger.setMaxDiskSize(100);
      logger.removeExpireData();
      logger.removeBeforeAllData();
      logger.removeAll();

      expect(MXLogger.selectLogmsg(diskcacheFilePath: file), hasLength(1),
          reason: '禁用期间的日志不应落盘');

      logger.setEnable(true);
      expect(logger.enable, isTrue);
      logger.info('after');
      expect(MXLogger.selectLogmsg(diskcacheFilePath: file), hasLength(2));
    });
  });



  // ---------------------------------------------------------------
  group('文件清理', () {
    /// 在日志目录伪造一个旧文件(旧mtime), 模拟历史日志
    File fakeOldFile(MXLogger logger, {int sizeBytes = 100}) {
      final f = File('${logger.diskcachePath}/2020-01-01_log.mx');
      f.writeAsStringSync('x' * sizeBytes);
      f.setLastModifiedSync(DateTime(2020, 1, 1));
      return f;
    }

    test('removeExpireData: maxDiskAge超时的旧文件被删, 当前文件保留', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('exp').path);
      logger.info('current');
      final old = fakeOldFile(logger);

      logger.setMaxDiskAge(60 * 60 * 24); // 1天
      logger.removeExpireData();

      expect(old.existsSync(), isFalse, reason: '2020年的旧文件应被清理');
      expect(readBack(logger).single['msg'], 'current',
          reason: '当前写入文件不能被删');
    });

    test('removeExpireData: maxDiskSize超限时从最旧文件删起', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('cap').path);
      logger.info('current');
      final old = fakeOldFile(logger, sizeBytes: 1024 * 1024);

      logger.setMaxDiskSize(1024); // 1KB 上限
      logger.removeExpireData();

      expect(old.existsSync(), isFalse, reason: '超限时最旧文件应被删除');
      expect(readBack(logger).single['msg'], 'current');
    });

    test('removeExpireData: 未设置限制时(默认0)不删任何文件', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('nolimit').path);
      logger.info('current');
      final old = fakeOldFile(logger);

      logger.removeExpireData();
      expect(old.existsSync(), isTrue);
    });

    test('removeBeforeAllData: 删除除当前文件外的所有文件', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('before').path);
      logger.info('current');
      final old = fakeOldFile(logger);

      logger.removeBeforeAllData();

      expect(old.existsSync(), isFalse);
      expect(readBack(logger).single['msg'], 'current');
    });

    test('removeAll: 删除包括当前文件在内的所有日志文件', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('all').path);
      logger.info('a');
      logger.info('b');
      final old = fakeOldFile(logger);

      logger.removeAll();

      expect(old.existsSync(), isFalse);
      expect(logger.getLogFiles(), isEmpty, reason: 'removeAll删除全部文件且不重建');
      // README语义: 运行中文件被删后继续写入不报错(写入已删除的映射, 不再落盘)
      expect(logger.info('after-clear'), 0);
    });
  });

  // ---------------------------------------------------------------
  group('getLogFiles / logFiles', () {
    test('返回文件元信息: 名称/大小/创建及修改时间', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('files').path);
      logger.info('hello');

      final files = logger.logFiles;
      expect(files, hasLength(1));
      final f = files.single;
      expect(f.name, endsWith('.mx'));
      expect(f.size, greaterThan(0));
      expect(f.createTimeStamp, greaterThan(0));
      expect(f.lastTimeStamp, greaterThanOrEqualTo(f.createTimeStamp));
      // 时间应在最近1小时内
      final diff = DateTime.now().difference(f.lastTime).inSeconds.abs();
      expect(diff, lessThan(3600));
    });

    test('目录中多个.mx文件都会被列出', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('files2').path);
      logger.info('hello');
      File('${logger.diskcachePath}/2020-01-01_log.mx')
          .writeAsStringSync('fake');
      expect(logger.getLogFiles().length, 2);
    });
  });

  // ---------------------------------------------------------------
  group('loggerKey 类方法族', () {
    test('logLoggerKey/debugLog..fatalLog 通过key写入同一日志', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('lk').path);
      final key = logger.loggerKey!;

      MXLogger.debugLog(key, 'k0', name: 'kn', tag: 'kt');
      MXLogger.infoLog(key, 'k1');
      MXLogger.warnLog(key, 'k2');
      MXLogger.errorLog(key, 'k3');
      MXLogger.fatalLog(key, 'k4');

      final records = readBack(logger);
      expect(records, hasLength(5));
      for (int i = 0; i < 5; i++) {
        expect(records[i]['level'], '$i');
        expect(records[i]['msg'], 'k$i');
      }
      expect(records.first['name'], 'kn');
      expect(records.first['tag'], 'kt');
    });
  });

  // ---------------------------------------------------------------
  group('destroy 生命周期', () {
    test('destroy后重新初始化: 文件保留, 记录追加不覆盖', () {
      final dir = newDir('destroy');
      final ns = uniqueNs();
      final logger = MXLogger(nameSpace: ns, directory: dir.path);
      logger.info('first');
      final file = currentLogFile(logger);

      MXLogger.destroy(nameSpace: ns, directory: dir.path);

      // 重新初始化同一namespace+directory
      final reopened = MXLogger(nameSpace: ns, directory: dir.path);
      reopened.info('second');

      // selectLogmsg返回倒序: 最新的"second"在前
      final records = MXLogger.selectLogmsg(diskcacheFilePath: file);
      expect(records.map((r) => r['msg']), ['second', 'first'],
          reason: 'destroy再重开不应覆盖已有数据');
      MXLogger.destroy(nameSpace: ns, directory: dir.path);
    });

    test('destroyWithLoggerKey 后重新初始化同样可用', () {
      final dir = newDir('destroy2');
      final ns = uniqueNs();
      final logger = MXLogger(nameSpace: ns, directory: dir.path);
      logger.info('x');
      final key = logger.loggerKey!;

      MXLogger.destroyWithLoggerKey(key);

      final reopened = MXLogger(nameSpace: ns, directory: dir.path);
      expect(reopened.loggerKey, key);
      reopened.info('y');
      expect(readBack(reopened), hasLength(2));
      MXLogger.destroyWithLoggerKey(key);
    });

    test('同参数重复构造出的多个实例 destroy后全部失效', () {
      final dir = newDir('dup');
      final ns = uniqueNs();
      // 两个Dart实例共享同一个native对象(core按namespace+directory去重)
      final first = MXLogger(nameSpace: ns, directory: dir.path);
      final second = MXLogger(nameSpace: ns, directory: dir.path);
      expect(first.loggerKey, second.loggerKey);
      first.info('a');
      second.info('b');

      MXLogger.destroy(nameSpace: ns, directory: dir.path);

      // 两个实例都必须被失效: enable为false且写入安全短路,
      // 否则先注册的实例会带着悬垂句柄继续调用native(use-after-free)
      expect(first.enable, isFalse, reason: '先构造的实例destroy后也必须失效');
      expect(second.enable, isFalse);
      expect(first.info('after-destroy'), 0);
      expect(second.info('after-destroy'), 0);
      // 生命周期回调同样不能再触碰native对象
      first.didChangeAppLifecycleState(AppLifecycleState.paused);
      second.didChangeAppLifecycleState(AppLifecycleState.paused);
    });
  });

  // ---------------------------------------------------------------
  group('writeFail / deleteFailFile / closeFailFile (纯Dart错误落盘)', () {
    test('writeFail 追加JSON行到error.txt, close后可读, delete后删除', () async {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('fail').path);

      logger.writeFail(code: -1, errorDesc: 'mmap failed', other: 'biz');
      logger.writeFail(code: -2, errorDesc: 'truncate failed');
      logger.closeFailFile();
      // closeFailFile 内部close是异步flush
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final errFile = File(logger.diskcacheErrorPath);
      expect(errFile.existsSync(), isTrue);
      final lines = errFile.readAsLinesSync();
      expect(lines, hasLength(2));
      final first = json.decode(lines[0]) as Map<String, dynamic>;
      expect(first['code'], -1);
      expect(first['error'], 'mmap failed');
      expect(first['other'], 'biz');
      final second = json.decode(lines[1]) as Map<String, dynamic>;
      expect(second['other'], isNull);

      logger.deleteFailFile();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(errFile.existsSync(), isFalse);
    });

    test('closeFailFile 在从未writeFail时调用安全', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('fail2').path);
      logger.closeFailFile(); // 不应抛异常
    });
  });

  // ---------------------------------------------------------------
  group('App生命周期联动 (WidgetsBindingObserver)', () {
    test('进入后台时自动清理过期文件(默认开启)', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('bg').path);
      logger.info('current');
      final old = File('${logger.diskcachePath}/2020-01-01_log.mx')
        ..writeAsStringSync('old');
      old.setLastModifiedSync(DateTime(2020, 1, 1));
      logger.setMaxDiskAge(60 * 60 * 24);

      logger.didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(old.existsSync(), isFalse, reason: 'paused时应触发removeExpireData');
    });

    test('shouldRemoveExpiredDataWhenEnterBackground(false) 后不清理', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('bg2').path);
      logger.info('current');
      final old = File('${logger.diskcachePath}/2020-01-01_log.mx')
        ..writeAsStringSync('old');
      old.setLastModifiedSync(DateTime(2020, 1, 1));
      logger.setMaxDiskAge(60 * 60 * 24);
      logger.shouldRemoveExpiredDataWhenEnterBackground(false);

      logger.didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(old.existsSync(), isTrue);
    });

    test('resumed等其他状态不触发清理', () {
      final logger =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('bg3').path);
      logger.info('current');
      final old = File('${logger.diskcachePath}/2020-01-01_log.mx')
        ..writeAsStringSync('old');
      old.setLastModifiedSync(DateTime(2020, 1, 1));
      logger.setMaxDiskAge(60 * 60 * 24);

      logger.didChangeAppLifecycleState(AppLifecycleState.resumed);
      logger.didChangeAppLifecycleState(AppLifecycleState.inactive);

      expect(old.existsSync(), isTrue);
    });
  });

  // ---------------------------------------------------------------
  group('MXLogger.initialize (MethodChannel)', () {
    const channel = MethodChannel('flutter_mxlogger');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('走channel协商目录后正常可用', () async {
      final dir = newDir('channel');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'initialize');
        final args = call.arguments as Map;
        // 模拟原生端行为: 未传directory时返回平台默认目录
        return {
          'nameSpace': args['nameSpace'],
          'directory': args['directory'] ?? dir.path,
        };
      });

      final logger = await MXLogger.initialize(
          nameSpace: uniqueNs(), cryptKey: kCryptKey, iv: kIv);
      expect(logger.diskcachePath, contains(dir.path));
      logger.info('via-initialize');
      expect(readBack(logger, cryptKey: kCryptKey, iv: kIv).single['msg'],
          'via-initialize');
    });

    test('显式directory透传', () async {
      final dir = newDir('channel2');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map;
        return {'nameSpace': args['nameSpace'], 'directory': args['directory']};
      });

      final logger = await MXLogger.initialize(
          nameSpace: uniqueNs(), directory: dir.path);
      expect(logger.diskcachePath, contains(dir.path));
    });
  });

  // ---------------------------------------------------------------
  group('selectLogfiles', () {
    test('非iOS平台返回空列表', () {
      // 宿主机测试环境不是iOS, 应走短路分支
      expect(MXLogger.selectLogfiles(directory: tempRoot.path), isEmpty);
    });
  });

  // ---------------------------------------------------------------
  group('多实例隔离', () {
    test('不同namespace的日志互不影响', () {
      final a =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('multiA').path);
      final b =
          MXLogger(nameSpace: uniqueNs(), directory: newDir('multiB').path);

      a.info('only-a');
      b.info('only-b-1');
      b.info('only-b-2');

      expect(readBack(a), hasLength(1));
      expect(readBack(b), hasLength(2));
      expect(readBack(a).single['msg'], 'only-a');
    });
  });
}
