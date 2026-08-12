import 'package:flutter_test/flutter_test.dart';

import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';
import 'package:mxlogger_analyzer_lib/src/global/host/mx_prefs.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/settings_store.dart';

/// 多组解密参数的持久化、迁移与「勾选顺序即尝试顺序」。
void main() {
  test("旧版单组配置迁移为一组并默认勾选", () async {
    final MXPrefs prefs = MXMemoryPrefs(const {
      "mx_crypt_key": "OLDKEY",
      "mx_crypt_iv": "OLDIV",
    });
    final CryptSettingsStore store = CryptSettingsStore(prefs);

    expect(store.value.entries.length, 1);
    expect(store.value.entries.single.cryptKey, "OLDKEY");
    expect(store.value.entries.single.cryptIv, "OLDIV");
    expect(store.value.entries.single.enabled, isTrue);
    expect(store.value.cryptPairs, const [MxCryptPair(key: "OLDKEY", iv: "OLDIV")]);
  });

  test("整表保存后可重新读出；空行被丢弃、首尾空格被去掉", () async {
    final MXPrefs prefs = MXMemoryPrefs();
    CryptSettingsStore(prefs).saveEntries(const [
      CryptEntry(cryptKey: " k1 ", cryptIv: " iv1 "),
      CryptEntry(),
      CryptEntry(cryptKey: "k2", cryptIv: "", enabled: false),
    ]);

    final CryptSettingsStore reopened = CryptSettingsStore(prefs);
    expect(reopened.value.entries.length, 2);
    expect(reopened.value.entries[0].cryptKey, "k1");
    expect(reopened.value.entries[0].cryptIv, "iv1");
    expect(reopened.value.entries[1].cryptKey, "k2");
    expect(reopened.value.entries[1].enabled, isFalse);
  });

  test("只有勾选且填了 KEY 的组参与解密，顺序即尝试顺序", () async {
    final MXPrefs prefs = MXMemoryPrefs();
    final CryptSettingsStore store = CryptSettingsStore(prefs);
    store.saveEntries(const [
      CryptEntry(cryptKey: "k1", cryptIv: "iv1"),
      CryptEntry(cryptKey: "k2", cryptIv: "iv2", enabled: false),
      CryptEntry(cryptKey: "", cryptIv: "iv3"),
      CryptEntry(cryptKey: "k4"),
    ]);

    expect(store.value.cryptPairs, const [
      MxCryptPair(key: "k1", iv: "iv1"),
      MxCryptPair(key: "k4"),
    ]);
  });

  test("嵌入模式写入多组：按给定顺序置于表首，用户自己加的组保留在后面", () async {
    final MXPrefs prefs = MXMemoryPrefs();
    final CryptSettingsStore store = CryptSettingsStore(prefs);
    store.saveEntries(const [
      CryptEntry(cryptKey: "mine", cryptIv: "myiv"),
      CryptEntry(cryptKey: "legacy", cryptIv: "legacyiv", enabled: false),
    ]);

    store.upsertAll(const [
      MxCryptPair(key: "current", iv: "curiv"),
      MxCryptPair(key: "legacy", iv: "legacyiv"),
    ]);

    expect(store.value.entries.map((CryptEntry e) => e.cryptKey),
        ["current", "legacy", "mine"]);
    // 传入的组一律勾选（含原本被取消勾选的 legacy），顺序即尝试顺序
    expect(store.value.cryptPairs, const [
      MxCryptPair(key: "current", iv: "curiv"),
      MxCryptPair(key: "legacy", iv: "legacyiv"),
      MxCryptPair(key: "mine", iv: "myiv"),
    ]);
  });

  test("嵌入模式写入单组：新组插到表首，已存在的同组只确保勾选", () async {
    final MXPrefs prefs = MXMemoryPrefs();
    final CryptSettingsStore store = CryptSettingsStore(prefs);
    store.saveEntries(const [CryptEntry(cryptKey: "mine", cryptIv: "myiv")]);

    store.upsert(cryptKey: "host", cryptIv: "hostiv");
    expect(store.value.entries.map((CryptEntry e) => e.cryptKey), ["host", "mine"]);

    // 用户手动取消勾选后，宿主再次传入同一组 → 只重新勾选，不重复插入
    store.saveEntries([
      store.value.entries.first.copyWith(enabled: false),
      store.value.entries.last,
    ]);
    store.upsert(cryptKey: "host", cryptIv: "hostiv");
    expect(store.value.entries.length, 2);
    expect(store.value.entries.first.enabled, isTrue);
  });
}
