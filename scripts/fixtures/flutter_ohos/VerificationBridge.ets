import { FlutterEngine, MethodCall, MethodCallHandler, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import FlutterMxloggerPlugin from 'flutter_mxlogger';
import { MXLogger, MXLogFile, MXLogLevel } from '@djy/mxlogger';
import hilog from '@ohos.hilog';

/** Only copied into the isolated verification app, never into the plugin HAR. */
export class VerificationBridge implements MethodCallHandler {
  private channel: MethodChannel;

  constructor(engine: FlutterEngine) {
    this.channel = new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), 'mxlogger_ohos_verify');
    this.channel.setMethodCallHandler(this);
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    try {
      if (call.method === 'report') {
        // Dart stdout may be disabled by the Release engine. Native HiLog is
        // the verification transport in every build mode.
        hilog.info(0xD003900, 'MXLoggerFlutter', 'MXLOGGER_FLUTTER_OHOS %{public}s',
          call.argument('report') as string);
        result.success(null);
        return;
      }
      const token = call.argument('token') as string;
      if (call.method === 'write') {
        const code = FlutterMxloggerPlugin.log(token, MXLogLevel.Info, call.argument('message') as string);
        if (code !== 0) {
          result.error('WRITE_FAILED', `Native return code ${code}`, null);
          return;
        }
        result.success(null);
      } else if (call.method === 'count') {
        const logger = MXLogger.fromLoggerToken(token);
        logger.flush();
        result.success(logger.logFiles.reduce((count: number, file: MXLogFile): number => {
          return count + logger.readLogFile(file.name).length;
        }, 0));
      } else {
        result.notImplemented();
      }
    } catch (error) {
      result.error('VERIFY_FAILED', String(error), null);
    }
  }
}
