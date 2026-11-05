import { DemoAction, DemoToggle, DemoStat, DemoHeader, DemoSection, DemoField } from '../DemoComponents';
import { MXLogger, MXLogLevel, MXLogOptions, MXLogFile, MXLogRecord } from '@djy/mxlogger';
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { BENCHMARK_COUNT } from '../DemoBenchmark';
import { DemoSession, DemoConfiguration, LEVEL_NAMES, LEVEL_COLORS, POLICIES,
  byteText, dateText } from '../DemoSession';

@Entry
@Component
struct Index {
  @StorageLink('demoChinese') chinese: boolean = true;
  @State screen: string = 'landing';
  @State busy: boolean = false;
  @State valid: boolean = false;
  @State logSizeText: string = '0 B';
  @State fileCount: number = 0;
  @State level: number = 0;
  @State loggingEnabled: boolean = true;
  @State consoleEnabled: boolean = false;
  @State maxAge: number = 604800;
  @State maxSize: number = 10485760;
  @State namespace: string = 'com.djy.mxlogger';
  @State policy: number = 1;
  @State encrypted: boolean = true;
  @State token: string = '';
  @State directory: string = '';
  @State feedback: string = '';
  @State files: MXLogFile[] = [];
  @State filename: string = '';
  @State visibleRecords: MXLogRecord[] = [];
  @State recordCount: number = 0;
  @State page: number = 0;
  @State query: string = '';
  @State recordLevel: number = -1;
  @State customMessage: string = '你好 HarmonyOS，MXLogger 中文日志 ✅';
  @State customName: string = 'demo';
  @State customTag: string = 'harmonyos,demo';
  @State customLevel: number = 1;
  @State initNamespace: string = 'com.djy.mxlogger';
  @State initDirectory: string = '';
  @State initFilename: string = 'mxlog';
  @State initHeader: string = '';
  @State initPolicy: number = 1;
  @State initEncrypted: boolean = true;
  @State initWithDirectory: boolean = false;
  private session: DemoSession = new DemoSession();
  private allRecords: MXLogRecord[] = [];
  private filteredRecords: MXLogRecord[] = [];
  private sequence: number = 0;
  private scroller: Scroller = new Scroller();

