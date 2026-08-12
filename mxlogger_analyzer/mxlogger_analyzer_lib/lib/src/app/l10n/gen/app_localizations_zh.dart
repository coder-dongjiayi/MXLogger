// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'MXLogger 日志解析器';

  @override
  String get parserSubtitle => '· 日志解析器';

  @override
  String get landingSubtitlePrefix => '基于 ';

  @override
  String get landingSubtitleSuffix => ' 的跨平台高性能日志库';

  @override
  String get landingDot1 => '零拷贝写入';

  @override
  String get landingDot2 => '断电不丢日志';

  @override
  String get dropTitle => '拖入日志文件开始';

  @override
  String get dropDesc => '把 .mx 日志文件拖到这里，或者点击下方按钮选择文件\n解析完成后自动展示日志列表';

  @override
  String get landingFilesTitle => '选择日志文件开始';

  @override
  String get landingFilesDesc => '拖拽或点击选择 .mx 文件';

  @override
  String get keyLabel => 'KEY';

  @override
  String get ivLabel => 'IV';

  @override
  String get keyHint => '16位解密密钥';

  @override
  String get ivHint => '16位偏移向量';

  @override
  String get cryptNote => '日志文件是加密的，请填写 Key 和 IV；可添加多组并勾选，未加密的文件留空即可';

  @override
  String get cryptConfirmTitle => '确认解密参数';

  @override
  String get cryptConfirmNote =>
      '请确认该 .mx 文件的解密参数，已代入上次填写的内容；可添加多组并勾选，解密时按序号依次尝试；未加密可留空。';

  @override
  String get addCryptGroup => '添加一组';

  @override
  String get removeCryptGroup => '移除这一组';

  @override
  String get cryptGroupToggleTip => '勾选后参与解密';

  @override
  String get cryptGroupOrderHint => '按勾选框中的序号依次尝试，解不开自动换下一组';

  @override
  String get clearExistingData => '导入前清空已有数据';

  @override
  String get clearExistingDataHint => '勾选后仅保留本次文件；不勾则与已有数据合并';

  @override
  String get pickFile => '选择日志文件';

  @override
  String get stepReading => '映射文件 (mmap)…';

  @override
  String get stepDecrypting => '解密并解码日志…';

  @override
  String get stepIndexing => '构建索引…';

  @override
  String get stepDone => '完成';

  @override
  String get parseFailed => '解析失败（格式或 Key/IV 有误）';

  @override
  String get fileReadFailed => '文件读取失败，请重试';

  @override
  String get themeToLight => '切换到浅色模式';

  @override
  String get themeToDark => '切换到深色模式';

  @override
  String get languageTip => '切换为英文';

  @override
  String get statStart => '起始';

  @override
  String get statEnd => '结束';

  @override
  String get shareAllTip => '分享日志（当前筛选结果）';

  @override
  String get cryptoTip => '修改解密 Key / IV';

  @override
  String get changeFileTip => '更换日志文件';

  @override
  String get refreshTip => '重新扫描本机日志';

  @override
  String get refresh => '刷新日志';

  @override
  String get embedEmptyTitle => '尚未解析本机日志';

  @override
  String get embedEmptyDesc => '点击下方按钮扫描并解析本机日志目录\n日志较多时解析需要几秒';

  @override
  String get noLogFiles => '日志目录下没有可解析的文件';

  @override
  String levelCountTip(String count) {
    return '$count 条';
  }

  @override
  String distTip(String label, String count, String pct) {
    return '$label  $count 条 ($pct%)';
  }

  @override
  String get headerTitle => 'Header';

  @override
  String headerItems(int count) {
    return '$count 项';
  }

  @override
  String get copyHeaderTip => '复制全部Header信息';

  @override
  String get headerCopied => '已复制 Header 信息';

  @override
  String get headerEmpty => '该日志无 Header 信息';

  @override
  String get headerRowTip => '查看这条日志的 Header';

  @override
  String get applyReparse => '应用并重新解析';

  @override
  String get keyIvUpdated => 'Key/IV 已更新';

  @override
  String get reparsedWithNewKey => '已使用新 Key/IV 重新解析';

  @override
  String get reparseFailed => '重新解析失败，请检查 Key/IV 是否正确';

  @override
  String get searchLogsHint => '搜索日志…（# 选 Tag，@ 选 Name）';

  @override
  String get searchLogsHintShort => '搜索…';

  @override
  String get searchPickTag => '选择 Tag · ↑↓ 切换 · 回车选中';

  @override
  String get searchPickName => '选择 Name · ↑↓ 切换 · 回车选中';

  @override
  String get searchNoMatch => '无匹配项';

  @override
  String get timeRange => '时间范围';

  @override
  String get timeFrom => '从';

  @override
  String get timeTo => '到';

  @override
  String get timeInputHint => '2026-07-03 10:30:15';

  @override
  String get apply => '应用';

  @override
  String get clear => '清除';

  @override
  String get foldAll => '折叠全部';

  @override
  String get unfoldAll => '展开全部';

  @override
  String get filterLabel => '筛选:';

  @override
  String get filterTypeTag => 'tag';

  @override
  String get filterTypeName => 'name';

  @override
  String get filterTypeTime => '时间';

  @override
  String get removeFilterTip => '移除筛选';

  @override
  String get clearAllFilters => '全部清除';

  @override
  String resultMatch(int matched, int total) {
    return '匹配 $matched / $total 条';
  }

  @override
  String resultTotal(int total) {
    return '$total 条日志';
  }

  @override
  String get noMatchLogs => '没有符合条件的日志';

  @override
  String get clearAllFiltersLink => '清除全部筛选条件';

  @override
  String get foldTip => '折叠';

  @override
  String get unfoldTip => '展开';

  @override
  String get filterByNameTip => '按 name 筛选';

  @override
  String get filterByTagTip => '按 tag 筛选';

  @override
  String get shareRowTip => '分享这条日志';

  @override
  String get fullscreenTip => '全屏查看';

  @override
  String get collapseFilters => '收起筛选区';

  @override
  String get expandFilters => '展开筛选区';

  @override
  String get moreActions => '更多操作';

  @override
  String get copyRowTip => '复制这条日志';

  @override
  String get copied => '已复制到剪贴板';

  @override
  String get jumpTopTip => '回到顶部';

  @override
  String get jumpBottomTip => '跳到底部';

  @override
  String get modalTitle => '日志详情';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldTags => 'Tags';

  @override
  String get fieldTime => '时间';

  @override
  String get fieldKind => '类型';

  @override
  String get kindJson => 'JSON';

  @override
  String get kindText => '文本';

  @override
  String get share => '分享';

  @override
  String get copyLog => '⧉ 复制日志';

  @override
  String get closeEsc => '关闭 (Esc)';

  @override
  String get close => '关闭';

  @override
  String get shareUnsupported => '当前环境不支持系统分享，已复制到剪贴板';

  @override
  String get shareFailed => '分享失败，请手动复制';

  @override
  String jsonItems(int count) {
    return '$count 项';
  }

  @override
  String jsonKeys(int count) {
    return '$count 键';
  }

  @override
  String get clickExpandTip => '点击展开';

  @override
  String viewFullLog(int count) {
    return '查看完整（共 $count 行）';
  }

  @override
  String get shareExportTitle => 'MXLogger 日志';

  @override
  String get shareHeaderSection => '===== Header =====';

  @override
  String shareBodyFiltered(int matched, int total) {
    return '===== 日志（筛选结果 $matched/$total 条）=====';
  }

  @override
  String shareBodyAll(int total) {
    return '===== 日志（共 $total 条）=====';
  }

  @override
  String get enterAnalyzer => '进入解析器';

  @override
  String get nextStep => '下一步';

  @override
  String get prevStep => '← 上一步';

  @override
  String get startImport => '开始导入';

  @override
  String selectedFiles(int count) {
    return '已选择 $count 个文件';
  }

  @override
  String get wizardStepFiles => '选择日志';

  @override
  String get wizardStepCrypt => '解密配置';

  @override
  String get wizardStepImport => '解析导入';

  @override
  String get clearSearchTip => '清除搜索内容';

  @override
  String get clearDataTip => '清除数据';

  @override
  String get clearDataConfirmTitle => '清空数据';

  @override
  String get clearDataConfirmMessage => '您确认要清空数据么？';

  @override
  String get cancel => '取消';

  @override
  String get confirmClear => '清空';

  @override
  String get dataCleared => '数据已清空';

  @override
  String get sortAsc => '时间正序';

  @override
  String get sortDesc => '时间倒序';

  @override
  String get keyIvTip => '查看解密 KEY / IV';

  @override
  String get keyIvDialogTitle => '解密 KEY / IV';

  @override
  String get keyIvNote => '当前配置的解密参数，勾选编号为解密尝试顺序。';

  @override
  String get keyIvEmpty => '尚未配置解密参数';

  @override
  String get keyIvDisabled => '未启用';

  @override
  String get clickToCopy => '点击复制';

  @override
  String get noLogRecords => '没有可解析的日志文件';
}
