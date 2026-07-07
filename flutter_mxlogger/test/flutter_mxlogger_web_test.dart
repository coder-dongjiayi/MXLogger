/// flutter_mxlogger_web 空实现测试
///
/// web实现是为了防止web编译报错的空壳, 契约是: 所有方法可安全调用、
/// 返回无害默认值、不触碰任何native/文件系统。
/// 这里直接以前缀导入web实现类进行验证。
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mxlogger/src/flutter_mxlogger_web.dart' as web;

void main() {
  group('web空实现: API契约', () {
    late web.MXLogger logger;

    setUp(() {
      logger = web.MXLogger(
          nameSpace: 'com.test.web',
          directory: '/tmp/web',
          cryptKey: 'abcdefg123456789',
          iv: '0123456789abcdef');
    });

    test('构造与getter返回默认值', () {
      expect(logger.enable, isTrue);
      expect(logger.errorDesc, isNull);
      expect(logger.diskcachePath, '');
      expect(logger.diskcacheErrorPath, '/error.txt');
      expect(logger.loggerKey, isNull);
      expect(logger.logSize, 0);
      expect(logger.logFiles, isEmpty);
      // cryptKey/iv 仍然记录构造入参
      expect(logger.cryptKey, 'abcdefg123456789');
      expect(logger.iv, '0123456789abcdef');
    });

    test('initialize 返回实例且不访问channel', () async {
      final l = await web.MXLogger.initialize(nameSpace: 'com.test.web.init');
      expect(l, isA<web.MXLogger>());
    });

    test('五个等级写入方法返回0', () {
      expect(logger.debug('d'), 0);
      expect(logger.info('i'), 0);
      expect(logger.warn('w'), 0);
      expect(logger.error('e'), 0);
      expect(logger.fatal('f'), 0);
      expect(logger.log(1, 'raw', name: 'n', tag: 't'), 0);
    });

    test('全部配置/清理方法可安全调用', () {
      logger.setLevel(2);
      logger.setEnable(false);
      logger.setEnable(true);
      logger.setConsoleEnable(true);
      logger.setMaxDiskAge(3600);
      logger.setMaxDiskSize(1024);
      logger.removeExpireData();
      logger.removeBeforeAllData();
      logger.removeAll();
      logger.shouldRemoveExpiredDataWhenEnterBackground(false);
      logger.writeFail(code: -1, errorDesc: 'x');
      logger.deleteFailFile();
      logger.closeFailFile();
      expect(logger.getLogSize(), 0);
      expect(logger.getDiskcachePath(), '');
      expect(logger.getLoggerKey(), isNull);
      expect(logger.getLogFiles(), isEmpty);
    });

    test('静态方法可安全调用且返回空', () {
      web.MXLogger.destroy(nameSpace: 'ns');
      web.MXLogger.destroyWithLoggerKey('key');
      web.MXLogger.logLoggerKey('key', 1, 'msg');
      web.MXLogger.debugLog('key', 'm');
      web.MXLogger.infoLog('key', 'm');
      web.MXLogger.warnLog('key', 'm');
      web.MXLogger.errorLog('key', 'm');
      web.MXLogger.fatalLog('key', 'm');
      expect(web.MXLogger.selectLogfiles(directory: '/tmp'), isEmpty);
      expect(
          web.MXLogger.selectLogmsg(diskcacheFilePath: '/tmp/a.mx'), isEmpty);
    });

    test('MXStoragePolicyType/MXFileEntity 与io版对齐', () {
      expect(web.MXStoragePolicyType.values, hasLength(4));
      final e = web.MXFileEntity(name: 'a.mx', size: 1);
      expect(e.toString(), contains('a.mx'));
    });
  });
}
