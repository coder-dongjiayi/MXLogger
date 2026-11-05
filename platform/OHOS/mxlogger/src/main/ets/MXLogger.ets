import native, { NativeHandle } from 'libmxlogger.so';
import common from '@ohos.app.ability.common';

export enum MXLogLevel { Debug = 0, Info = 1, Warn = 2, Error = 3, Fatal = 4 }
export enum MXStoragePolicy {
  Daily = 'yyyy_MM_dd', Hourly = 'yyyy_MM_dd_HH', Weekly = 'yyyy_ww', Monthly = 'yyyy_MM'
}
export interface MXLoggerOptions {
  nameSpace: string;
  directory?: string;
  storagePolicy?: MXStoragePolicy;
  fileName?: string;
  fileHeader?: string;
  cryptKey?: string;
  iv?: string;
}
export interface MXLogOptions { name?: string; tag?: string; }
export interface MXLoggerState {
  loggerToken: string;
  diskCachePath: string;
  errorDesc: string;
  level: MXLogLevel;
  enable: boolean;
  consoleEnable: boolean;
  maxDiskAge: number;
  maxDiskSize: number;
  logSize: number;
}
export interface MXLogFile { name: string; size: number; lastTimeStamp: number; createTimeStamp: number; }
export interface MXLogRecord {
  name: string; tag: string; msg: string; level: number; timestamp: number;
  threadId: number; isMainThread: boolean;
}
interface NativeFile { name: string; size: string; last_timestamp: string; create_timestamp: string; }
interface NativeRecord {
  name: string; tag: string; msg: string; level: string; timestamp: string;
  thread_id: string; is_main_thread: string;
}

export class MXLogger {
  private handle: NativeHandle;
  private constructor(handle: NativeHandle) { this.handle = handle; }

  static coreVersion(): string { return native.coreVersion(); }
  static initialize(context: common.Context, options: MXLoggerOptions): MXLogger {
    return MXLogger.initializeWithDirectory(options.directory ?? context.filesDir + '/com.mxlog.LoggerCache', options);
  }
  static initializeWithDirectory(directory: string, options: MXLoggerOptions): MXLogger {
    return new MXLogger(native.initialize(options.nameSpace, directory,
      options.storagePolicy ?? MXStoragePolicy.Daily, options.fileName ?? 'mxlog',
      options.fileHeader ?? '', options.cryptKey ?? '', options.iv ?? ''));
  }
  static fromLoggerToken(token: string): MXLogger { return new MXLogger(native.attach(token)); }
  static logWithToken(token: string, level: MXLogLevel, message: string, options?: MXLogOptions): number {
    return native.logWithToken(token, level, message, options?.name ?? 'mxlogger', options?.tag ?? '');
  }
  get isValid(): boolean { return native.isValid(this.handle); }
  get state(): MXLoggerState { return JSON.parse(native.snapshot(this.handle)) as MXLoggerState; }
  get loggerToken(): string { return this.state.loggerToken; }
  get diskCachePath(): string { return this.state.diskCachePath; }
  get errorDesc(): string { return this.state.errorDesc; }
  get level(): MXLogLevel { return this.state.level; }
  get enable(): boolean { return this.state.enable; }
  get consoleEnable(): boolean { return this.state.consoleEnable; }
  get maxDiskAge(): number { return this.state.maxDiskAge; }
  get maxDiskSize(): number { return this.state.maxDiskSize; }
  get logSize(): number { return this.state.logSize; }
  get logFiles(): MXLogFile[] {
    const rows = JSON.parse(native.files(this.handle)) as NativeFile[];
    return rows.map((row: NativeFile): MXLogFile => {
      return { name: row.name, size: Number(row.size), lastTimeStamp: Number(row.last_timestamp),
        createTimeStamp: Number(row.create_timestamp) };
    });
  }
  readLogFile(filename: string): MXLogRecord[] {
    const rows = JSON.parse(native.read(this.handle, filename)) as NativeRecord[];
    return rows.map((row: NativeRecord): MXLogRecord => {
      return { name: row.name, tag: row.tag, msg: row.msg, level: Number(row.level),
        timestamp: Number(row.timestamp), threadId: Number(row.thread_id),
        isMainThread: row.is_main_thread === '1' };
    });
  }
  log(level: MXLogLevel, message: string, options?: MXLogOptions): number {
    return native.log(this.handle, level, message, options?.name ?? 'mxlogger', options?.tag ?? '');
  }
  debug(message: string, options?: MXLogOptions): number { return this.log(MXLogLevel.Debug, message, options); }
  info(message: string, options?: MXLogOptions): number { return this.log(MXLogLevel.Info, message, options); }
  warn(message: string, options?: MXLogOptions): number { return this.log(MXLogLevel.Warn, message, options); }
  error(message: string, options?: MXLogOptions): number { return this.log(MXLogLevel.Error, message, options); }
  fatal(message: string, options?: MXLogOptions): number { return this.log(MXLogLevel.Fatal, message, options); }
  setLevel(value: MXLogLevel): void { native.configure(this.handle, 0, value); }
  setEnable(value: boolean): void { native.configure(this.handle, 1, value ? 1 : 0); }
  setConsoleEnable(value: boolean): void { native.configure(this.handle, 2, value ? 1 : 0); }
  setMaxDiskAge(seconds: number): void { native.configure(this.handle, 3, seconds); }
  setMaxDiskSize(bytes: number): void { native.configure(this.handle, 4, bytes); }
  flush(): void { native.flush(this.handle); }
  removeExpireData(): void { native.clean(this.handle, 0); }
  removeBeforeAllData(): void { native.clean(this.handle, 1); }
  removeAll(): void { native.clean(this.handle, 2); }
  // All aliases of this session become invalid. Reinitialization creates a new
  // generation; calling destroy again on an old wrapper cannot close it.
  destroy(): void { native.destroy(this.handle); }
}