  private t(zh: string, en: string): string { return this.chinese ? zh : en; }
  private policies(): string[] { return this.chinese ? ['按天', '按小时', '按周', '按月'] : ['Daily', 'Hourly', 'Weekly', 'Monthly']; }
  private toast(message: string): void {
    this.feedback = message;
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2400 });
  }
  private execute(action: () => void, message: string = ''): void {
    if (this.busy) { return; }
    try {
      action(); this.refresh();
      if (message) { this.toast(message); }
    } catch (error) { this.failure(error); }
  }
  private failure(error: Object): void {
    const message = String(error);
    this.feedback = message;
    this.getUIContext().getPromptAction().showDialog({ title: this.t('调用失败', 'API error'), message: message,
      buttons: [{ text: this.t('知道了', 'OK'), color: '#4F46E5' }] }).catch(() => {});
    this.refresh();
  }
  private refresh(): void {
    this.valid = this.session.isValid;
    if (!this.valid) { this.token = ''; this.directory = ''; this.logSizeText = '—'; this.fileCount = 0; return; }
    const logger = this.session.current;
    const state = logger.state;
    this.token = logger.loggerToken; this.directory = logger.diskCachePath;
    this.logSizeText = byteText(logger.logSize); this.fileCount = logger.logFiles.length;
    this.level = logger.level; this.loggingEnabled = logger.enable; this.consoleEnabled = logger.consoleEnable;
    this.maxAge = logger.maxDiskAge; this.maxSize = logger.maxDiskSize;
    this.namespace = this.session.configuration.nameSpace;
    this.policy = this.session.configuration.policyIndex; this.encrypted = this.session.configuration.encrypted;
    if (state.errorDesc) { this.feedback = state.errorDesc; }
  }
  private enter(): void {
    this.execute(() => {
      if (!this.session.isValid) {
        const context = this.getUIContext().getHostContext();
        if (!context) { throw new Error('Context unavailable'); }
        this.session.initialize(context);
      }
      this.screen = 'home';
    });
  }
  private back(): void {
    if (this.busy) { return; }
    if (this.screen === 'records') { this.screen = 'files'; }
    else if (this.screen === 'home') { this.screen = 'landing'; }
    else { this.screen = 'home'; }
    this.refresh();
  }
  onBackPress(): boolean {
    if (this.busy) { return true; }
    if (this.screen !== 'landing') { this.back(); return true; }
    return false;
  }
  onPageShow(): void { this.refresh(); }
  private write(level: number): void {
    this.execute(() => {
      const logger = this.session.current;
      const message = LEVEL_NAMES[level] + ' · HarmonyOS 中文日志 ✅ #' + (++this.sequence);
      const options: MXLogOptions = { name: 'demo', tag: 'harmonyos,' + LEVEL_NAMES[level].toLowerCase() };
      let code = 0;
      if (level === 0) { code = logger.debug(message, options); }
      else if (level === 1) { code = logger.info(message, options); }
      else if (level === 2) { code = logger.warn(message, options); }
      else if (level === 3) { code = logger.error(message, options); }
      else { code = logger.fatal(message, options); }
      this.writeFeedback(level, code);
    });
  }
  private writeFeedback(level: number, code: number): void {
    if (code !== 0) { throw new Error('log returned ' + code); }
    if (!this.session.current.enable) { this.toast(this.t('写入已禁用，本条未保存', 'Logging disabled; record skipped')); }
    else if (level < this.session.current.level) { this.toast(this.t('低于当前等级，本条已过滤', 'Below current level; record filtered')); }
    else { this.toast(this.t('日志已写入', 'Log written')); }
  }
  private async choose(title: string, options: string[], action: (index: number) => void): Promise<void> {
    if (this.busy) { return; }
    try {
      const buttons: [promptAction.Button, promptAction.Button?, promptAction.Button?, promptAction.Button?, promptAction.Button?, promptAction.Button?] = [{ text: options[0], color: '#202124' }];
      for (let i = 1; i < options.length; i++) { buttons.push({ text: options[i], color: '#202124' }); }
      const result = await this.getUIContext().getPromptAction().showActionMenu({ title: title,
        buttons: buttons });
      this.execute(() => action(result.index));
    } catch (_) { /* Dismissing a picker leaves configuration unchanged. */ }
  }
  private async confirm(title: string, message: string, action: () => void): Promise<void> {
    if (this.busy) { return; }
    const result = await this.getUIContext().getPromptAction().showDialog({ title: title, message: message,
      buttons: [{ text: this.t('取消', 'Cancel'), color: '#6B7280' },
        { text: this.t('确认', 'Confirm'), color: '#EF4444' }] });
    if (result.index === 1) { this.execute(action, this.t('操作完成', 'Done')); }
  }
  private copy(text: string): void {
    pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text))
      .then(() => this.toast(this.t('已复制', 'Copied'))).catch((error: Object) => this.failure(error));
  }
  private openFiles(): void {
    this.execute(() => { this.files = this.session.current.logFiles; this.screen = 'files'; });
  }
  private openFile(name: string): void {
    this.execute(() => {
      this.allRecords = this.session.current.readLogFile(name).reverse();
      this.filename = name; this.query = ''; this.recordLevel = -1; this.page = 0;
      this.filterRecords(); this.screen = 'records';
    });
  }
  private filterRecords(): void {
    const text = this.query.toLowerCase();
    this.filteredRecords = this.allRecords.filter((row: MXLogRecord) =>
      (this.recordLevel < 0 || row.level === this.recordLevel) &&
      (!text || (row.msg + ' ' + row.name + ' ' + row.tag).toLowerCase().includes(text)));
    this.recordCount = this.filteredRecords.length;
    this.page = 0; this.paginate();
  }
  private paginate(): void { this.visibleRecords = this.filteredRecords.slice(this.page * 100, (this.page + 1) * 100); }
  private showRecord(row: MXLogRecord): void {
    this.getUIContext().getPromptAction().showDialog({ title: LEVEL_NAMES[row.level] + ' · ' + row.name,
      message: JSON.stringify(row, null, 2), buttons: [{ text: this.t('关闭', 'Close'), color: '#6B7280' },
        { text: this.t('复制 JSON', 'Copy JSON'), color: '#4F46E5' }] })
      .then((result) => { if (result.index === 1) { this.copy(JSON.stringify(row, null, 2)); } }).catch(() => {});
  }
  private configure(): void {
    const c = this.session.configuration;
    this.initNamespace = c.nameSpace; this.initDirectory = c.directory; this.initFilename = c.fileName;
    this.initHeader = c.fileHeader; this.initPolicy = c.policyIndex; this.initEncrypted = c.encrypted;
    this.initWithDirectory = c.useDirectoryAPI; this.screen = 'initialize';
  }
  private initialize(): void {
    this.execute(() => {
      const context = this.getUIContext().getHostContext();
      if (!context) { throw new Error('Context unavailable'); }
      const config: DemoConfiguration = { nameSpace: this.initNamespace.trim(), directory: this.initDirectory.trim(),
        fileName: this.initFilename.trim(), fileHeader: this.initHeader, policyIndex: this.initPolicy,
        encrypted: this.initEncrypted, useDirectoryAPI: this.initWithDirectory };
      if (!config.nameSpace || !config.fileName || /[\/\\]/.test(config.nameSpace + config.fileName) ||
        config.nameSpace === '.' || config.nameSpace === '..' || config.fileName === '.' || config.fileName === '..') {
        throw new Error(this.t('namespace / fileName 必须是单个非空路径分量', 'namespace / fileName must be nonempty path components'));
      }
      if (config.directory && !config.directory.startsWith('/')) { throw new Error('directory must be absolute'); }
      this.session.initialize(context, config); this.screen = 'home';
    }, this.t('实例已初始化', 'Logger initialized'));
  }
  private async benchmark(workers: number): Promise<void> {
    if (this.busy) { return; }
    this.busy = true; this.feedback = this.t('正在后台写入…', 'Writing in background…');
    try {
      const result = await this.session.benchmark(workers === 1 ? BENCHMARK_COUNT : 1000, workers);
      this.feedback = result.count + this.t(' 条 · ', ' records · ') + result.milliseconds + ' ms · ' + workers + ' Worker';
      this.toast(this.feedback); this.refresh();
    } catch (error) { this.failure(error); }
    finally { this.busy = false; }
  }

  @Builder
  private landing() {
    Column() {
      Row() {
        Blank()
        Button(this.chinese ? 'English' : '中文').fontColor('#6B7280').fontSize(14).backgroundColor(Color.Transparent)
          .onClick(() => { this.chinese = !this.chinese; }).id('demo.landingLanguage')
      }.width('100%').padding(16)
      Blank()
      Image($r('app.media.mxlogger_logo')).width(80).height(80)
      Text('MXLogger').fontSize(34).fontWeight(FontWeight.Bold).fontColor('#202124').margin({ top: 20 })
      Text(this.t('高性能 · 跨平台 · 加密日志', 'High performance · Cross platform · Encrypted logs'))
        .fontSize(15).fontColor('#6B7280').margin({ top: 12 })
      Text('HarmonyOS Native Demo\nCore ' + MXLogger.coreVersion()).fontSize(13).fontColor('#9295A0')
        .textAlign(TextAlign.Center).lineHeight(22).margin({ top: 12 })
      Blank()
      Button(this.t('进入演示', 'Explore Demo')).width('100%').height(52).fontSize(17).fontWeight(FontWeight.Bold)
        .backgroundColor('#4F46E5').onClick(() => this.enter()).id('demo.enter')
      Text('mmap · FlatBuffers · AES-CFB-128').fontSize(11).fontColor('#9295A0').margin({ top: 18, bottom: 16 })
    }.padding({ left: 28, right: 28, bottom: 20 }).width('100%').height('100%')
  }
  @Builder
  private home() {
    Column() {
      DemoHeader({ title: 'MXLogger Demo', chinese: this.chinese, busy: this.busy, onBack: () => this.back(), onLanguage: () => { this.chinese = !this.chinese; } })
      Scroll(this.scroller) {
        Column() {
          Column({ space: 18 }) {
            Row() {
              Text(this.namespace).fontSize(13).fontColor('#EFEDFF').layoutWeight(1).maxLines(1)
              Text(this.valid ? (this.encrypted ? 'AES' : 'PLAIN') : 'CLOSED').fontSize(11).fontColor(Color.White)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(6).backgroundColor('#25FFFFFF')
            }
            Row() {
              DemoStat({ value: this.logSizeText, label: this.t('日志大小', 'Log size') })
              DemoStat({ value: '' + this.fileCount, label: this.t('文件', 'Files') })
              DemoStat({ value: LEVEL_NAMES[this.level], label: this.t('等级', 'Level') })
              DemoStat({ value: this.policies()[this.policy], label: this.t('策略', 'Policy') })
            }
          }.width('100%').padding(20).borderRadius(20).backgroundColor('#4F46E5')
          if (this.feedback) {
            Text(this.feedback).fontSize(12).fontColor('#4F46E5').width('100%').padding(12)
              .backgroundColor('#EDEBFF').borderRadius(10).margin({ top: 12 }).id('demo.feedback')
          }
          DemoSection({ label: this.t('日志写入', 'WRITE LOGS') })
          ForEach(LEVEL_NAMES, (name: string, index: number) => {
            DemoAction({ title: this.t('写入 ', 'Write ') + name, subtitle: name.toLowerCase() + '(message, { name, tag })', icon: name.slice(0, 1), color: LEVEL_COLORS[index], identifier: 'demo.write.' + index, onAction: () => this.write(index), disabled: this.busy })
          })
          DemoAction({ title: this.t('模拟网络请求', 'Network request'), subtitle: 'info · JSON · network,api', icon: '↗', color: '#14A6A0', identifier: 'demo.network', onAction: () => {
            this.execute(() => {
              const code = this.session.current.info(JSON.stringify({ method: 'GET', url: '/api/user', status: 200, duration_ms: 128 }),
                { name: 'network', tag: 'network,api' });
              this.writeFeedback(1, code);
            });
          }, disabled: this.busy })
          DemoAction({ title: this.t('自定义日志', 'Custom log'), subtitle: 'log(level, message, { name, tag })', icon: '＋', color: '#4F46E5', identifier: 'demo.custom', onAction: () => { this.screen = 'custom'; }, disabled: this.busy })
          DemoAction({ title: this.t('通过 token 写入', 'Write with token'), subtitle: 'MXLogger.logWithToken()', icon: '#', color: '#A07855', identifier: 'demo.tokenWrite', onAction: () => {
            this.execute(() => { this.writeFeedback(1, MXLogger.logWithToken(this.session.current.loggerToken, MXLogLevel.Info,
              'Static token 中文日志 #' + (++this.sequence), { name: 'token', tag: 'token,static' })); });
          }, disabled: this.busy })
          DemoSection({ label: this.t('运行时配置', 'CONFIGURATION') })
          DemoAction({ title: this.t('日志等级 · ', 'Log level · ') + LEVEL_NAMES[this.level], subtitle: 'setLevel / level', icon: '≡', color: '#007AFF', identifier: 'demo.level', onAction: () => {
            this.choose('setLevel', LEVEL_NAMES, (index: number) => this.session.current.setLevel(index));
          }, disabled: this.busy })
          DemoToggle({ title: this.t('启用写入', 'Enable logging'), subtitle: 'setEnable / enable', value: this.loggingEnabled, identifier: 'demo.enable', onToggle: (value: boolean) => {
            this.execute(() => this.session.current.setEnable(value));
          }, disabled: this.busy })
          DemoToggle({ title: this.t('HiLog 控制台', 'HiLog console'), subtitle: 'setConsoleEnable / consoleEnable', value: this.consoleEnabled, identifier: 'demo.console', onToggle: (value: boolean) => {
            this.execute(() => this.session.current.setConsoleEnable(value));
          }, disabled: this.busy })
          DemoAction({ title: this.t('保留时长 · ', 'Max disk age · ') + (this.maxAge ? this.maxAge / 86400 + this.t(' 天', ' days') : '∞'), subtitle: 'setMaxDiskAge(seconds) / maxDiskAge', icon: '◷', color: '#FF9500', identifier: 'demo.age', onAction: () => {
              this.choose('setMaxDiskAge', [this.t('不限', 'Unlimited'), '1 day', '7 days', '30 days'],
                (index: number) => this.session.current.setMaxDiskAge([0, 86400, 604800, 2592000][index]));
            }, disabled: this.busy })
          DemoAction({ title: this.t('大小上限 · ', 'Max disk size · ') + (this.maxSize ? byteText(this.maxSize) : '∞'), subtitle: 'setMaxDiskSize(bytes) / maxDiskSize', icon: '▤', color: '#EC4899', identifier: 'demo.maxSize', onAction: () => {
              this.choose('setMaxDiskSize', [this.t('不限', 'Unlimited'), '1 MB', '10 MB', '50 MB'],
                (index: number) => this.session.current.setMaxDiskSize([0, 1048576, 10485760, 52428800][index]));
            }, disabled: this.busy })
          DemoSection({ label: this.t('性能与并发', 'PERFORMANCE & WORKERS') })
          DemoAction({ title: this.t('批量写入 100,000 条', 'Write 100,000 records'), subtitle: this.t('Info · 每条 message 61 B · 1 个 Worker', 'Info · 61 B per message · 1 Worker'), icon: '↯', color: '#22A06B', identifier: 'demo.benchmark', onAction: () => { this.benchmark(1); }, disabled: this.busy })
          DemoAction({ title: this.t('4 个 Worker 并发写入', '4 concurrent Workers'), subtitle: '4 × 1,000 · fromLoggerToken()', icon: 'W', color: '#14A6A0', identifier: 'demo.workers', onAction: () => { this.benchmark(4); }, disabled: this.busy })
          DemoSection({ label: this.t('文件管理', 'FILES') })
          DemoAction({ title: this.t('浏览日志文件', 'Browse log files'), subtitle: 'logFiles / readLogFile()', icon: '▤', color: '#007AFF', identifier: 'demo.files', onAction: () => this.openFiles(), disabled: this.busy })
          DemoAction({ title: this.t('刷回映射数据', 'Flush mapped data'), subtitle: 'flush() · async msync', icon: '↓', color: '#4F46E5', identifier: 'demo.flush', onAction: () => {
            this.execute(() => this.session.current.flush(), this.t('已请求 flush', 'Flush requested'));
          }, disabled: this.busy })
          DemoAction({ title: this.t('清理过期文件', 'Remove expired files'), subtitle: 'removeExpireData() · age / size', icon: '◷', color: '#FF9500', identifier: 'demo.expire', onAction: () => {
            this.confirm('removeExpireData()', this.t('按当前时长和大小上限清理，保留活跃文件。', 'Apply age / size limits; keep active file.'),
              () => this.session.current.removeExpireData());
          }, disabled: this.busy })
          DemoAction({ title: this.t('清理历史文件', 'Remove previous files'), subtitle: 'removeBeforeAllData()', icon: '↶', color: '#D6A21C', identifier: 'demo.before', onAction: () => {
            this.confirm('removeBeforeAllData()', this.t('删除历史文件，保留活跃文件。', 'Remove previous files; keep active file.'),
              () => this.session.current.removeBeforeAllData());
          }, disabled: this.busy })
          DemoAction({ title: this.t('清理全部非活跃文件', 'Remove all inactive files'), subtitle: 'removeAll() · ' + this.t('保留活跃文件', 'keeps active file'), icon: '×', color: '#EF4444', identifier: 'demo.removeAll', onAction: () => {
            this.confirm('removeAll()', this.t('删除本实例的非活跃文件，无法撤销。', 'Permanently delete inactive files for this logger.'),
              () => this.session.current.removeAll());
          }, disabled: this.busy })
          DemoSection({ label: this.t('实例与初始化', 'INSTANCE & INITIALIZATION') })
          DemoAction({ title: this.t('初始化参数 / 重建', 'Initialize / rebuild'), subtitle: this.policies()[this.policy] + ' · ' + (this.encrypted ? 'AES-CFB-128' : 'Plain') + ' · fileHeader', icon: '⚙', color: '#4F46E5', identifier: 'demo.initialize', onAction: () => this.configure(), disabled: this.busy })
          DemoAction({ title: this.t('关联共享实例', 'Attach shared logger'), subtitle: 'fromLoggerToken() · isValid', icon: '↔', color: '#14A6A0', identifier: 'demo.attach', onAction: () => {
            this.execute(() => {
              const alias = MXLogger.fromLoggerToken(this.session.current.loggerToken);
              this.writeFeedback(1, alias.info('Shared instance 中文日志', { name: 'alias', tag: 'shared' }));
            });
          }, disabled: this.busy })
          DemoAction({ title: 'loggerToken', subtitle: this.token || '—', icon: '#', color: '#4F46E5', identifier: 'demo.copyToken', onAction: () => this.copy(this.token), disabled: this.busy })
          DemoAction({ title: 'diskCachePath', subtitle: this.directory || '—', icon: '/', color: '#6B7280', identifier: 'demo.copyPath', onAction: () => this.copy(this.directory), disabled: this.busy })
          DemoAction({ title: this.t('实例状态', 'Instance state'), subtitle: 'state / isValid / errorDesc / coreVersion()', icon: 'i', color: '#FF9500', identifier: 'demo.state', onAction: () => {
            this.execute(() => {
              const message = this.valid ? JSON.stringify(this.session.current.state, null, 2) : 'isValid: false';
              this.getUIContext().getPromptAction().showDialog({ title: 'Core ' + MXLogger.coreVersion(),
                message: 'isValid: ' + this.session.isValid + '\n' + message,
                buttons: [{ text: 'OK', color: '#4F46E5' }] }).catch(() => {});
            });
          }, disabled: this.busy })
          DemoAction({ title: this.t('销毁实例', 'Destroy logger'), subtitle: 'destroy() · ' + this.t('所有别名失效', 'invalidates all aliases'), icon: '×', color: '#EF4444', identifier: 'demo.destroy', onAction: () => {
            this.confirm('destroy()', this.t('销毁后可通过初始化入口重新创建，磁盘数据保留。', 'Reinitialize to use again; disk data is retained.'),
              () => this.session.destroy());
          }, disabled: this.busy })
          DemoSection({ label: this.t('开发验证', 'VERIFICATION') })
          DemoAction({ title: this.t('运行 SDK 自动验收', 'Run SDK verification'), subtitle: this.t('独立测试目录 · 共享实例 / AES / Worker', 'Separate fixtures · shared state / AES / Worker'), icon: '✓', color: '#22A06B', identifier: 'demo.verify', onAction: () => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/Verification' }).catch((error: Object) => this.failure(error));
          }, disabled: this.busy })
          Text('Core ' + MXLogger.coreVersion() + ' · HarmonyOS · @djy/mxlogger')
            .fontSize(11).fontColor('#9295A0').padding({ top: 24, bottom: 32 })
        }.width('100%').padding({ left: 16, right: 16, top: 10 })
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%')
  }
  @Builder
  private filesPage() {
    Column() {
      DemoHeader({ title: this.t('日志文件', 'Log files'), chinese: this.chinese, busy: this.busy, onBack: () => this.back(), onLanguage: () => { this.chinese = !this.chinese; } })
      Row() {
        Text(this.files.length + this.t(' 个文件 · ', ' files · ') + this.logSizeText).fontSize(13).fontColor('#6B7280').layoutWeight(1)
        Button(this.t('刷新', 'Refresh')).backgroundColor('#4F46E5').fontSize(13).onClick(() => this.openFiles()).id('demo.filesRefresh')
      }.padding(16).width('100%')
      Text(this.directory).fontSize(11).fontColor('#9295A0').copyOption(CopyOptions.InApp).padding({ left: 16, right: 16, bottom: 12 })
      if (!this.files.length) {
        Text(this.t('暂无文件，先写入一条日志。', 'No files. Write a log first.')).fontColor('#6B7280').margin({ top: 60 })
      }
      List({ space: 10 }) {
        ForEach(this.files, (file: MXLogFile) => {
          ListItem() {
            Column({ space: 8 }) {
              Row() {
                Text(file.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#202124').layoutWeight(1)
                Text('›').fontColor('#9295A0').fontSize(22)
              }
              Text(byteText(file.size) + ' · ' + (this.encrypted ? 'AES-CFB-128' : 'Plain')).fontSize(12).fontColor('#4F46E5')
              Text(this.t('修改 ', 'Modified ') + dateText(file.lastTimeStamp * 1000)).fontSize(11).fontColor('#6B7280')
              Text(this.t('创建 ', 'Created ') + dateText(file.createTimeStamp * 1000)).fontSize(11).fontColor('#9295A0')
            }.alignItems(HorizontalAlign.Start).padding(16).width('100%').backgroundColor(Color.White).borderRadius(14)
              .onClick(() => this.openFile(file.name)).id('demo.file.' + file.name)
          }
        }, (file: MXLogFile) => file.name)
      }.padding({ left: 16, right: 16 }).layoutWeight(1).width('100%')
    }.height('100%').width('100%')
  }
  @Builder
  private recordsPage() {
    Column() {
      DemoHeader({ title: this.t('日志详情', 'Log records'), chinese: this.chinese, busy: this.busy, onBack: () => this.back(), onLanguage: () => { this.chinese = !this.chinese; } })
      Text(this.filename).fontSize(12).fontColor('#6B7280').maxLines(1).padding({ left: 16, right: 16, top: 8 }).width('100%')
      Row({ space: 8 }) {
        TextInput({ text: this.query, placeholder: this.t('搜索消息、name、tag', 'Search message, name, tag') })
          .layoutWeight(1).fontSize(14).onChange((text: string) => { this.query = text; this.filterRecords(); }).id('demo.search')
        Button(this.recordLevel < 0 ? this.t('全部', 'All') : LEVEL_NAMES[this.recordLevel]).fontSize(12).backgroundColor('#4F46E5')
          .onClick(() => { this.choose(this.t('筛选等级', 'Filter level'), [this.t('全部', 'All')].concat(LEVEL_NAMES), (index: number) => {
            this.recordLevel = index - 1; this.filterRecords();
          }); }).id('demo.recordLevel')
      }.padding(16).width('100%')
      if (!this.recordCount) { Text(this.t('没有匹配的日志', 'No matching records')).fontColor('#6B7280').padding(24) }
      List({ space: 10 }) {
        ForEach(this.visibleRecords, (row: MXLogRecord, index: number) => {
          ListItem() {
            Column({ space: 8 }) {
              Row({ space: 8 }) {
                Text(LEVEL_NAMES[row.level] || 'HEADER').fontSize(10).fontWeight(FontWeight.Bold).fontColor(Color.White)
                  .padding(5).backgroundColor(LEVEL_COLORS[row.level] || '#6B7280').borderRadius(5)
                Text(row.name).fontSize(12).fontWeight(FontWeight.Medium).fontColor('#202124').layoutWeight(1).maxLines(1)
              }
              Text(dateText(row.timestamp / 1000)).fontSize(11).fontColor('#9295A0')
              Text(row.msg).fontSize(14).fontColor('#202124').maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text('# ' + row.tag + ' · ' + (row.isMainThread ? 'Main' : 'Worker') + ' · tid ' + row.threadId)
                .fontSize(10).fontColor('#6B7280').maxLines(2)
            }.alignItems(HorizontalAlign.Start).width('100%').padding(14).backgroundColor(Color.White).borderRadius(14)
              .onClick(() => this.showRecord(row)).id('demo.record.' + index)
          }
        }, (row: MXLogRecord, index: number) => this.page + '_' + index + '_' + row.timestamp)
      }.padding({ left: 16, right: 16 }).layoutWeight(1).width('100%')
      Row() {
        Button('‹').enabled(this.page > 0).onClick(() => { this.page--; this.paginate(); }).backgroundColor('#4F46E5').id('demo.previous')
        Text(this.recordCount + this.t(' 条 · 第 ', ' records · Page ') + (this.page + 1) + '/' + Math.max(1, Math.ceil(this.recordCount / 100)))
          .fontSize(12).fontColor('#6B7280').layoutWeight(1).textAlign(TextAlign.Center)
        Button('›').enabled((this.page + 1) * 100 < this.recordCount).onClick(() => { this.page++; this.paginate(); })
          .backgroundColor('#4F46E5').id('demo.next')
      }.padding(16).width('100%')
    }.height('100%').width('100%')
  }
  @Builder
  private customPage() {
    Column() {
      DemoHeader({ title: this.t('自定义日志', 'Custom log'), chinese: this.chinese, busy: this.busy, onBack: () => this.back(), onLanguage: () => { this.chinese = !this.chinese; } })
      Scroll() {
        Column() {
          DemoField({ label: 'level' })
          Select(LEVEL_NAMES.map((text: string) => { return { value: text }; })).selected(this.customLevel).value(LEVEL_NAMES[this.customLevel])
            .onSelect((index: number) => { this.customLevel = index; }).width('100%').id('demo.customLevel')
          DemoField({ label: 'name' })
          TextInput({ text: this.customName }).onChange((text: string) => { this.customName = text; }).id('demo.customName')
          DemoField({ label: 'tag' })
          TextInput({ text: this.customTag }).onChange((text: string) => { this.customTag = text; }).id('demo.customTag')
          DemoField({ label: 'message' })
          TextArea({ text: this.customMessage }).height(160).onChange((text: string) => { this.customMessage = text; }).id('demo.customMessage')
          Button(this.t('写入日志', 'Write log')).width('100%').height(48).backgroundColor('#4F46E5').margin({ top: 24 })
            .onClick(() => this.execute(() => this.writeFeedback(this.customLevel,
              this.session.current.log(this.customLevel, this.customMessage, { name: this.customName, tag: this.customTag })))).id('demo.customSubmit')
        }.padding(20).width('100%')
      }.layoutWeight(1)
    }.height('100%').width('100%')
  }
  @Builder
  private initializePage() {
    Column() {
      DemoHeader({ title: this.t('初始化参数', 'Initialization'), chinese: this.chinese, busy: this.busy, onBack: () => this.back(), onLanguage: () => { this.chinese = !this.chinese; } })
      Scroll() {
        Column() {
          Text(this.t('修改参数后会销毁当前实例并创建新实例，默认恢复 Debug、7 天、10 MB。',
            'Apply destroys the current logger and initializes with Debug, 7 days and 10 MB.'))
            .fontSize(12).fontColor('#6B7280').width('100%')
          DemoField({ label: 'namespace' })
          TextInput({ text: this.initNamespace }).onChange((text: string) => { this.initNamespace = text; }).id('demo.initNamespace')
          DemoField({ label: this.t('directory（留空使用演示目录）', 'directory (blank: demo directory)') })
          TextInput({ text: this.initDirectory, placeholder: '/data/storage/…' }).onChange((text: string) => { this.initDirectory = text; }).id('demo.initDirectory')
          DemoField({ label: 'fileName' })
          TextInput({ text: this.initFilename }).onChange((text: string) => { this.initFilename = text; }).id('demo.initFilename')
          DemoField({ label: 'storagePolicy' })
          Select(this.policies().map((text: string, index: number) => { return { value: text + ' · ' + POLICIES[index] }; }))
            .selected(this.initPolicy).value(this.policies()[this.initPolicy]).onSelect((index: number) => { this.initPolicy = index; }).width('100%').id('demo.initPolicy')
          DemoField({ label: 'fileHeader' })
          TextArea({ text: this.initHeader }).height(100).onChange((text: string) => { this.initHeader = text; }).id('demo.initHeader')
          DemoField({ label: this.t('加密与初始化方式', 'Encryption & initialization API') })
          DemoToggle({ title: 'AES-CFB-128', subtitle: this.t('关闭后写入明文，默认目录会自动切换', 'Off: plaintext; default directory changes automatically'), value: this.initEncrypted, identifier: 'demo.initEncrypted', onToggle: (value: boolean) => { this.initEncrypted = value; }, disabled: this.busy })
          Text('cryptKey: abcdefgabcdefgob\niv: abcdefgabcdefgcc\n' + this.t('仅为演示，与 iOS / Android 参数一致。', 'Demo keys, same as iOS / Android.'))
            .fontSize(11).fontColor('#9295A0').width('100%').padding(12)
          DemoToggle({ title: 'initializeWithDirectory', subtitle: this.t('关闭时使用 initialize(context, options)', 'Off: initialize(context, options)'), value: this.initWithDirectory, identifier: 'demo.initDirectoryAPI', onToggle: (value: boolean) => { this.initWithDirectory = value; }, disabled: this.busy })
          Text(this.t('同一目录已有文件时，请保持原有密钥和 IV。fileHeader 仅在创建文件时写入。',
            'Existing files require the same key / IV. fileHeader is written only when creating a file.'))
            .fontSize(12).fontColor('#6B7280').width('100%').margin({ top: 16 })
          Button(this.t('应用并初始化', 'Apply & initialize')).width('100%').height(48).backgroundColor('#4F46E5')
            .margin({ top: 24, bottom: 28 }).onClick(() => this.initialize()).id('demo.initSubmit')
        }.width('100%').padding(20)
      }.layoutWeight(1).width('100%')
    }.height('100%').width('100%')
  }
  build() {
    Column() {
      if (this.screen === 'landing') { this.landing() }
      else if (this.screen === 'files') { this.filesPage() }
      else if (this.screen === 'records') { this.recordsPage() }
      else if (this.screen === 'custom') { this.customPage() }
      else if (this.screen === 'initialize') { this.initializePage() }
      else { this.home() }
    }.width('100%').height('100%').backgroundColor('#F2F2F7')
  }
}
