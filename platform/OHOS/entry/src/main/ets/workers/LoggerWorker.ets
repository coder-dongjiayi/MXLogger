import worker, { MessageEvents } from '@ohos.worker';
import { MXLogger } from '@djy/mxlogger';

const port = worker.workerPort;
port.onmessage = (event: MessageEvents): void => {
  try {
    const token = event.data as string;
    const logger = MXLogger.fromLoggerToken(token);
    for (let i = 0; i < 64; i++) {
      logger.info('worker #' + i, { name: 'sdk_worker', tag: 'worker' });
    }
    logger.flush();
    port.postMessage({ passed: true });
  } catch (error) {
    port.postMessage({ passed: false, error: String(error) });
  }
};
