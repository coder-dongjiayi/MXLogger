import { MXLogger } from '@djy/mxlogger';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { verifySDK, verifyPersistence } from '../SDKContracts';

@Entry
@Component
struct Verification {
  @State report: string = '准备验证';
  @State busy: boolean = false;

  aboutToAppear(): void {
    this.verify();
  }

  private async verify(): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    try {
      const context = this.getUIContext().getHostContext();
      if (!context) {
        this.report = 'FAIL: 无法取得应用 Context';
        return;
      }
      this.report = '正在验证 SDK、共享实例及 Worker…';
      const sdk = await verifySDK(context);
      const plain = verifyPersistence(context, false);
      const encrypted = verifyPersistence(context, true);
      hilog.info(0x0000, 'MXLoggerPOC', 'MXLOGGER_OHOS_POC %{public}s', plain);
      hilog.info(0x0000, 'MXLoggerPOC', 'MXLOGGER_OHOS_POC %{public}s', encrypted);
      hilog.info(0x0000, 'MXLoggerPOC', 'MXLOGGER_OHOS_SDK %{public}s', sdk);
      this.report = 'PASS · Core ' + MXLogger.coreVersion() + '\n\nSDK\n' + sdk + '\n\n明文\n' + plain + '\n\nAES\n' + encrypted;
    } catch (error) {
      this.report = 'FAIL: ' + String(error);
      hilog.error(0x0000, 'MXLoggerPOC', 'MXLOGGER_OHOS_POC_FAILED %{public}s', this.report);
    } finally {
      this.busy = false;
    }
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        Text('MXLogger · 鸿蒙 SDK').fontSize(24).fontWeight(FontWeight.Bold)
        Text('HAR → ArkTS API → 共享实例 / Worker → 重启读取').fontSize(15)
        Button('再次验证').enabled(!this.busy).onClick(() => this.verify())
        Text(this.report).fontSize(14).width('100%').copyOption(CopyOptions.InApp)
        Text('关闭并重新启动应用后，previousCount 应保留上一进程的记录。').fontSize(14)
      }.width('100%').padding(24)
    }.width('100%').height('100%')
  }
}
