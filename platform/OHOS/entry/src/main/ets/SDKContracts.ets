import { MXLogger, MXLogLevel, MXStoragePolicy, MXLoggerOptions, MXLogRecord } from '@djy/mxlogger';
import common from '@ohos.app.ability.common';
import process from '@ohos.process';
import fs from '@ohos.file.fs';
import worker, { MessageEvents } from '@ohos.worker';

let checks: number = 0;
let runId: string = '';
function check(value: boolean, message: string): void {
  checks++;
  if (!value) { throw new Error(message); }
}
function rejects(action: () => void, message: string): void {
  let rejected: boolean = false;
  try { action(); } catch (_) { rejected = true; }
  check(rejected, message);
}
function records(logger: MXLogger): MXLogRecord[] {
  let result: MXLogRecord[] = [];
  logger.logFiles.forEach((file) => { result = result.concat(logger.readLogFile(file.name)); });
  return result;
}
interface WorkerResult { passed: boolean; error?: string; }
interface SDKReport { passed: boolean; pid: number; checks: number; workerRecords: number; coreVersion: string; }

async function workerCheck(context: common.Context): Promise<number> {
  const logger = MXLogger.initialize(context, { nameSpace: 'sdk_worker_' + runId });
  const token = logger.loggerToken;
  await new Promise<void>((resolve, reject) => {
    const thread = new worker.ThreadWorker('entry/ets/workers/LoggerWorker.ets');
    const timer = setTimeout(() => {
      thread.terminate(); reject(new Error('worker timed out'));
    }, 20000);
    thread.onmessage = (event: MessageEvents): void => {
      clearTimeout(timer);
      const result = event.data as WorkerResult;
      thread.terminate();
      if (result.passed) { resolve(); } else { reject(new Error(result.error ?? 'worker failed')); }
    };
    thread.onerror = (): void => {
      clearTimeout(timer); thread.terminate(); reject(new Error('worker runtime error'));
    };
    thread.postMessage(token);
  });
  const rows = records(logger);
  check(rows.length === 64, 'worker writes must share the UI-initialized logger');
  check(rows.every((row) => !row.isMainThread && row.tag === 'worker'), 'worker thread metadata');
  logger.destroy();
  return rows.length;
}

