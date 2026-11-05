import worker, { MessageEvents } from '@ohos.worker';
import { MXLogger } from '@djy/mxlogger';
import { DemoWriteRequest, DemoWriteResult } from '../DemoSession';
import { BENCHMARK_NAME, BENCHMARK_TAG, benchmarkMessage } from '../DemoBenchmark';

worker.workerPort.onmessage = (event: MessageEvents): void => {
  let count: number = 0;
  const start = Date.now();
  let result: DemoWriteResult;
  try {
    const request = event.data as DemoWriteRequest;
    const logger = MXLogger.fromLoggerToken(request.token);
    for (let i = 0; i < request.count; i++) {
      const code = request.benchmark ?
        logger.info(benchmarkMessage(i + 1), { name: BENCHMARK_NAME, tag: BENCHMARK_TAG }) :
        logger.info('HarmonyOS Worker #' + request.workerId + ' · 中文日志 ✅ #' + i,
          { name: 'benchmark', tag: 'worker,' + request.workerId });
      if (code !== 0) { throw new Error('write returned ' + code); }
      count++;
    }
    logger.flush();
    result = { passed: true, count: count, milliseconds: Date.now() - start, error: '' };
  } catch (error) {
    result = { passed: false, count: count, milliseconds: Date.now() - start, error: String(error) };
  }
  worker.workerPort.postMessage(result);
};
