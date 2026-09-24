# flutter_mxlogger

[English](./README.md) | [简体中文](./README_CN.md) | 日本語 | [한국어](./README_KO.md)

MXLogger は mmap メモリマッピングを基盤とし、AES-CFB-128 暗号化に対応したクロスプラットフォームのログライブラリです。コアは C/C++ で実装され、レコードは Google FlatBuffers でシリアライズされます。Flutter 側は `dart:ffi` から直接コアを呼び出すため、性能はネイティブとほぼ同等です。

プロジェクト全体は [MXLogger メインリポジトリ](https://github.com/coder-dongjiayi/MXLogger) を参照してください。

- **バージョン**: 2.1.0
- **要件**: Dart SDK `>=2.18.0 <4.0.0`、Flutter `>=3.3.0`
- **対応プラットフォーム**: iOS（>= 9.0）、Android（minSdk 21）

## 目次

- [インストール](#インストール)
- [クイックスタート](#クイックスタート)
- [1. アーキテクチャ](#1-アーキテクチャ)
- [2. Dart API](#2-dart-api)
  - [2.1 初期化](#21-初期化)
  - [2.2 ストレージポリシー `MXStoragePolicyType`](#22-ストレージポリシー-mxstoragepolicytype)
  - [2.3 ログの書き込み](#23-ログの書き込み)
  - [2.4 スイッチとレベル](#24-スイッチとレベル)
  - [2.5 ディスク管理](#25-ディスク管理)
  - [2.6 状態](#26-状態)
  - [2.7 書き込み失敗の記録](#27-書き込み失敗の記録)
  - [2.8 ログファイルの解析](#28-ログファイルの解析)
  - [2.9 ロガーの破棄](#29-ロガーの破棄)
- [3. `loggerToken`: モジュールと言語をまたいで 1 つのロガーを共有する](#3-loggertoken-モジュールと言語をまたいで-1-つのロガーを共有する)
  - [3.1 これは何か](#31-これは何か)
  - [3.2 サブモジュールからの書き込み（Dart）](#32-サブモジュールからの書き込みdart)
  - [3.3 ネイティブコードからの書き込み（Android / iOS）](#33-ネイティブコードからの書き込みandroid--ios)
  - [3.4 ライフタイム](#34-ライフタイム)
- [4. `.mx` ログファイルを読む](#4-mx-ログファイルを読む)
  - [4.1 ファイルの場所](#41-ファイルの場所)
  - [4.2 デスクトップアナライザー（macOS / Windows / Linux）](#42-デスクトップアナライザーmacos--windows--linux)
  - [4.3 アプリ内アナライザー（`mxlogger_analyzer_lib`）](#43-アプリ内アナライザーmxlogger_analyzer_lib)
  - [4.4 Dart で解析する](#44-dart-で解析する)
- [Example](#example)
- [License](#license)

## インストール

```yaml
dependencies:
  flutter_mxlogger: ^2.1.0
```

ネイティブ依存は自動的に取り込まれるため、手動設定は不要です。

- iOS（CocoaPods、既定）: `MXLogger 2.1.0` → `MXLoggerCore 2.1.0` に依存
- iOS（Swift Package Manager）: ホストアプリで Flutter の SwiftPM サポートを有効にしている場合（`flutter config --enable-swift-package-manager`）、プラグインは `ios/flutter_mxlogger/Package.swift` 経由で統合され、代わりに [MXLogger-SwiftPM](https://github.com/coder-dongjiayi/MXLogger-SwiftPM) `2.1.0` に依存します
- Android: Gradle が `io.github.coder-dongjiayi:mxlogger:2.1.0` に依存

## クイックスタート

```dart
import 'package:flutter_mxlogger/flutter_mxlogger.dart';

final logger = await MXLogger.initialize(
  nameSpace: "flutter.mxlogger",
  storagePolicy: MXStoragePolicyType.yyyyMMddHH,
  consoleEnable: true,
  cryptKey: "abcuioqbsdguijlk",   // 16 バイト
  iv: "bccuioqbsdguijiv",         // 省略時は cryptKey と同じ値
);

logger.setMaxDiskAge(60 * 60 * 24 * 7); // 最長 7 日間保持
logger.setMaxDiskSize(1024 * 1024 * 10); // 最大 10 MB
logger.setLevel(0);                      // 0:debug — すべてファイルに書き込む

logger.debug("this is debug message", name: "mxlogger", tag: "net,response");
logger.info("this is info message", name: "mxlogger", tag: "tag1,tag2");
logger.warn("this is warn message");
logger.error("this is error message");
logger.fatal("this is fatal message");
```

---

# 1. アーキテクチャ

```
┌──────────────────────────────────────────────────────────────┐
│  Dart      lib/src/flutter_mxlogger.dart                     │
│  · MethodChannel("flutter_mxlogger") — 既定ディレクトリの取得のみ│
│  · dart:ffi — 読み書きはすべてここ、チャネルのオーバーヘッドなし │
│  · WidgetsBindingObserver — バックグラウンド移行時のクリーンアップ│
└──────────────┬───────────────────────────┬───────────────────┘
               │ ffi lookup                │ ffi lookup
               │ (flutter_mxlogger_ プレフィックスのシンボル)     │
┌──────────────▼──────────────┐ ┌──────────▼───────────────────┐
│ iOS  flutter-bridge.mm      │ │ Android flutter-bridge.cpp   │
│ Objective-C MXLogger をブリッジ│ │ C++ mx_logger をブリッジ      │
└──────────────┬──────────────┘ └──────────┬───────────────────┘
               │                           │
        ┌──────▼───────────────────────────▼──────┐
        │  Core (C/C++): mmap + AES-CFB-128       │
        │  + FlatBuffers シリアライズ              │
        └─────────────────────────────────────────┘
```

重要なのは、**ログ書き込みの経路に MethodChannel が存在しない**ことです。`log()` は Dart からディスクまで同期的な FFI 呼び出しで完結し、メッセージキューもコーデックのエンコードもプラットフォームスレッド待ちもありません。

---

# 2. Dart API

## 2.1 初期化

### `MXLogger.initialize`（推奨）

```dart
static Future<MXLogger> initialize({
  required String nameSpace,
  String? directory,
  bool consoleEnable = false,
  MXStoragePolicyType storagePolicy = MXStoragePolicyType.yyyyMMdd,
  String? fileName,
  String? fileHeader,
  String? cryptKey,
  String? iv,
})
```

| パラメータ | 説明 |
|---|---|
| `nameSpace` | ログファイルの名前空間。一意性のためドメインの逆順表記を推奨。最終的なディレクトリは `directory/nameSpace` |
| `directory` | カスタムディレクトリ。省略時は MethodChannel でプラットフォーム既定値を取得: iOS `<Library>/com.mxlog.LoggerCache`、Android `<filesDir>/com.mxlog.LoggerCache` |
| `consoleEnable` | コンソール出力の有無。debug ビルドでのみ有効 |
| `storagePolicy` | ファイル分割ポリシー。2.2 を参照 |
| `fileName` | カスタムファイル名。既定値は `mxlog` |
| `fileHeader` | ファイルヘッダー。ファイル**作成時**に一度だけ書き込まれる。アプリバージョン、プラットフォーム、端末モデルなどのコンテキストを入れるのに適している |
| `cryptKey` | AES 鍵。**16 バイト: 長ければ切り詰め、短ければ 0 埋め。** 省略すると暗号化なし |
| `iv` | 初期化ベクトル。ルールは `cryptKey` と同じ。省略時は `cryptKey` と同じ値 |

> ⚠️ 16 バイト未満の `cryptKey` / `iv` の 0 埋めは v2.0.0 で完全に修正されました。短い鍵で書かれた古いログはアナライザーで読めない可能性があります。16 バイトちょうどの鍵を使うことを推奨します。

### 同期コンストラクタ

```dart
MXLogger({required String nameSpace, required String directory, ...})
```

`directory` は必須で、MethodChannel は使われず、呼び出しは同期です。

**初期化は例外を投げません。** ネイティブが null ハンドルを返した場合（例: ディレクトリを作成できない）、インスタンスは自動的に `enable == false` になり、以降の呼び出しはすべて安全に短絡し、null ポインタがネイティブに渡されることはありません。`logger.enable` で検出できます。

## 2.2 ストレージポリシー `MXStoragePolicyType`

| 値 | 粒度 | ファイル名の例 |
|---|---|---|
| `yyyyMMdd`（既定） | 日単位 | `2023-01-11_mxlog.mx` |
| `yyyyMMddHH` | 時間単位 | `2023-01-11-15_mxlog.mx` |
| `yyyyWw` | 週単位 | `2023-01-02w_mxlog.mx`（`02w` = その年の第 2 週） |
| `yyyyMM` | 月単位 | `2023-01_mxlog.mx` |

## 2.3 ログの書き込み

### インスタンスメソッド

```dart
int debug(String msg, {String? name, String? tag});
int info (String msg, {String? name, String? tag});
int warn (String msg, {String? name, String? tag});
int error(String msg, {String? name, String? tag});
int fatal(String msg, {String? name, String? tag});

int log(int lvl, String msg, {String? name, String? tag});
```

- `lvl`: `0` debug、`1` info、`2` warn、`3` error、`4` fatal
- `name`: ロガー名。通常はモジュール名
- `tag`: タグ。複数はカンマ区切り（`"net,response"`）。アナライザーでタグによる絞り込みができる
- `msg` が有効な JSON の場合、コンソールにはインデント付きで整形表示される

**戻り値:**

| 値 | 意味 |
|---|---|
| `0` | 成功 |
| `-1` | ファイル拡張に失敗 |
| `-2` | unmap に失敗 |
| `-3` | mmap に失敗 |

### クラスメソッド（モジュール化されたアプリ向け）

大規模アプリをモジュールに分割していると、サブモジュールがロガーオブジェクトを保持しづらいことがよくあります。その場合は `loggerToken` 文字列を渡してください。

```dart
// メインプロジェクト
final token = logger.loggerToken;   // 保存するか、グローバルサービスに登録する

// サブモジュール — ロガーインスタンスに依存しない
MXLogger.infoLog(token, "module message", name: "user_module", tag: "login");
```

```dart
static void logLoggerToken(String? loggerToken, int lvl, String msg, {String? name, String? tag});
static void debugLog(String? loggerToken, String msg, {String? name, String? tag});
static void infoLog (String? loggerToken, String msg, {String? name, String? tag});
static void warnLog (String? loggerToken, String msg, {String? name, String? tag});
static void errorLog(String? loggerToken, String msg, {String? name, String? tag});
static void fatalLog(String? loggerToken, String msg, {String? name, String? tag});
```

同じ `loggerToken` はネイティブ側でも使えます。Android は `FlutterMxloggerPlugin.info(...)`、iOS は `[FlutterMxloggerPlugin info:...]` で、同じファイルに書き込まれます。トークンとは何か、有効期間、ネイティブからの使い方は[第 3 章](#3-loggertoken-モジュールと言語をまたいで-1-つのロガーを共有する)で説明します。

## 2.4 スイッチとレベル

```dart
void setLevel(int lvl);        // level >= lvl のログだけファイルに書き込む
void setEnable(bool enable);   // マスタースイッチ。false なら何も書き込まない
void setConsoleEnable(bool enable);
void shouldRemoveExpiredDataWhenEnterBackground(bool should); // 既定値 true
```

- `setLevel(2)` にすると warn 以上だけがディスクに到達し、debug/info は捨てられます。**コンソールには影響せず**、すべてのレベルがそのまま出力されます。
- `setConsoleEnable` は**static フィールド**に書き込むため、すべてのロガーインスタンスにグローバルに適用されます。ロガー構築時に渡した `consoleEnable` もこのグローバル値を上書きします。

> 🔁 1.x からの移行: `setFileLevel(int)` は `setLevel(int)` に改名されました。意味は変わりません。

## 2.5 ディスク管理

```dart
void setMaxDiskAge(int seconds);  // 既定値 0 = 無制限
void setMaxDiskSize(int bytes);   // 既定値 0 = 無制限

void removeExpireData();      // 上記 2 つのしきい値に従ってクリーンアップ
void removeBeforeAllData();   // 書き込み中のファイル以外をすべて削除
void removeAll();             // すべてのログファイルを削除
```

`removeExpireData()` は 2 段階でクリーンアップします。まず最終更新時刻が `maxDiskAge` より古いファイルを削除し、それでも合計サイズが `maxDiskSize` を超えていれば、古いファイルから順に削除を続けます。**現在書き込み中のファイルは決して削除されません。**

アプリがバックグラウンドに移行したとき自動的に一度呼ばれます。`shouldRemoveExpiredDataWhenEnterBackground(false)` で無効化できます。

## 2.6 状態

| メンバー | 型 | 説明 |
|---|---|---|
| `enable` | `bool` | ログ機能が利用可能か |
| `consoleEnable` | `bool` | コンソールスイッチ（グローバル） |
| `loggerToken` | `String?` | 基盤ロガーの一意なトークン。モジュール間で受け渡すために使う |
| `diskcachePath` | `String` | ログディレクトリ（`directory` + `nameSpace`） |
| `diskcacheErrorPath` | `String` | エラー記録ファイルのパス。つまり `diskcachePath/error.txt` |
| `logSize` | `int` | 保存済みログの合計サイズ（バイト） |
| `logFiles` | `List<MXFileEntity>` | ログファイルの一覧 |
| `errorDesc` | `String?` | 直近の書き込み失敗の説明。失敗がなければ `null` |
| `cryptKey` / `iv` | `String?` | 初期化時に渡した暗号化パラメータ |

### `MXFileEntity`

```dart
class MXFileEntity {
  String? name;          // ファイル名
  int size;              // サイズ（バイト）
  int createTimeStamp;   // 作成タイムスタンプ（秒）
  int lastTimeStamp;     // 最終更新タイムスタンプ（秒）

  DateTime get createTime;
  DateTime get lastTime;
}
```

## 2.7 書き込み失敗の記録

`log()` が 0 以外を返した場合、そのエントリは書き込まれていません。後で調査できるように、失敗を別のプレーンテキストファイルに記録できます。

```dart
final code = logger.error("something went wrong");
if (code != 0) {
  logger.writeFail(
    code: code,
    errorDesc: logger.errorDesc ?? "",
    other: "userId=$userId",
  );
}
```

エントリは JSON 行として `diskcacheErrorPath` に追記されます。

```json
{"code":-3,"error":"mmap failed","other":"userId=123"}
```

```dart
void writeFail({required int code, required String errorDesc, String? other});
void deleteFailFile();  // エラーファイルを削除
void closeFailFile();   // 書き込みストリームを閉じる
```

> パスが無効なとき（未初期化、無効化済み、破棄済み）、`writeFail` はファイルシステムのルートに書き込むのではなく即座に戻ります。

## 2.8 ログファイルの解析

```dart
static List<Map<String, dynamic>> selectLogmsg({
  required String diskcacheFilePath,
  String? cryptKey,
  String? iv,
});
```

ログファイルのフルパスと、書き込み時に使った暗号化パラメータを渡します（暗号化していないファイルは省略）。エントリは**新しいものから順に**返され、各エントリは次のフィールドを含みます。

| フィールド | 説明 |
|---|---|
| `name` | ロガー名 |
| `tag` | タグ |
| `msg` | ログメッセージ |
| `level` | レベル |
| `timestamp` | タイムスタンプ |
| `thread_id` | スレッド ID |
| `is_main_thread` | メインスレッドだったか |
| `error_code` | `"1"` はそのエントリのデコード失敗を意味する。通常は `cryptKey` / `iv` の誤り |

同期 FFI 呼び出しのため、大きなファイルではブロックします。isolate で実行してください。

```dart
final records = await Isolate.run(() => MXLogger.selectLogmsg(
      diskcacheFilePath: path,
      cryptKey: key,
      iv: iv,
    ));
```

`logFiles` と組み合わせれば、アプリ内ログビューアを作るには十分です。example の `log_viewer_page.dart` がまさにそれを実装しています。UI を自作したくない場合は、[第 4 章](#4-mx-ログファイルを読む)にある既製のデスクトップアナライザーとアプリ内アナライザーを参照してください。

> `selectLogfiles({required String directory})` は未実装のスタブで、すべてのプラットフォームで空リストを返します。使用しないでください。

## 2.9 ロガーの破棄

```dart
static void destroy({required String nameSpace, String? directory});
static void destroyWithLoggerToken(String loggerToken);
```

破棄では、まず対応する Dart インスタンスを無効化し（ライフサイクルオブザーバーの削除、エラーファイルのシンクを閉じる、ネイティブハンドルのクリア）、その後でネイティブオブジェクトを解放します。

この順序が重要です。ネイティブを先に解放すると、バックグラウンド移行時のクリーンアップコールバックが解放済みポインタでネイティブコードを呼び出し、use-after-free でクラッシュします。

同じ `nameSpace + directory` で構築した複数の Dart インスタンスは 1 つのネイティブオブジェクトを共有し、`destroy` はその**すべて**を無効化します。以前のインスタンスが取り残されることはありません。

---

# 3. `loggerToken`: モジュールと言語をまたいで 1 つのロガーを共有する

## 3.1 これは何か

`loggerToken` は 1 つのネイティブロガーを識別する文字列です。C++ コアがログディレクトリから導出します: `md5(directory/nameSpace)`、すなわち `diskcachePath` の MD5 です。そこから 3 つの性質が導かれます。

- 同じ `nameSpace` + `directory` は常に同じトークンになります。起動ごとに変わらず、iOS と Android でも同じです。ディレクトリが異なればトークンも異なります。
- コアはグローバルテーブル `token → logger` を保持します。トークンを受け取るすべての API はこのテーブルでロガーを探すため、トークンはそのロガーが現在のプロセスで初期化されている間だけ機能します。
- 秘密情報ではなく、`cryptKey` / `iv` とは無関係です。保存、モジュール間での受け渡し、出力はすべて問題ありません。

`logger.loggerToken`（または `getLoggerToken()`）で読み取ります。インスタンスが無効なとき、例えば初期化に失敗したとき（2.1）は `null` になります。

## 3.2 サブモジュールからの書き込み（Dart）

モジュール化されたアプリでは、メインプロジェクトがロガーを所有し、ディレクトリと暗号化設定を知っています。サブモジュールはそのどちらにも依存すべきではありません。トークンを渡し、2.3 に挙げたクラスメソッドを使わせてください。

```dart
// メインプロジェクト: 一度初期化し、トークンを公開する
final logger = await MXLogger.initialize(nameSpace: "com.example.app", cryptKey: key, iv: iv);
AppServices.loggerToken = logger.loggerToken;   // 任意のサービスロケーター / DI コンテナで可

// サブモジュール: MXLogger の設定を一切知らない
MXLogger.infoLog(AppServices.loggerToken, "user tapped pay", name: "pay", tag: "ui");
MXLogger.errorLog(AppServices.loggerToken, "payment failed: $error", name: "pay", tag: "order");
```

すべてのエントリは同じファイルに書き込まれ、メインプロジェクトのインスタンスと同じレベルフィルター、暗号化、コンソールスイッチに従います。トークンが `null` または未知の場合、クラスメソッドはそのエントリを捨てます。例外は投げられません。

## 3.3 ネイティブコードからの書き込み（Android / iOS）

トークンは共有の C++ コアで計算されるため、ネイティブ層も同じ文字列を理解します。自前のチャネル（MethodChannel、Pigeon、ネイティブのシングルトンなど）で渡せば、Flutter のロガーのファイルに直接書き込めます。

```java
// Android: com.coderdjy.mxlogger.FlutterMxloggerPlugin
FlutterMxloggerPlugin.info(loggerToken, /*tag*/ "network", /*name*/ "okhttp", /*msg*/ "GET /user 200");
```

```objc
// iOS: FlutterMxloggerPlugin.h
[FlutterMxloggerPlugin info:loggerToken name:@"URLSession" msg:@"GET /user 200" tag:@"network"];
```

引数の順序に注意してください。Android は `(token, tag, name, msg)`、iOS は `(token, name, msg, tag)` です。どちらも `debug` / `info` / `warn` / `error` / `fatal` を提供します。ネイティブコードが MXLogger SDK 自体をリンクしている場合は、SDK 自身のトークン系メソッドも使えます: Android は `MXLogger.log(token, tag, level, name, msg)`、iOS は `[MXLogger infoWithLoggerToken:name:msg:tag:]`（Swift: `MXLogger.info(loggerToken:name:message:tag:)`）。

## 3.4 ライフタイム

- トークンは `MXLogger.initialize` から `destroy` / `destroyWithLoggerToken`（2.9）まで有効です。同じ `nameSpace` + `directory` を 2 回構築すると 1 つのネイティブロガーが再利用されるため、両方の Dart インスタンスが同じトークンを返します。
- `MXLogger.destroyWithLoggerToken(token)` は、文字列しか持っていないコードのための破棄です。そのトークンに対応するすべての Dart インスタンスを無効化し（`enable` が `false` になり、以降の呼び出しは何もしない）、ネイティブオブジェクトを解放します。以後、そのトークンでの書き込みは捨てられます。
- 同じパラメータで再初期化すると同一のトークン文字列が得られ、書き込みが再開されます。したがって保存したトークンは起動をまたいで陳腐化しませんが、メインプロジェクトがこのプロセスでロガーを初期化してからでないと機能しません。

クイックリファレンス:

| 目的 | API |
|---|---|
| トークンの取得 | `logger.loggerToken` |
| Dart からの書き込み | `MXLogger.debugLog / infoLog / warnLog / errorLog / fatalLog(token, msg, name:, tag:)`、`MXLogger.logLoggerToken(token, lvl, msg, name:, tag:)` |
| Android からの書き込み | `FlutterMxloggerPlugin.debug / info / warn / error / fatal(token, tag, name, msg)` |
| iOS からの書き込み | `[FlutterMxloggerPlugin debug / info / warn / error / fatal:token name: msg: tag:]` |
| トークンによる破棄 | `MXLogger.destroyWithLoggerToken(token)` |

# 4. `.mx` ログファイルを読む

`.mx` ファイルはテキストではありません。各レコードは flatbuffer で、ロガーが `cryptKey` / `iv` 付きで作成された場合はファイル全体が AES-CFB-128 で暗号化されているため、エディタで開いてもバイナリのノイズしか見えません。読み取り手段は 3 つあり、シナリオで選びます。

| シナリオ | 使うもの |
|---|---|
| 端末から取り出した、またはユーザーがアップロードしたファイルを PC で分析する | [4.2 デスクトップアナライザー](#42-デスクトップアナライザーmacos--windows--linux) |
| テスト中に PC を使わず端末上でログを読む | [4.3 アプリ内アナライザー](#43-アプリ内アナライザーmxlogger_analyzer_lib) |
| Dart で自前のビューアやアップロード経路を作る | [4.4 Dart で解析する](#44-dart-で解析する) |

## 4.1 ファイルの場所

- **ディレクトリ**: `logger.diskcachePath`、すなわち `directory/nameSpace`。既定ディレクトリの場合、iOS は `<Library>/com.mxlog.LoggerCache/<nameSpace>`、Android は `<filesDir>/com.mxlog.LoggerCache/<nameSpace>`（`/data/data/<package>/files/...`）です。
- **ファイル名**はストレージポリシー（2.2）に従います。例: `2023-01-11_mxlog.mx`。隣にある `error.txt`（2.7）はプレーンテキストで、パーサーは不要です。
- **Dart からの一覧取得**: `logger.logFiles` は `MXFileEntity(name, size)` を返します。フルパスは `"${logger.diskcachePath}/${file.name}"` です。

ファイルを PC に取り出す方法:

- **iOS 実機**: Xcode > Window > Devices and Simulators > 端末とアプリを選択 > ⚙︎ > *Download Container…*。`.xcappdata` を右クリック > *パッケージの内容を表示* > `AppData/Library/com.mxlog.LoggerCache/<nameSpace>/`。
- **iOS シミュレータ**:

  ```bash
  open "$(xcrun simctl get_app_container booted <bundle id> data)/Library/com.mxlog.LoggerCache/<nameSpace>"
  ```

- **Android**（debuggable ビルド。ディレクトリはアプリ専用領域）:

  ```bash
  adb shell run-as <package> ls files/com.mxlog.LoggerCache/<nameSpace>
  adb exec-out run-as <package> cat files/com.mxlog.LoggerCache/<nameSpace>/2023-01-11_mxlog.mx > 2023-01-11_mxlog.mx
  ```

- **リリースビルド / 実ユーザー**: アプリ自身がファイルを外に出す必要があります。例えば `share_plus` で共有したり、`logFiles` のパスを使って自社サーバーにアップロードします。ロガーが開いたままでもファイルはコピーできます。後述のアプリ内アナライザーも同じ方法でライブなディレクトリを読んでいます。

## 4.2 デスクトップアナライザー（macOS / Windows / Linux）

[Releases](https://github.com/coder-dongjiayi/MXLogger/releases) から自分の OS 向けの `mxlogger_analyzer` をダウンロードします。初回起動は 3 ステップのウィザードです。

1. **ファイルを選ぶ**: 1 つ以上の `.mx` ファイルをウィンドウにドラッグするか、クリックして選択します。
2. **復号**: ロガー作成時に使った `cryptKey` / `iv` を入力します。暗号化していないログは両方空欄のままにします。鍵をローテーションした場合はすべてのペアを追加してください。番号付きチェックボックスの順に、レコードが復号できるまで試行されます。値は次回のために記憶されます。
3. **インポート**: 実際の進捗バー（解析済みバイト数、書き込み済み行数）が表示され、その後データページが自動的に開きます。

データページのヘッダーには合計件数、期間、ファイル名が表示されます。その下にはクリックで絞り込めるレベル分布バーと DEBUG–FATAL のチップ、時間範囲フィルター付きのキーワード検索（すべて / メッセージ / タグ / 名前）、任意のカードの `@name` や `#tag` をクリックしての絞り込み、JSON メッセージのシンタックスカラー付きツリー、1 レコードの全画面詳細（Esc で閉じる）、共有ボタンからの `.txt` エクスポートがあります。ファイル変更、鍵変更、データ消去はヘッダーメニューにあります。

解析に失敗するとウィザードはステップ 2 に戻ります。ほとんどの場合 `cryptKey` / `iv` の誤りです。v2.0.0 より前に 16 バイト未満の鍵で書かれたログは復号できない可能性があります（2.1 の注記を参照）。

スクリーンショットと機能一覧はリポジトリの [README](https://github.com/coder-dongjiayi/MXLogger#log-analyzer) にあります。

## 4.3 アプリ内アナライザー（`mxlogger_analyzer_lib`）

アナライザーのコアは Flutter パッケージとしても提供されています。アプリの `Overlay` にドラッグ可能なフローティングボールを載せ、タップするとボトムシートが開いて `diskcachePath` をオンデマンドで解析するため、テスターは PC なしで端末上のログを読めます。

```yaml
dependencies:
  mxlogger_analyzer_lib: ^2.0.0
```

```dart
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';

final navigatorKey = GlobalKey<NavigatorState>();
// MaterialApp(navigatorKey: navigatorKey, ...)

await MXAnalyzer.showDebug(
  navigatorKey.currentState!.overlay!,
  diskcachePath: logger.diskcachePath,
  // すべての復号ペア。順番に試行される。暗号化なしのログは [] を渡す
  cryptPairs: [
    MxCryptPair(key: logger.cryptKey ?? "", iv: logger.iv ?? ""),
    // MxCryptPair(key: "legacy-key", iv: "legacy-iv"),
  ],
  // 共有はホスト側で実装する（share_plus、自前のアップローダーなど）。
  // false を返すとクリップボードへのコピーにフォールバックする
  onShare: (MXShareRequest request) async => false,
);

MXAnalyzer.dismiss(); // ボールを取り除き、データベースを解放する
```

これはデバッグツールです。エンドユーザーに出荷するのではなく、debug フラグの背後で有効化してください。完全な API とモバイルレイアウトの説明: [mxlogger_analyzer_lib README](https://github.com/coder-dongjiayi/MXLogger/blob/main/mxlogger_analyzer/mxlogger_analyzer_lib/README.md)。

## 4.4 Dart で解析する

`MXLogger.selectLogmsg`（2.8）は 1 つのファイルを、アナライザーが表示するのと同じフィールドを持つ `List<Map<String, dynamic>>` にデコードします。自前の UI を作りたいとき、あるいはアップロード前にログを JSON / テキストに変換したいときに使います。同期 FFI なので isolate で実行してください。example の `log_viewer_page.dart` が完全なリファレンスです。

# Example

`example/` は本ドキュメントのすべての API を網羅した完全なデモアプリです: 初期化、5 つのレベルすべて、モジュール化アプリ向けの loggerToken ベースの書き込み、ストレージポリシー、ファイル一覧、ログビューアと解析、破棄。

```bash
cd example && flutter run
```

# License

BSD 3-Clause。[LICENSE](LICENSE) を参照してください。
