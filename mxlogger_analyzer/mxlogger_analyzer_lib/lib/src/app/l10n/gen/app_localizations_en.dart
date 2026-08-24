// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MXLogger Analyzer';

  @override
  String get parserSubtitle => '· Log Analyzer';

  @override
  String get landingSubtitlePrefix =>
      'Cross-platform high-performance logging built on ';

  @override
  String get landingSubtitleSuffix => '';

  @override
  String get landingDot1 => 'Zero-copy writes';

  @override
  String get landingDot2 => 'Power-loss safe';

  @override
  String get dropTitle => 'Drop a log file to start';

  @override
  String get dropDesc =>
      'Drop .mx log files here, or click the button below to choose\nLogs show up automatically once parsed';

  @override
  String get landingFilesTitle => 'Choose a log file to start';

  @override
  String get landingFilesDesc => 'Drag & drop or click to choose a .mx file';

  @override
  String get keyLabel => 'KEY';

  @override
  String get ivLabel => 'IV';

  @override
  String get keyHint => '16-byte decryption key';

  @override
  String get ivHint => '16-byte IV';

  @override
  String get cryptNote =>
      'For encrypted logs add Key and IV — several checked sets are tried in order; plain logs need no key set at all';

  @override
  String get cryptConfirmTitle => 'Confirm decryption parameters';

  @override
  String get cryptConfirmNote =>
      'Confirm the decryption parameters for this .mx file (prefilled with your last values); checked sets are tried in order, and plain logs need no key set at all.';

  @override
  String get addCryptGroup => 'Add key set';

  @override
  String get removeCryptGroup => 'Remove this set';

  @override
  String get cryptGroupToggleTip => 'Check to use for decryption';

  @override
  String get cryptGroupOrderHint =>
      'Tried in the order shown in the checkboxes; falls through to the next set. Drag the handle to reorder';

  @override
  String get reorderCryptGroup => 'Drag to reorder';

  @override
  String get cryptGroupEmptyHint =>
      'No key sets — logs are parsed as unencrypted; add a set on the left to decrypt';

  @override
  String get clearExistingData => 'Clear existing data before import';

  @override
  String get clearExistingDataHint =>
      'Checked keeps only this import; unchecked merges with existing data';

  @override
  String get pickFile => 'Choose log file';

  @override
  String get stepReading => 'Mapping file (mmap)…';

  @override
  String get stepDecrypting => 'Decrypting & decoding…';

  @override
  String get stepIndexing => 'Building index…';

  @override
  String get stepDone => 'Done';

  @override
  String get parseFailed => 'Parse failed (bad format or wrong Key/IV)';

  @override
  String get fileReadFailed => 'Failed to read file, please retry';

  @override
  String get dbWriteFailed => 'Failed to write to database, please retry';

  @override
  String get themeToLight => 'Switch to light mode';

  @override
  String get themeToDark => 'Switch to dark mode';

  @override
  String get languageTip => '切换为中文';

  @override
  String get statStart => 'Start';

  @override
  String get statEnd => 'End';

  @override
  String get shareAllTip => 'Share logs (current filter result)';

  @override
  String get cryptoTip => 'Edit decryption Key / IV';

  @override
  String get changeFileTip => 'Open another file';

  @override
  String get refreshTip => 'Rescan on-device logs';

  @override
  String get refresh => 'Refresh logs';

  @override
  String get embedEmptyTitle => 'On-device logs not parsed yet';

  @override
  String get embedEmptyDesc =>
      'Tap the button below to scan and parse the log directory\nParsing takes a few seconds when there are many logs';

  @override
  String get noLogFiles => 'No parsable files in the log directory';

  @override
  String levelCountTip(String count) {
    return '$count logs';
  }

  @override
  String distTip(String label, String count, String pct) {
    return '$label  $count logs ($pct%)';
  }

  @override
  String get headerTitle => 'Header';

  @override
  String headerItems(int count) {
    return '$count fields';
  }

  @override
  String get copyHeaderTip => 'Copy all header fields';

  @override
  String get headerCopied => 'Header copied';

  @override
  String get headerEmpty => 'This log has no header info';

  @override
  String get headerRowTip => 'View this log\'s header';

  @override
  String get applyReparse => 'Apply & re-parse';

  @override
  String get keyIvUpdated => 'Key/IV updated';

  @override
  String get reparsedWithNewKey => 'Re-parsed with new Key/IV';

  @override
  String get reparseFailed => 'Re-parse failed, please check Key/IV';

  @override
  String get searchLogsHint => 'Search logs…  (# for tags, @ for names)';

  @override
  String get searchLogsHintShort => 'Search…';

  @override
  String get searchPickTag => 'Pick a tag · ↑↓ to move · Enter to select';

  @override
  String get searchPickName => 'Pick a name · ↑↓ to move · Enter to select';

  @override
  String get searchNoMatch => 'No matches';

  @override
  String get timeRange => 'Time range';

  @override
  String get timeFrom => 'From';

  @override
  String get timeTo => 'To';

  @override
  String get timeInputHint => '2026-07-03 10:30:15';

  @override
  String get apply => 'Apply';

  @override
  String get clear => 'Clear';

  @override
  String get foldAll => 'Collapse all';

  @override
  String get unfoldAll => 'Expand all';

  @override
  String get filterLabel => 'Filters:';

  @override
  String get filterTypeTag => 'tag';

  @override
  String get filterTypeName => 'name';

  @override
  String get filterTypeTime => 'time';

  @override
  String get removeFilterTip => 'Remove filter';

  @override
  String get clearAllFilters => 'Clear all';

  @override
  String resultMatch(int matched, int total) {
    return 'Matched $matched / $total';
  }

  @override
  String resultTotal(int total) {
    return '$total logs';
  }

  @override
  String get noMatchLogs => 'No logs match the current filters';

  @override
  String get clearAllFiltersLink => 'Clear all filters';

  @override
  String get foldTip => 'Collapse';

  @override
  String get unfoldTip => 'Expand';

  @override
  String get filterByNameTip => 'Filter by name';

  @override
  String get filterByTagTip => 'Filter by tag';

  @override
  String get shareRowTip => 'Share this log';

  @override
  String get fullscreenTip => 'View fullscreen';

  @override
  String get collapseFilters => 'Hide filters';

  @override
  String get expandFilters => 'Show filters';

  @override
  String get moreActions => 'More actions';

  @override
  String get copyRowTip => 'Copy this log';

  @override
  String get copied => 'Copied to clipboard';

  @override
  String get jumpTopTip => 'Back to top';

  @override
  String get jumpBottomTip => 'Jump to bottom';

  @override
  String get modalTitle => 'Log detail';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldTags => 'Tags';

  @override
  String get fieldTime => 'Time';

  @override
  String get fieldKind => 'Kind';

  @override
  String get kindJson => 'JSON';

  @override
  String get kindText => 'Text';

  @override
  String get share => 'Share';

  @override
  String get copyLog => '⧉ Copy log';

  @override
  String get closeEsc => 'Close (Esc)';

  @override
  String get close => 'Close';

  @override
  String get shareUnsupported =>
      'System share unavailable, copied to clipboard instead';

  @override
  String get shareFailed => 'Share failed, please copy manually';

  @override
  String jsonItems(int count) {
    return '$count items';
  }

  @override
  String jsonKeys(int count) {
    return '$count keys';
  }

  @override
  String get clickExpandTip => 'Click to expand';

  @override
  String viewFullLog(int count) {
    return 'View full ($count lines)';
  }

  @override
  String get shareExportTitle => 'MXLogger logs';

  @override
  String get shareHeaderSection => '===== Header =====';

  @override
  String shareBodyFiltered(int matched, int total) {
    return '===== Logs (filtered $matched/$total) =====';
  }

  @override
  String shareBodyAll(int total) {
    return '===== Logs ($total total) =====';
  }

  @override
  String get enterAnalyzer => 'Enter Analyzer';

  @override
  String get nextStep => 'Next';

  @override
  String get prevStep => '← Back';

  @override
  String get startImport => 'Start import';

  @override
  String selectedFiles(int count) {
    return '$count file(s) selected';
  }

  @override
  String get wizardStepFiles => 'Choose logs';

  @override
  String get wizardStepCrypt => 'Decryption';

  @override
  String get wizardStepImport => 'Parse & import';

  @override
  String get clearSearchTip => 'Clear search';

  @override
  String get clearDataTip => 'Clear data';

  @override
  String get clearDataConfirmTitle => 'Clear Data';

  @override
  String get clearDataConfirmMessage =>
      'Are you sure you want to clear all data?';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirmClear => 'Clear';

  @override
  String get dataCleared => 'Data cleared';

  @override
  String get sortAsc => 'Oldest first';

  @override
  String get sortDesc => 'Newest first';

  @override
  String get keyIvTip => 'Manage decryption KEY / IV';

  @override
  String get keyIvDialogTitle => 'Decryption KEY / IV';

  @override
  String get keyIvNote =>
      'Add, remove, check or drag to reorder; the number marks the try order.';

  @override
  String get noLogRecords => 'No parsable log records';
}
