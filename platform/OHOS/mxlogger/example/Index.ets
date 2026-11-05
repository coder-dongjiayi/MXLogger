import { MXLogger, MXLogLevel, MXStoragePolicy, MXLogOptions, MXLogFile, MXLogRecord } from '@djy/mxlogger';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface ExampleFile { file: MXLogFile; records: MXLogRecord[]; }

@Entry
@Component
struct Index {
  @State ready: boolean = false;
  @State statusText: string = '准备初始化';
  @State output: string = '';
  private logger?: MXLogger;

  aboutToAppear(): void {
    this.run(() => {
      this.initialize();
      const logger = this.current();
      const message = 'MXLogger example 中文日志 ✅ ' + Date.now();
      this.checkWrite(logger.info(message, { name: 'example', tag: 'startup' }));
      const found = logger.logFiles.some((file) => logger.readLogFile(file.name).some((row) => row.msg === message));
      if (!found) { throw new Error('启动日志读回失败'); }
      this.statusText = 'PASS · Core ' + MXLogger.coreVersion();
      hilog.info(0x0000, 'MXLoggerExample', 'MXLOGGER_EXAMPLE_READY %{public}s', logger.diskCachePath);
    });
  }

  aboutToDisappear(): void {
    this.logger?.destroy();
    this.logger = undefined;
  }

  private current(): MXLogger {
    if (!this.logger || !this.logger.isValid) { throw new Error('请先初始化实例'); }
    return this.logger;
  }

  private initialize(): void {
    if (this.logger?.isValid) { return; }
    const context = this.getUIContext().getHostContext();
    if (!context) { throw new Error('Context unavailable'); }
    this.logger = MXLogger.initialize(context, {
      nameSpace: 'com.example.mxlogger', storagePolicy: MXStoragePolicy.Daily,
      fileName: 'example', fileHeader: '{"platform":"HarmonyOS","example":true}',
      cryptKey: 'abcdefgabcdefgob', iv: 'abcdefgabcdefgcc'
    });
    this.logger.setMaxDiskAge(7 * 24 * 60 * 60);
    this.logger.setMaxDiskSize(10 * 1024 * 1024);
  }

  private checkWrite(code: number): void {
    if (code !== 0) { throw new Error('写入失败：' + code); }
  }

  private run(action: () => void): void {
    try {
      action();
      this.ready = this.logger?.isValid ?? false;
      this.output = this.ready ? JSON.stringify(this.current().state, null, 2) : 'isValid: false';
    } catch (error) {
      this.ready = this.logger?.isValid ?? false;
      this.statusText = 'FAIL: ' + String(error);
      hilog.error(0x0000, 'MXLoggerExample', 'MXLOGGER_EXAMPLE_FAILED %{public}s', this.statusText);
    }
  }

  private writeAll(): void {
    this.run(() => {
      const logger = this.current();
      const options: MXLogOptions = { name: 'example', tag: 'levels' };
      this.checkWrite(logger.debug('debug 中文日志', options));
      this.checkWrite(logger.info('info 中文日志', options));
      this.checkWrite(logger.warn('warn 中文日志', options));
      this.checkWrite(logger.error('error 中文日志', options));
      this.checkWrite(logger.fatal('fatal 中文日志', options));
      this.statusText = '五级日志调用完成；保存结果遵循当前 enable / level 设置';
    });
  }

  private readFiles(): void {
    this.run(() => { this.statusText = '已读取文件'; });
    try {
      const logger = this.current();
      this.output = JSON.stringify(logger.logFiles.map((file: MXLogFile): ExampleFile => {
        return { file: file, records: logger.readLogFile(file.name).slice(-20) };
      }), null, 2);
    } catch (error) { this.statusText = 'FAIL: ' + String(error); }
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text('MXLogger · ArkTS example').fontSize(23).fontWeight(FontWeight.Bold)
        Text(this.statusText).fontSize(14).width('100%').id('example.status')
        Button('初始化 / 重新打开').onClick(() => this.run(() => {
          this.initialize(); this.statusText = '实例已初始化';
        })).id('example.initialize')
        Button('写入五级日志').enabled(this.ready).onClick(() => this.writeAll()).id('example.write')
        Button('静态 token / 共享实例写入').enabled(this.ready).onClick(() => this.run(() => {
          const token = this.current().loggerToken;
          this.checkWrite(MXLogger.logWithToken(token, MXLogLevel.Info, '静态 token 日志', { name: 'example', tag: 'token' }));
          const alias = MXLogger.fromLoggerToken(token);
          this.checkWrite(alias.log(MXLogLevel.Warn, '共享实例日志', { name: 'example', tag: 'alias' }));
          this.statusText = '共享实例调用完成';
        })).id('example.token')
        Button('切换最低等级 Debug / Warn').enabled(this.ready).onClick(() => this.run(() => {
          const logger = this.current();
          logger.setLevel(logger.level === MXLogLevel.Debug ? MXLogLevel.Warn : MXLogLevel.Debug);
          this.statusText = '等级：' + logger.level;
        })).id('example.level')
        Button('切换 enable').enabled(this.ready).onClick(() => this.run(() => {
          const logger = this.current(); logger.setEnable(!logger.enable);
          this.statusText = 'enable：' + logger.enable;
        })).id('example.enable')
        Button('切换 HiLog').enabled(this.ready).onClick(() => this.run(() => {
          const logger = this.current(); logger.setConsoleEnable(!logger.consoleEnable);
          this.statusText = 'HiLog：' + logger.consoleEnable;
        })).id('example.console')
        Button('flush / 按时长和大小清理').enabled(this.ready).onClick(() => this.run(() => {
          const logger = this.current(); logger.flush(); logger.removeExpireData();
          this.statusText = '已请求 flush 并清理非活跃过期文件';
        })).id('example.flush')
        Button('读取文件和日志').enabled(this.ready).onClick(() => this.readFiles()).id('example.read')
        Button('销毁共享会话').enabled(this.ready).onClick(() => this.run(() => {
          this.current().destroy(); this.logger = undefined;
          this.statusText = '已销毁；可重新初始化，磁盘数据保留';
        })).id('example.destroy')
        Text(this.output).fontSize(12).width('100%').copyOption(CopyOptions.InApp).id('example.output')
      }.width('100%').padding(20)
    }.width('100%').height('100%')
  }
}
