import { MXLogger, MXLoggerOptions, MXStoragePolicy } from '@djy/mxlogger';
import common from '@ohos.app.ability.common';
import worker, { MessageEvents } from '@ohos.worker';

// These demonstration keys match the iOS / Android demos. They are not app secrets.
export const DEMO_KEY: string = 'abcdefgabcdefgob';
export const DEMO_IV: string = 'abcdefgabcdefgcc';
export const LEVEL_NAMES: string[] = ['Debug', 'Info', 'Warn', 'Error', 'Fatal'];
export const LEVEL_COLORS: string[] = ['#8E8E93', '#007AFF', '#FF9500', '#FF3B30', '#AF52DE'];
export const POLICIES: MXStoragePolicy[] = [MXStoragePolicy.Daily, MXStoragePolicy.Hourly,
  MXStoragePolicy.Weekly, MXStoragePolicy.Monthly];

export interface DemoConfiguration {
  nameSpace: string;
  directory: string;
  fileName: string;
  fileHeader: string;
  policyIndex: number;
  encrypted: boolean;
  useDirectoryAPI: boolean;
}
export interface DemoWriteRequest { token: string; count: number; workerId: number; benchmark: boolean; }
export interface DemoWriteResult { passed: boolean; count: number; milliseconds: number; error: string; }
export interface DemoBenchmark { count: number; milliseconds: number; workers: number; }

export function byteText(count: number): string {
  if (count < 1024) { return count + ' B'; }
  if (count < 1024 * 1024) { return (count / 1024).toFixed(1) + ' KB'; }
  return (count / 1024 / 1024).toFixed(2) + ' MB';
}
export function dateText(milliseconds: number): string {
  return milliseconds > 0 ? new Date(milliseconds).toLocaleString() : '—';
}

export class DemoSession {
  private logger?: MXLogger;
  configuration: DemoConfiguration = {
    nameSpace: 'com.djy.mxlogger', directory: '', fileName: 'mxlog',
    fileHeader: '{"platform":"HarmonyOS","appVersion":"0.1.0","demo":true}',
    policyIndex: 1, encrypted: true, useDirectoryAPI: false
  };

  get current(): MXLogger {
    if (!this.logger || !this.logger.isValid) { throw new Error('Logger 已销毁 / Logger is closed'); }
    return this.logger;
  }
  get isValid(): boolean { return this.logger?.isValid ?? false; }

  initialize(context: common.Context, config: DemoConfiguration = this.configuration): void {
    const options: MXLoggerOptions = {
      nameSpace: config.nameSpace, fileName: config.fileName, fileHeader: config.fileHeader,
      storagePolicy: POLICIES[config.policyIndex],
      cryptKey: config.encrypted ? DEMO_KEY : '', iv: config.encrypted ? DEMO_IV : ''
    };
    // Separate each policy/encryption combination so reopening cannot mix encryption formats.
    const directory = config.directory.trim() || context.filesDir + '/mxlogger_demo/' +
      config.policyIndex + (config.encrypted ? '_aes' : '_plain');
    options.directory = directory;
    // Destroy the old session before changing immutable initialization options.
    this.destroy();
    this.logger = config.useDirectoryAPI ? MXLogger.initializeWithDirectory(directory, options) :
      MXLogger.initialize(context, options);
    this.configuration = config;
    this.logger.setMaxDiskAge(7 * 24 * 60 * 60);
    this.logger.setMaxDiskSize(10 * 1024 * 1024);
    this.logger.setConsoleEnable(false);
    this.logger.setLevel(0);
  }

  destroy(): void { this.logger?.destroy(); }

  async benchmark(count: number, workers: number): Promise<DemoBenchmark> {
    const logger = this.current;
    if (!logger.enable || logger.level > 1) {
      throw new Error('请开启写入并将等级设为 Debug / Info · Enable logging and select Debug / Info');
    }
    const consoleEnabled = logger.consoleEnable;
    logger.setConsoleEnable(false);
    try {
      const tasks: Promise<DemoWriteResult>[] = [];
      const start = Date.now();
      for (let i = 0; i < workers; i++) {
        tasks.push(this.writeOnWorker({ token: logger.loggerToken, count: count, workerId: i, benchmark: workers === 1 })
          .catch((error: Object): DemoWriteResult => {
            return { passed: false, count: 0, milliseconds: 0, error: String(error) };
          }));
      }
      const results = await Promise.all(tasks);
      // Wait for every Worker, including when one fails, before allowing destroy/reconfiguration.
      const failure = results.find((item: DemoWriteResult) => !item.passed);
      if (failure) { throw new Error(failure.error); }
      return { count: results.reduce((sum: number, item: DemoWriteResult) => sum + item.count, 0),
        milliseconds: Date.now() - start, workers: workers };
    } finally {
      if (logger.isValid) { logger.setConsoleEnable(consoleEnabled); }
    }
  }

  private writeOnWorker(request: DemoWriteRequest): Promise<DemoWriteResult> {
    return new Promise<DemoWriteResult>((resolve, reject) => {
      const thread = new worker.ThreadWorker('entry/ets/workers/DemoWriter.ets');
      const timer = setTimeout(() => {
        thread.terminate(); reject(new Error('Worker timed out (60 s)'));
      }, 60000);
      thread.onmessage = (event: MessageEvents): void => {
        clearTimeout(timer); thread.terminate();
        const result = event.data as DemoWriteResult;
        if (result.passed) { resolve(result); } else { reject(new Error(result.error)); }
      };
      thread.onerror = (): void => {
        clearTimeout(timer); thread.terminate(); reject(new Error('Worker runtime error'));
      };
      thread.postMessage(request);
    });
  }
}