export async function verifySDK(context: common.Context): Promise<string> {
  checks = 0;
  runId = process.pid + '_' + Date.now();
  const options: MXLoggerOptions = {
    nameSpace: 'sdk_contract_' + runId, fileName: 'contract', fileHeader: '{"suite":"ohos-sdk"}'
  };
  const a = MXLogger.initialize(context, options);
  const b = MXLogger.initialize(context, options);
  const token = a.loggerToken;
  check(token === b.loggerToken, 'same initialization must share a logger');
  check(a.isValid && b.isValid && a.enable, 'default validity and enable');
  check(a.level === MXLogLevel.Debug && !a.consoleEnable, 'default configuration');
  a.setLevel(MXLogLevel.Warn);
  check(b.level === MXLogLevel.Warn, 'aliases must read real native configuration');
  a.debug('filtered'); a.warn('kept');
  check(!records(b).some((row) => row.msg === 'filtered'), 'level filter');
  check(records(b).some((row) => row.msg === 'kept'), 'warn write');
  a.setEnable(false); b.fatal('disabled');
  check(!records(a).some((row) => row.msg === 'disabled'), 'disabled logger');
  b.setEnable(true); a.setLevel(MXLogLevel.Debug);
  a.debug('debug'); a.info('info'); a.warn('warn'); a.error('error'); a.fatal('fatal');
  check([0, 1, 2, 3, 4].every((level) => records(a).some((row) => row.level === level)), 'all log levels');
  a.setMaxDiskSize(5000000000); a.setMaxDiskAge(604800);
  check(b.maxDiskSize === 5000000000 && b.maxDiskAge === 604800, '64-bit settings and shared getters');
  a.setConsoleEnable(true);
  check(b.consoleEnable, 'shared console configuration');
  a.info('HiLog bridge verified', { name: 'sdk_contract', tag: 'console' });
  a.setConsoleEnable(false);
  const attached = MXLogger.fromLoggerToken(token);
  check(attached.loggerToken === token, 'attach token');
  MXLogger.logWithToken(token, MXLogLevel.Info, 'token 中文 ✅', { name: 'sdk_contract', tag: 'token' });
  check(records(attached).some((row) => row.msg === 'token 中文 ✅'), 'static token write');
  check(records(a).some((row) => row.name === 'com.djy.mxlogger.fileHeader'), 'file header retained');
  check(a.logSize > 0 && a.logFiles[0].size > 0 && a.logFiles[0].lastTimeStamp > 0, 'file metadata');
  rejects(() => a.setMaxDiskAge(-1), 'negative settings must fail');
  rejects(() => a.setLevel(99 as MXLogLevel), 'invalid level must fail');
  rejects(() => a.readLogFile('../escape.mx'), 'file traversal must fail');
  rejects(() => MXLogger.fromLoggerToken('missing'), 'missing token must fail');
  rejects(() => MXLogger.initialize(context, { nameSpace: options.nameSpace, cryptKey: 'different' }), 'conflicting config must fail');
  for (let mode = 0; mode < 3; mode++) {
    const current = a.logFiles[0].name;
    const old = a.diskCachePath + 'inactive.mx';
    const file = fs.openSync(old, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    fs.writeSync(file.fd, 'inactive fixture'); fs.closeSync(file);
    if (mode === 0) { a.setMaxDiskSize(1); a.removeExpireData(); }
    else if (mode === 1) { a.removeBeforeAllData(); }
    else { a.removeAll(); }
    check(!fs.accessSync(old), 'cleanup inactive file');
    check(a.logFiles.some((file) => file.name === current), 'cleanup retains current file');
  }
  a.flush();
  const before = records(a).length;
  a.destroy();
  check(!b.isValid && !attached.isValid, 'destroy must invalidate all aliases');
  rejects(() => b.info('stale'), 'stale handle write must fail');
  const fresh = MXLogger.initialize(context, options);
  b.destroy(); b.destroy();
  check(fresh.isValid && records(fresh).length === before, 'old alias must not destroy reopened generation');
  fresh.destroy();

  const policies: MXStoragePolicy[] = [MXStoragePolicy.Daily, MXStoragePolicy.Hourly, MXStoragePolicy.Weekly, MXStoragePolicy.Monthly];
  policies.forEach((policy, index) => {
    const logger = MXLogger.initialize(context, { nameSpace: 'sdk_policy_' + runId + '_' + index,
      storagePolicy: policy, cryptKey: 'poc-test-key-1234', iv: 'poc-test-iv--1234' });
    logger.info('policy 中文 ✅'); logger.flush();
    check(logger.logFiles.length === 1 && records(logger)[0].msg === 'policy 中文 ✅', 'encrypted policy round trip');
    logger.destroy();
  });
  const workerRecords = await workerCheck(context);
  const result: SDKReport = { passed: true, pid: process.pid, checks: checks, workerRecords: workerRecords, coreVersion: MXLogger.coreVersion() };
  return JSON.stringify(result);
}

interface PersistenceReport {
  passed: boolean; coreVersion: string; pid: number; encrypted: boolean; sharedCore: boolean;
  previousCount: number; readBackCount: number; loggerToken: string; directory: string; files: string[];
}
export function verifyPersistence(context: common.Context, encrypted: boolean): string {
  const directory = context.filesDir + '/com.mxlog.LoggerCache';
  const options: MXLoggerOptions = { nameSpace: encrypted ? 'poc_encrypted' : 'poc_plain', fileName: 'poc',
    cryptKey: encrypted ? 'poc-test-key-1234' : undefined, iv: encrypted ? 'poc-test-iv--1234' : undefined };
  const logger = MXLogger.initialize(context, options);
  const alias = MXLogger.fromLoggerToken(logger.loggerToken);
  const token = logger.loggerToken;
  const before = records(logger).length;
  const suffix = String(before + 1);
  logger.info('OHOS POC FFI 中文 ✅ #' + suffix, { name: 'ohos_poc', tag: 'ffi' });
  MXLogger.logWithToken(token, MXLogLevel.Info, 'OHOS POC native 中文 ✅ #' + suffix, { name: 'ohos_poc', tag: 'native' });
  check(alias.loggerToken === token && records(alias).length === before + 2, 'shared session persistence');
  logger.flush(); logger.destroy();
  const reopened = MXLogger.initialize(context, options);
  const after = records(reopened).length;
  check(after === before + 2, 'reopen must preserve old and new records');
  const result: PersistenceReport = { passed: true, coreVersion: MXLogger.coreVersion(), pid: process.pid,
    encrypted: encrypted, sharedCore: true, previousCount: before, readBackCount: after,
    loggerToken: token, directory: directory, files: reopened.logFiles.map((file) => reopened.diskCachePath + file.name) };
  reopened.destroy();
  return JSON.stringify(result);
}
