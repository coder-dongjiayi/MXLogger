import native from 'libmxlogger.so';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Entry
@Component
struct Index {
  @State report: string = '准备验证';

  aboutToAppear(): void {
    this.verify();
  }

  private verify(): void {
    try {
      const context = this.getUIContext().getHostContext();
      if (!context) {
        this.report = 'FAIL: 无法取得应用 Context';
        return;
      }
      const directory = context.filesDir + '/com.mxlog.LoggerCache';
      const plain = native.runSmoke(directory, false);
      const encrypted = native.runSmoke(directory, true);
      hilog.info(0x0000, 'MXLoggerPOC', 'MXLOGGER_OHOS_POC %{public}s', plain);
      hilog.info(0x0000, 'MXLoggerPOC', 'MXLOGGER_OHOS_POC %{public}s', encrypted);
      this.report = 'PASS · Core ' + native.coreVersion() + '\n\n明文\n' + plain + '\n\nAES\n' + encrypted;
    } catch (error) {
      this.report = 'FAIL: ' + String(error);
      hilog.error(0x0000, 'MXLoggerPOC', 'MXLOGGER_OHOS_POC_FAILED %{public}s', this.report);
    }
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        Text('MXLogger · 鸿蒙最小调用链').fontSize(24).fontWeight(FontWeight.Bold)
        Text('加载动态库 → FFI / Native 写入 → 关闭重开 → 解密读取').fontSize(15)
        Button('再次验证').onClick(() => this.verify())
        Text(this.report).fontSize(14).width('100%').copyOption(CopyOptions.InApp)
        Text('关闭并重新启动应用后，previousCount 应保留上一进程的记录。').fontSize(14)
      }.width('100%').padding(24)
    }.width('100%').height('100%')
  }
}
