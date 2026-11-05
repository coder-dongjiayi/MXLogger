import {
  FlutterPlugin, FlutterPluginBinding, MethodCall, MethodCallHandler, MethodChannel, MethodResult
} from '@ohos/flutter_ohos';
import common from '@ohos.app.ability.common';
import { MXLogger, MXLogLevel } from '@djy/mxlogger';

/** Resolves the application sandbox. Log operations stay on the shared C ABI. */
export default class FlutterMxloggerPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private context: common.Context | null = null;

  getUniqueClassName(): string {
    return 'FlutterMxloggerPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.context = binding.getApplicationContext();
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'flutter_mxlogger');
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
    this.context = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method !== 'initialize') {
      result.notImplemented();
      return;
    }
    if (this.context === null) {
      result.error('MXLOGGER_NO_CONTEXT', 'Flutter engine is detached', null);
      return;
    }
    const supplied = call.argument('directory') as string | null;
    const directory = supplied ?? `${this.context.filesDir}/com.mxlog.LoggerCache`;
    // Also loads the OHPM native library before Dart opens libmxlogger.so.
    MXLogger.coreVersion();
    const response = new Map<string, string>();
    response.set('directory', directory);
    result.success(response);
  }

  /** ArkTS and Dart can write to the same session using its loggerToken. */
  static log(loggerToken: string, level: MXLogLevel, message: string,
    name: string = 'flutter', tag: string = 'native'): number {
    return MXLogger.logWithToken(loggerToken, level, message, { name, tag });
  }
}
