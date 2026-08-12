import 'dart:convert';

import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';
import 'package:mxlogger_analyzer_lib/src/global/host/mx_prefs.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_state.dart';

const String _cryptEntriesKey = "mx_crypt_entries";

/// 单组时代的旧键，仅用于首次启动时迁移成一组参数
const String _cryptKeyKey = "mx_crypt_key";
const String _cryptIvKey = "mx_crypt_iv";

/// 一组 AES 解密参数（KEY / IV + 是否参与解密）。
class CryptEntry {
  const CryptEntry({this.cryptKey = "", this.cryptIv = "", this.enabled = true});

  factory CryptEntry.fromJson(Map<String, Object?> json) => CryptEntry(
        cryptKey: json["key"] as String? ?? "",
        cryptIv: json["iv"] as String? ?? "",
        enabled: json["enabled"] as bool? ?? true,
      );

  final String cryptKey;
  final String cryptIv;

  /// 勾选态：只有勾选的组参与解密，按列表顺序依次尝试
  final bool enabled;

  /// KEY / IV 都没填，视为空行（保存时丢弃）
  bool get isEmpty => cryptKey.isEmpty && cryptIv.isEmpty;

  CryptEntry copyWith({String? cryptKey, String? cryptIv, bool? enabled}) => CryptEntry(
        cryptKey: cryptKey ?? this.cryptKey,
        cryptIv: cryptIv ?? this.cryptIv,
        enabled: enabled ?? this.enabled,
      );

  CryptEntry trimmed() => CryptEntry(
        cryptKey: cryptKey.trim(),
        cryptIv: cryptIv.trim(),
        enabled: enabled,
      );

  Map<String, Object?> toJson() => {
        "key": cryptKey,
        "iv": cryptIv,
        "enabled": enabled,
      };

  @override
  bool operator ==(Object other) =>
      other is CryptEntry &&
      other.cryptKey == cryptKey &&
      other.cryptIv == cryptIv &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(cryptKey, cryptIv, enabled);
}

/// AES 解密参数表（可配多组），持久化到本地。
/// 解密时按列表顺序依次尝试勾选的组：第一组解不开就换第二组，以此类推。
class CryptSettings {
  const CryptSettings({this.entries = const <CryptEntry>[]});

  final List<CryptEntry> entries;

  /// 参与解密的组，顺序即尝试顺序
  List<CryptEntry> get activeEntries => entries
      .where((CryptEntry entry) => entry.enabled && entry.cryptKey.isNotEmpty)
      .toList(growable: false);

  /// 传给解析器的候选参数（顺序即尝试顺序）
  List<MxCryptPair> get cryptPairs => activeEntries
      .map((CryptEntry entry) => MxCryptPair(key: entry.cryptKey, iv: entry.cryptIv))
      .toList(growable: false);

  /// 首组 KEY（嵌入模式写入、单组入口读取用）
  String get cryptKey => entries.isEmpty ? "" : entries.first.cryptKey;

  /// 首组 IV
  String get cryptIv => entries.isEmpty ? "" : entries.first.cryptIv;

  @override
  bool operator ==(Object other) {
    if (other is! CryptSettings) return false;
    if (other.entries.length != entries.length) return false;
    for (int i = 0; i < entries.length; i++) {
      if (other.entries[i] != entries[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(entries);
}

class CryptSettingsStore extends MXState<CryptSettings> {
  CryptSettingsStore(MXPrefs prefs)
      : _prefs = prefs,
        super(_load(prefs));

  final MXPrefs _prefs;

  /// 读取多组参数；老版本只存过一组时迁移为单组，保证升级后设置不丢。
  static CryptSettings _load(MXPrefs prefs) {
    final String? raw = prefs.getString(_cryptEntriesKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<Object?> list = jsonDecode(raw) as List<Object?>;
        return CryptSettings(
          entries: list
              .whereType<Map<String, Object?>>()
              .map(CryptEntry.fromJson)
              .toList(growable: false),
        );
      } catch (_) {
        // 存储损坏时退回旧键 / 空表，不至于打不开分析器
      }
    }
    final String legacyKey = prefs.getString(_cryptKeyKey) ?? "";
    final String legacyIv = prefs.getString(_cryptIvKey) ?? "";
    if (legacyKey.isEmpty && legacyIv.isEmpty) return const CryptSettings();
    return CryptSettings(
      entries: [CryptEntry(cryptKey: legacyKey, cryptIv: legacyIv)],
    );
  }

  /// 整表保存：去空格、丢弃 KEY/IV 都为空的行。
  void saveEntries(List<CryptEntry> entries) {
    final List<CryptEntry> cleaned = entries
        .map((CryptEntry entry) => entry.trimmed())
        .where((CryptEntry entry) => !entry.isEmpty)
        .toList(growable: false);
    value = CryptSettings(entries: cleaned);
    _persist();
  }

  /// 单组入口（嵌入模式由宿主传入 Key/IV）：见 [upsertAll]。
  void upsert({required String cryptKey, required String cryptIv}) {
    upsertAll([MxCryptPair(key: cryptKey, iv: cryptIv)]);
  }

  /// 宿主传入的若干组解密参数：按给定顺序置于表首并勾选
  /// （已存在的同一组只确保勾选、不重复插入），用户自己加的其它组原样保留在后面。
  void upsertAll(List<MxCryptPair> pairs) {
    final List<CryptEntry> incoming = [];
    for (final MxCryptPair pair in pairs) {
      final CryptEntry entry =
          CryptEntry(cryptKey: pair.key, cryptIv: pair.iv).trimmed();
      if (entry.isEmpty) continue;
      final bool duplicated = incoming.any((CryptEntry other) =>
          other.cryptKey == entry.cryptKey && other.cryptIv == entry.cryptIv);
      if (!duplicated) incoming.add(entry);
    }
    if (incoming.isEmpty) return;
    final List<CryptEntry> rest = value.entries
        .where((CryptEntry entry) => !incoming.any((CryptEntry added) =>
            added.cryptKey == entry.cryptKey && added.cryptIv == entry.cryptIv))
        .toList();
    saveEntries([...incoming, ...rest]);
  }

  void _persist() {
    _prefs.setString(
      _cryptEntriesKey,
      jsonEncode(value.entries.map((CryptEntry entry) => entry.toJson()).toList()),
    );
    // 旧键同步首组，方便回滚到旧版本时设置仍在
    _prefs.setString(_cryptKeyKey, value.cryptKey);
    _prefs.setString(_cryptIvKey, value.cryptIv);
  }
}
