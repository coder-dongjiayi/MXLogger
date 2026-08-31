import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'MXLogger 日志解析器'**
  String get appTitle;

  /// No description provided for @parserSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'· 日志解析器'**
  String get parserSubtitle;

  /// No description provided for @landingSubtitlePrefix.
  ///
  /// In zh, this message translates to:
  /// **'基于 '**
  String get landingSubtitlePrefix;

  /// No description provided for @landingSubtitleSuffix.
  ///
  /// In zh, this message translates to:
  /// **' 的跨平台高性能日志库'**
  String get landingSubtitleSuffix;

  /// No description provided for @landingDot1.
  ///
  /// In zh, this message translates to:
  /// **'零拷贝写入'**
  String get landingDot1;

  /// No description provided for @landingDot2.
  ///
  /// In zh, this message translates to:
  /// **'断电不丢日志'**
  String get landingDot2;

  /// No description provided for @dropTitle.
  ///
  /// In zh, this message translates to:
  /// **'拖入日志文件开始'**
  String get dropTitle;

  /// No description provided for @dropDesc.
  ///
  /// In zh, this message translates to:
  /// **'把 .mx 日志文件拖到这里，或者点击下方按钮选择文件\n解析完成后自动展示日志列表'**
  String get dropDesc;

  /// No description provided for @landingFilesTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择日志文件开始'**
  String get landingFilesTitle;

  /// No description provided for @landingFilesDesc.
  ///
  /// In zh, this message translates to:
  /// **'拖拽或点击选择 .mx 文件'**
  String get landingFilesDesc;

  /// No description provided for @keyLabel.
  ///
  /// In zh, this message translates to:
  /// **'KEY'**
  String get keyLabel;

  /// No description provided for @ivLabel.
  ///
  /// In zh, this message translates to:
  /// **'IV'**
  String get ivLabel;

  /// No description provided for @keyHint.
  ///
  /// In zh, this message translates to:
  /// **'16位解密密钥'**
  String get keyHint;

  /// No description provided for @ivHint.
  ///
  /// In zh, this message translates to:
  /// **'16位偏移向量'**
  String get ivHint;

  /// No description provided for @cryptNote.
  ///
  /// In zh, this message translates to:
  /// **'加密的日志请添加 Key 和 IV，可配多组并勾选，按序号依次尝试；未加密的日志无需配置，直接开始导入'**
  String get cryptNote;

  /// No description provided for @cryptConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认解密参数'**
  String get cryptConfirmTitle;

  /// No description provided for @cryptConfirmNote.
  ///
  /// In zh, this message translates to:
  /// **'请确认该 .mx 文件的解密参数，已代入上次填写的内容；可添加多组并勾选，解密时按序号依次尝试；未加密的日志可全部删除。'**
  String get cryptConfirmNote;

  /// No description provided for @addCryptGroup.
  ///
  /// In zh, this message translates to:
  /// **'添加一组'**
  String get addCryptGroup;

  /// No description provided for @removeCryptGroup.
  ///
  /// In zh, this message translates to:
  /// **'移除这一组'**
  String get removeCryptGroup;

  /// No description provided for @cryptGroupToggleTip.
  ///
  /// In zh, this message translates to:
  /// **'勾选后参与解密'**
  String get cryptGroupToggleTip;

  /// No description provided for @cryptGroupOrderHint.
  ///
  /// In zh, this message translates to:
  /// **'按勾选框中的序号依次尝试，解不开自动换下一组；拖动把手可调整顺序'**
  String get cryptGroupOrderHint;

  /// No description provided for @reorderCryptGroup.
  ///
  /// In zh, this message translates to:
  /// **'拖动调整尝试顺序'**
  String get reorderCryptGroup;

  /// No description provided for @cryptGroupEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'未配置解密参数，按未加密的日志解析；需要解密请点左侧按钮添加'**
  String get cryptGroupEmptyHint;

  /// No description provided for @clearExistingData.
  ///
  /// In zh, this message translates to:
  /// **'导入前清空已有数据'**
  String get clearExistingData;

  /// No description provided for @clearExistingDataHint.
  ///
  /// In zh, this message translates to:
  /// **'勾选后仅保留本次文件；不勾则与已有数据合并'**
  String get clearExistingDataHint;

  /// No description provided for @pickFile.
  ///
  /// In zh, this message translates to:
  /// **'选择日志文件'**
  String get pickFile;

  /// No description provided for @stepReading.
  ///
  /// In zh, this message translates to:
  /// **'映射文件 (mmap)…'**
  String get stepReading;

  /// No description provided for @stepDecrypting.
  ///
  /// In zh, this message translates to:
  /// **'解密并解码日志…'**
  String get stepDecrypting;

  /// No description provided for @stepIndexing.
  ///
  /// In zh, this message translates to:
  /// **'构建索引…'**
  String get stepIndexing;

  /// No description provided for @stepDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get stepDone;

  /// No description provided for @parseFailed.
  ///
  /// In zh, this message translates to:
  /// **'解析失败（格式或 Key/IV 有误）'**
  String get parseFailed;

  /// No description provided for @fileReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'文件读取失败，请重试'**
  String get fileReadFailed;

  /// No description provided for @dbWriteFailed.
  ///
  /// In zh, this message translates to:
  /// **'写入数据库失败，请重试'**
  String get dbWriteFailed;

  /// No description provided for @themeToLight.
  ///
  /// In zh, this message translates to:
  /// **'切换到浅色模式'**
  String get themeToLight;

  /// No description provided for @themeToDark.
  ///
  /// In zh, this message translates to:
  /// **'切换到深色模式'**
  String get themeToDark;

  /// No description provided for @languageTip.
  ///
  /// In zh, this message translates to:
  /// **'切换为英文'**
  String get languageTip;

  /// No description provided for @statStart.
  ///
  /// In zh, this message translates to:
  /// **'起始'**
  String get statStart;

  /// No description provided for @statEnd.
  ///
  /// In zh, this message translates to:
  /// **'结束'**
  String get statEnd;

  /// No description provided for @shareAllTip.
  ///
  /// In zh, this message translates to:
  /// **'分享日志（当前筛选结果）'**
  String get shareAllTip;

  /// No description provided for @cryptoTip.
  ///
  /// In zh, this message translates to:
  /// **'修改解密 Key / IV'**
  String get cryptoTip;

  /// No description provided for @changeFileTip.
  ///
  /// In zh, this message translates to:
  /// **'更换日志文件'**
  String get changeFileTip;

  /// No description provided for @refreshTip.
  ///
  /// In zh, this message translates to:
  /// **'重新扫描本机日志'**
  String get refreshTip;

  /// No description provided for @refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新日志'**
  String get refresh;

  /// No description provided for @embedEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'尚未解析本机日志'**
  String get embedEmptyTitle;

  /// No description provided for @embedEmptyDesc.
  ///
  /// In zh, this message translates to:
  /// **'点击下方按钮扫描并解析本机日志目录\n日志较多时解析需要几秒'**
  String get embedEmptyDesc;

  /// No description provided for @noLogFiles.
  ///
  /// In zh, this message translates to:
  /// **'日志目录下没有可解析的文件'**
  String get noLogFiles;

  /// No description provided for @levelCountTip.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条'**
  String levelCountTip(String count);

  /// No description provided for @distTip.
  ///
  /// In zh, this message translates to:
  /// **'{label}  {count} 条 ({pct}%)'**
  String distTip(String label, String count, String pct);

  /// No description provided for @headerTitle.
  ///
  /// In zh, this message translates to:
  /// **'Header'**
  String get headerTitle;

  /// No description provided for @headerItems.
  ///
  /// In zh, this message translates to:
  /// **'{count} 项'**
  String headerItems(int count);

  /// No description provided for @copyHeaderTip.
  ///
  /// In zh, this message translates to:
  /// **'复制全部Header信息'**
  String get copyHeaderTip;

  /// No description provided for @headerCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制 Header 信息'**
  String get headerCopied;

  /// No description provided for @headerEmpty.
  ///
  /// In zh, this message translates to:
  /// **'该日志无 Header 信息'**
  String get headerEmpty;

  /// No description provided for @headerRowTip.
  ///
  /// In zh, this message translates to:
  /// **'查看这条日志的 Header'**
  String get headerRowTip;

  /// No description provided for @applyReparse.
  ///
  /// In zh, this message translates to:
  /// **'应用并重新解析'**
  String get applyReparse;

  /// No description provided for @keyIvUpdated.
  ///
  /// In zh, this message translates to:
  /// **'Key/IV 已更新'**
  String get keyIvUpdated;

  /// No description provided for @reparsedWithNewKey.
  ///
  /// In zh, this message translates to:
  /// **'已使用新 Key/IV 重新解析'**
  String get reparsedWithNewKey;

  /// No description provided for @reparseFailed.
  ///
  /// In zh, this message translates to:
  /// **'重新解析失败，请检查 Key/IV 是否正确'**
  String get reparseFailed;

  /// No description provided for @searchLogsHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索日志…（# 选 Tag，@ 选 Name）'**
  String get searchLogsHint;

  /// No description provided for @searchLogsHintShort.
  ///
  /// In zh, this message translates to:
  /// **'搜索…'**
  String get searchLogsHintShort;

  /// No description provided for @searchPickTag.
  ///
  /// In zh, this message translates to:
  /// **'选择 Tag · ↑↓ 切换 · 回车选中'**
  String get searchPickTag;

  /// No description provided for @searchPickName.
  ///
  /// In zh, this message translates to:
  /// **'选择 Name · ↑↓ 切换 · 回车选中'**
  String get searchPickName;

  /// No description provided for @searchNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'无匹配项'**
  String get searchNoMatch;

  /// No description provided for @timeRange.
  ///
  /// In zh, this message translates to:
  /// **'时间范围'**
  String get timeRange;

  /// No description provided for @timeFrom.
  ///
  /// In zh, this message translates to:
  /// **'从'**
  String get timeFrom;

  /// No description provided for @timeTo.
  ///
  /// In zh, this message translates to:
  /// **'到'**
  String get timeTo;

  /// No description provided for @timeInputHint.
  ///
  /// In zh, this message translates to:
  /// **'2026-07-03 10:30:15'**
  String get timeInputHint;

  /// No description provided for @apply.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get apply;

  /// No description provided for @clear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get clear;

  /// No description provided for @foldAll.
  ///
  /// In zh, this message translates to:
  /// **'折叠全部'**
  String get foldAll;

  /// No description provided for @unfoldAll.
  ///
  /// In zh, this message translates to:
  /// **'展开全部'**
  String get unfoldAll;

  /// No description provided for @filterLabel.
  ///
  /// In zh, this message translates to:
  /// **'筛选:'**
  String get filterLabel;

  /// No description provided for @filterTypeTag.
  ///
  /// In zh, this message translates to:
  /// **'tag'**
  String get filterTypeTag;

  /// No description provided for @filterTypeName.
  ///
  /// In zh, this message translates to:
  /// **'name'**
  String get filterTypeName;

  /// No description provided for @filterTypeTime.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get filterTypeTime;

  /// No description provided for @removeFilterTip.
  ///
  /// In zh, this message translates to:
  /// **'移除筛选'**
  String get removeFilterTip;

  /// No description provided for @clearAllFilters.
  ///
  /// In zh, this message translates to:
  /// **'全部清除'**
  String get clearAllFilters;

  /// No description provided for @resultMatch.
  ///
  /// In zh, this message translates to:
  /// **'匹配 {matched} / {total} 条'**
  String resultMatch(int matched, int total);

  /// No description provided for @resultTotal.
  ///
  /// In zh, this message translates to:
  /// **'{total} 条日志'**
  String resultTotal(int total);

  /// No description provided for @noMatchLogs.
  ///
  /// In zh, this message translates to:
  /// **'没有符合条件的日志'**
  String get noMatchLogs;

  /// No description provided for @clearAllFiltersLink.
  ///
  /// In zh, this message translates to:
  /// **'清除全部筛选条件'**
  String get clearAllFiltersLink;

  /// No description provided for @foldTip.
  ///
  /// In zh, this message translates to:
  /// **'折叠'**
  String get foldTip;

  /// No description provided for @unfoldTip.
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get unfoldTip;

  /// No description provided for @filterByNameTip.
  ///
  /// In zh, this message translates to:
  /// **'按 name 筛选'**
  String get filterByNameTip;

  /// No description provided for @filterByTagTip.
  ///
  /// In zh, this message translates to:
  /// **'按 tag 筛选'**
  String get filterByTagTip;

  /// No description provided for @shareRowTip.
  ///
  /// In zh, this message translates to:
  /// **'分享这条日志'**
  String get shareRowTip;

  /// No description provided for @fullscreenTip.
  ///
  /// In zh, this message translates to:
  /// **'全屏查看'**
  String get fullscreenTip;

  /// No description provided for @collapseFilters.
  ///
  /// In zh, this message translates to:
  /// **'收起筛选区'**
  String get collapseFilters;

  /// No description provided for @expandFilters.
  ///
  /// In zh, this message translates to:
  /// **'展开筛选区'**
  String get expandFilters;

  /// No description provided for @moreActions.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get moreActions;

  /// No description provided for @copyRowTip.
  ///
  /// In zh, this message translates to:
  /// **'复制这条日志'**
  String get copyRowTip;

  /// No description provided for @copied.
  ///
  /// In zh, this message translates to:
  /// **'已复制到剪贴板'**
  String get copied;

  /// No description provided for @jumpTopTip.
  ///
  /// In zh, this message translates to:
  /// **'回到顶部'**
  String get jumpTopTip;

  /// No description provided for @jumpBottomTip.
  ///
  /// In zh, this message translates to:
  /// **'跳到底部'**
  String get jumpBottomTip;

  /// No description provided for @modalTitle.
  ///
  /// In zh, this message translates to:
  /// **'日志详情'**
  String get modalTitle;

  /// No description provided for @fieldName.
  ///
  /// In zh, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @fieldTags.
  ///
  /// In zh, this message translates to:
  /// **'Tags'**
  String get fieldTags;

  /// No description provided for @fieldTime.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get fieldTime;

  /// No description provided for @fieldKind.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get fieldKind;

  /// No description provided for @kindJson.
  ///
  /// In zh, this message translates to:
  /// **'JSON'**
  String get kindJson;

  /// No description provided for @kindText.
  ///
  /// In zh, this message translates to:
  /// **'文本'**
  String get kindText;

  /// No description provided for @share.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get share;

  /// No description provided for @copyLog.
  ///
  /// In zh, this message translates to:
  /// **'⧉ 复制日志'**
  String get copyLog;

  /// No description provided for @closeEsc.
  ///
  /// In zh, this message translates to:
  /// **'关闭 (Esc)'**
  String get closeEsc;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @shareUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前环境不支持系统分享，已复制到剪贴板'**
  String get shareUnsupported;

  /// No description provided for @shareFailed.
  ///
  /// In zh, this message translates to:
  /// **'分享失败，请手动复制'**
  String get shareFailed;

  /// No description provided for @jsonItems.
  ///
  /// In zh, this message translates to:
  /// **'{count} 项'**
  String jsonItems(int count);

  /// No description provided for @jsonKeys.
  ///
  /// In zh, this message translates to:
  /// **'{count} 键'**
  String jsonKeys(int count);

  /// No description provided for @clickExpandTip.
  ///
  /// In zh, this message translates to:
  /// **'点击展开'**
  String get clickExpandTip;

  /// No description provided for @viewFullLog.
  ///
  /// In zh, this message translates to:
  /// **'查看完整（共 {count} 行）'**
  String viewFullLog(int count);

  /// No description provided for @shareExportTitle.
  ///
  /// In zh, this message translates to:
  /// **'MXLogger 日志'**
  String get shareExportTitle;

  /// No description provided for @shareHeaderSection.
  ///
  /// In zh, this message translates to:
  /// **'===== Header ====='**
  String get shareHeaderSection;

  /// No description provided for @shareBodyFiltered.
  ///
  /// In zh, this message translates to:
  /// **'===== 日志（筛选结果 {matched}/{total} 条）====='**
  String shareBodyFiltered(int matched, int total);

  /// No description provided for @shareBodyAll.
  ///
  /// In zh, this message translates to:
  /// **'===== 日志（共 {total} 条）====='**
  String shareBodyAll(int total);

  /// No description provided for @enterAnalyzer.
  ///
  /// In zh, this message translates to:
  /// **'进入解析器'**
  String get enterAnalyzer;

  /// No description provided for @nextStep.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get nextStep;

  /// No description provided for @prevStep.
  ///
  /// In zh, this message translates to:
  /// **'← 上一步'**
  String get prevStep;

  /// No description provided for @startImport.
  ///
  /// In zh, this message translates to:
  /// **'开始导入'**
  String get startImport;

  /// No description provided for @selectedFiles.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {count} 个文件'**
  String selectedFiles(int count);

  /// No description provided for @wizardStepFiles.
  ///
  /// In zh, this message translates to:
  /// **'选择日志'**
  String get wizardStepFiles;

  /// No description provided for @wizardStepCrypt.
  ///
  /// In zh, this message translates to:
  /// **'解密配置'**
  String get wizardStepCrypt;

  /// No description provided for @wizardStepImport.
  ///
  /// In zh, this message translates to:
  /// **'解析导入'**
  String get wizardStepImport;

  /// No description provided for @clearSearchTip.
  ///
  /// In zh, this message translates to:
  /// **'清除搜索内容'**
  String get clearSearchTip;

  /// No description provided for @clearDataTip.
  ///
  /// In zh, this message translates to:
  /// **'清除数据'**
  String get clearDataTip;

  /// No description provided for @clearDataConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'清空数据'**
  String get clearDataConfirmTitle;

  /// No description provided for @clearDataConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'您确认要清空数据么？'**
  String get clearDataConfirmMessage;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirmClear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get confirmClear;

  /// No description provided for @dataCleared.
  ///
  /// In zh, this message translates to:
  /// **'数据已清空'**
  String get dataCleared;

  /// No description provided for @sortAsc.
  ///
  /// In zh, this message translates to:
  /// **'时间正序'**
  String get sortAsc;

  /// No description provided for @sortDesc.
  ///
  /// In zh, this message translates to:
  /// **'时间倒序'**
  String get sortDesc;

  /// No description provided for @keyIvTip.
  ///
  /// In zh, this message translates to:
  /// **'管理解密 KEY / IV'**
  String get keyIvTip;

  /// No description provided for @keyIvDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'解密 KEY / IV'**
  String get keyIvDialogTitle;

  /// No description provided for @keyIvNote.
  ///
  /// In zh, this message translates to:
  /// **'已保存的组掩码显示、不可编辑，需修改请删除后重新添加；可勾选与拖动排序，勾选编号为解密尝试顺序。'**
  String get keyIvNote;

  /// No description provided for @noLogRecords.
  ///
  /// In zh, this message translates to:
  /// **'没有可解析的日志文件'**
  String get noLogRecords;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
