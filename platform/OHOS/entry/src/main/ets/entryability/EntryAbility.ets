import { UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

export default class EntryAbility extends UIAbility {
  private page: string = 'pages/Index';

  onCreate(want: Want): void {
    this.page = want?.parameters?.mxloggerPage === 'verification' ? 'pages/Verification' : 'pages/Index';
    hilog.info(0x0000, 'MXLoggerPOC', 'Demo entry: %{public}s', this.page);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'MXLoggerPOC', 'Demo window ready');
    windowStage.loadContent(this.page, (error) => {
      if (error.code) {
        hilog.error(0x0000, 'MXLoggerPOC', 'loadContent failed: %{public}s', JSON.stringify(error));
      }
    });
  }
}
