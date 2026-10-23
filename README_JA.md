<p align="center">
  <img src="https://img.shields.io/badge/iOS-9.0+-000000?style=for-the-badge&logo=apple&logoColor=white" alt="iOS" />
  <img src="https://img.shields.io/badge/macOS-10.13+-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS" />
  <img src="https://img.shields.io/badge/Android-minSdk%2021-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android" />
  <img src="https://img.shields.io/badge/Flutter-3.7+-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Analyzer-macOS%20%7C%20Windows%20%7C%20Linux-6C5CE7?style=for-the-badge&logo=flutter&logoColor=white" alt="Analyzer desktop" />
  <a href="https://chromewebstore.google.com/detail/mxlogger-analyzer/bpjhmakllccpeiglbfngmdbelimlghfi"><img src="https://img.shields.io/badge/Chrome-Install%20extension-4285F4?style=for-the-badge&logo=googlechrome&logoColor=white" alt="Install MXLogger Analyzer from the Chrome Web Store" /></a>
  <a href="https://pub.dev/packages/mxlogger_analyzer_lib"><img src="https://img.shields.io/pub/v/mxlogger_analyzer_lib?style=for-the-badge&label=analyzer%20lib&logo=dart" alt="pub analyzer" /></a>
</p>

<p align="center">
  <a href="https://github.com/coder-dongjiayi/MXLogger/blob/main/LICENSE.TXT"><img src="https://img.shields.io/badge/license-BSD--3-brightgreen.svg?style=flat-square" alt="license" /></a>
  <a href="https://cocoapods.org/pods/MXLogger"><img src="https://img.shields.io/cocoapods/v/MXLogger?style=flat-square&label=pod" alt="CocoaPods" /></a>
  <a href="https://central.sonatype.com/artifact/io.github.coder-dongjiayi/mxlogger"><img src="https://img.shields.io/maven-central/v/io.github.coder-dongjiayi/mxlogger?style=flat-square&label=maven%20central" alt="Maven Central" /></a>
  <a href="https://pub.dev/packages/flutter_mxlogger"><img src="https://img.shields.io/pub/v/flutter_mxlogger?style=flat-square&label=pub&logo=dart" alt="pub" /></a>
</p>

[English](./README.md) | [简体中文](./README_CN.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md)

MXLogger は **mmap** によるメモリマッピングを利用するクロスプラットフォームのログライブラリです。**AES-CFB-128** 暗号化に対応し、iOS、macOS、Android、Flutter で利用できます。コアは C/C++ で実装され、Google **FlatBuffers** でシリアライズします。Flutter からは `dart:ffi` で直接呼び出すため、ネイティブに近い性能を得られます。iPhone 11 では、約 134 バイトのログ 10 万件を約 **0.13 秒**で書き込めます。

付属の **mxlogger_analyzer** は、生成された `.mx` バイナリログの読み込み、復号、検索を行うツールです。Chrome 拡張機能、デスクトップアプリ（macOS / Windows / Linux）、iOS / Android の Flutter アプリに組み込むフローティングボタンとして利用できます。

- [ログ解析ツール](#log-analyzer)
- [インストール](#install)
- [クイックスタート](#quick-start)
- [API リファレンス](#api-reference)
  - [iOS / macOS](#ios-api) · [Android](#android-api) · [Flutter](#flutter-api) · [解析ツール](#analyzer-api)
- [保存ポリシーとログレベル](#storage-policy-and-levels)
- [性能](#performance)
- [注意事項](#notes)

## 構成

<img src="./icon/jiegoutu.webp" alt="構成図" width="640" />

MXLogger はログの**書き込み**と**解析**を提供します。ログをいつアップロードするかはアプリ側で決めます。公開されているログディレクトリ（`diskCachePath`）から自分のサーバーへファイルを送信し、ダウンロード後に mxlogger_analyzer で解析できます。

---

<a id="log-analyzer"></a>

# ログ解析ツール

`.mx` は AES-CFB-128 と FlatBuffers によるバイナリ形式のため、専用のリーダーが必要です。解析ツールはデータを SQLite に取り込み、全文検索、レベル・時刻・Tag・Name による絞り込み、JSON ツリー表示を提供します。

| 形式 | 概要 | 入手方法 |
| --- | --- | --- |
| Chrome 拡張機能 | Chrome で `.mx` ファイルを解析 | [Chrome ウェブストアからインストール](https://chromewebstore.google.com/detail/mxlogger-analyzer/bpjhmakllccpeiglbfngmdbelimlghfi) |
| デスクトップアプリ | macOS / Windows / Linux 向け。ファイルを選択またはドロップして解析 | [Releases](https://github.com/coder-dongjiayi/MXLogger/releases)（CI で 3 プラットフォームの配布物を生成） |
| アプリへの組み込み | iOS / Android の Flutter アプリ内にフローティングボタンとボトムシートを表示 | pub.dev の `mxlogger_analyzer_lib` |

Chrome でストアのリンクを開き、**Chrome に追加** → **拡張機能を追加**を選びます。拡張機能メニューから **MXLogger Analyzer** を開き、`.mx` ファイルを選択またはドロップしてください。暗号化されている場合は KEY / IV を設定して取り込みます。

**データ画面**：レベル分布バー、レベル別の絞り込み、検索、時刻フィルターを備えています。各ログカードには構文を色分けした JSON ツリーがあり、`@name` / `#tag` をクリックして絞り込めます。レコードごとに詳細表示、共有、全画面表示、コピーが可能です。右上の切り替えでライトテーマに変更できます。

<img src="./mxlogger_analyzer/mxlogger_analyzer_lib/screenshots/desktop_dark.png" alt="解析結果画面" width="900" />

**初回起動時の 3 ステップ**：① `.mx` ファイルを選択またはドロップ → ② 復号用 KEY / IV を設定（複数の組を登録でき、チェックボックスの番号順に試行）→ ③ 進捗を確認しながら取り込みます。

<img src="./mxlogger_analyzer/mxlogger_analyzer_lib/screenshots/desktop_wizard.png" alt="初回セットアップ" width="900" />

**レコードの全画面表示**（Esc で閉じる）：Name、Tags、時刻、レベル、完全な JSON ツリーを確認し、内容全体を共有またはコピーできます。

<img src="./mxlogger_analyzer/mxlogger_analyzer_lib/screenshots/desktop_detail.png" alt="ログの全画面詳細" width="900" />

**ホストアプリへの組み込み**（スマートフォン）：画面の 85% を覆うボトムシートを表示します。余白を抑え、操作をアイコン化し、レベル選択を横スクロールにしています。カードは初期状態では折りたたまれ、操作は「⋯」メニューにまとめられます。

<p align="center">
<img src="./mxlogger_analyzer/mxlogger_analyzer_lib/screenshots/mobile_embed.png" alt="組み込みボトムシート" width="340" />
</p>

解析ツールの詳細：[mxlogger_analyzer_lib/README.md](./mxlogger_analyzer/mxlogger_analyzer_lib/README.md)。

---

<a id="install"></a>

# インストール

## iOS

```ruby
pod 'MXLogger', '~> 2.2.0'
```

## ネイティブ macOS

ソースの podspec は macOS 10.13 以降に対応しています。このバージョンの公開前はローカルのチェックアウトを指定します。

```ruby
platform :osx, '10.13'
pod 'MXLogger', :path => '/path/to/MXLogger'
pod 'MXLoggerCore', :path => '/path/to/MXLogger'
```

SwiftPM では [mxlogger-spm](https://github.com/coder-dongjiayi/mxlogger-spm.git) を使用します。`spm/Package.swift` の対象は iOS 12 以降、macOS 10.13 以降です。両者は同じネイティブ API を使います。macOS では `removeExpireData` を明示的に呼び出してください。`shouldRemoveExpiredDataWhenEnterBackground` は動作しません。Flutter macOS は共有の `darwin/` プラグイン経由で同じ Dart API を提供します（Flutter 3.7 以降、macOS 10.14 以降）。

### ネイティブ macOS デモ

`macOS/MXLoggerDemo` は **AppKit + Swift + Main.storyboard** で構成されたネイティブアプリです。入口、ホーム、ファイル一覧、ログビューアー、再利用セルを Storyboard で編集できます。iOS / Android / Flutter のデモと同じ紫色のステータスカードと英語・中国語の切り替えを備え、iOS デモのロゴと言語リソースを共有しています。

```bash
pod install --project-directory=macOS/MXLoggerDemo
open macOS/MXLoggerDemo/MXLoggerDemo.xcworkspace
```

`MXLoggerDemo` スキームと `My Mac` を選んで実行します。現在のチェックアウトにあるネイティブ Pod を使うため、Flutter や公開済みの 2.2.0 は不要です。既定値は他のデモと同じく、`com.djy.mxlogger`、時間単位のファイル分割、AES-CFB-128、保存期間 7 日、上限 10 MB です。

5 段階のログ、ネットワーク JSON、汎用・Token 経由の書き込み、設定、10 万件の性能測定、スレッド・プロセス間の並行書き込みと件数・順序の検証、手動クリーンアップ、インスタンスの再生成、レベル・検索フィルター付きのログビューアーを備えています。macOS のクリーンアップは手動です。Release ではコンソール出力のスイッチを無効にします。`pod install` は現在の Xcode SDK に合わせたローカルの `Configurations/SDK.xcconfig` を生成します。

```bash
bash scripts/verify_macos_demo.sh
```

Debug / Release をビルドし、複数プロセスの暗号化読み書き、Token、クリーンアップ、再オープンを検証します。Debug では Storyboard を読み込み、outlet、画面遷移、言語切り替え、フィルターも確認し、アプリ自身のビューを画像に出力します。ログとプレビューは `build/macos-native-demo/` に保存されます。

### Flutter macOS デモ

`flutter_mxlogger/example` はモバイル版と入口画面、紫色のステータスカード、機能のグループ分け、英語・中国語の切り替え、ファイル一覧、暗号化ログビューアーを共有します。macOS 向けにサイズ変更可能なウィンドウ、設定ダイアログ、独立した Finder 項目、手動クリーンアップの説明を追加しています。書き込み、10 万件の性能測定、isolate の並行処理、クリーンアップ、絞り込みを試せます。isolate は同じプロセスに属します。複数プロセスのデモには上記のネイティブ版を使ってください。

リポジトリのルートで実行します。ネイティブ 2.2.0 の事前公開は不要です。

```bash
bash scripts/run_flutter_macos_demo.sh
# Set FLUTTER_BIN=/path/to/flutter/bin/flutter if Flutter is not on PATH.
bash scripts/run_flutter_macos_demo.sh build --release
bash scripts/run_flutter_macos_demo.sh test
```

スクリプトはコマンドの実行中だけローカル CocoaPods を有効にし、デモのビルド対象をインストール済み Xcode SDK に合わせます。UI 検証は一時的なログを使用し、プレビューを `flutter_mxlogger/example/screenshots/macos-*.png` に保存します。[Flutter デモの説明](flutter_mxlogger/example/README.md)も参照してください。

### macOS の回帰検証とリリース準備

Xcode（iOS SDK を含む）、CocoaPods、Python 3、Flutter 3.44 以降を導入した Mac で実行します。

```bash
python3 scripts/verify_macos_support.py
# If Flutter is not on PATH:
python3 scripts/verify_macos_support.py --flutter /path/to/flutter/bin/flutter
```

Core のテスト（実際の複数プロセス、クリーンアップ、プロセス終了後の復旧を含む）、Objective-C / Swift API、ネイティブ macOS デモ、Flutter 単体テスト、iOS 実機・シミュレーター向けブリッジのコンパイル、Flutter デスクトップデモの UI フローを確認します。さらに CocoaPods と SwiftPM の両方で macOS Debug 統合テストと Release の暗号化読み書きを行い、シンボル除去後のブリッジ公開シンボルも検査します。

テスト用プロジェクトは `build/macos-validation/run-*/` に生成され、ローカルのネイティブソースを使用します。配布用マニフェスト、デモのロックファイル、Flutter のグローバル設定は変更しません。検証プロジェクトの配備対象は現在の Xcode SDK の最小対応バージョンに合わせますが、ライブラリの macOS 10.13、Flutter プラグインの macOS 10.14 という宣言は維持します。旧 OS での実行互換性を確認する検証ではありません。

`--package-manager pods` / `--package-manager spm` で接続方式を選べます。`--skip-native` は Core とネイティブ Apple のテストを省略し、`--offline` は Dart のキャッシュを利用します（エンジンと CocoaPods メタデータは事前に必要）。結果は各実行ディレクトリの `logs/` に保存されます。この検証スクリプトには Flutter 3.44 以降が必要ですが、プラグインの最低要件は Flutter 3.7 のままです。成功した Flutter テストプロジェクトは容量確保のため削除し、ログを残します。`--keep-builds` でビルド内容を保持できます。失敗時は原因調査のため常に保持します。

Android の検証には NDK、CMake、Ninja が必要です。4 種類の ABI をコンパイルし、macOS のプロセスロックが誤って混入していないことを確認します。

```bash
ANDROID_NDK_HOME=/path/to/android-sdk/ndk/27.0.12077973 bash scripts/verify_android_native.sh
```

`.github/workflows/verify-logger.yml` は関連する PR と手動実行で検証し、ログを 7 日間保存します。Android 実機での動作は別途検証が必要です。

2.2.0 の公開時は `mxlogger-spm` ミラーを同期し、メインとミラーの `v2.2.0` タグを利用可能にします。その後 `MXLoggerCore`、`MXLogger`、Android 2.2.0、最後に Flutter パッケージを公開します。Flutter 公開前に `scripts/pub_flutter_mxlogger.sh --dry-run` を実行し、ネイティブ依存関係の公開後にリモートからの解決を検証してください。

## Android

```groovy
implementation 'io.github.coder-dongjiayi:mxlogger:2.2.0'
```

## Flutter

```yaml
dependencies:
  flutter_mxlogger: ^2.2.0
  mxlogger_analyzer_lib: ^2.0.0   # optional: the in-app log viewer
```

ネイティブ依存関係は自動で取得されます。CocoaPods は `MXLogger` → `MXLoggerCore`、Gradle は `io.github.coder-dongjiayi:mxlogger` に依存します。

---

<a id="quick-start"></a>

# クイックスタート

## iOS

```objective-c
MXLogger *logger = [MXLogger initializeWithNamespace:@"com.yourdomain.logger"
                                      storagePolicy:MXStoragePolicyYYYYMMDD
                                           fileName:@"mxlog"
                                         fileHeader:@"{\"app_version\":\"2.0.0\"}"
                                           cryptKey:@"abcuioqbsdguijlk"   // 16 bytes
                                                 iv:@"bccuioqbsdguijiv"];

logger.consoleEnable = YES;                 // debug only — set NO for benchmarks / release
logger.maxDiskAge   = 60 * 60 * 24 * 7;     // keep at most 7 days
logger.maxDiskSize  = 1024 * 1024 * 10;     // use at most 10 MB
logger.level        = 0;                    // 0:debug — write everything to file

[logger debugWithName:@"login" msg:@"token check started" tag:@"login,service"];
[logger infoWithName:@"network" msg:responseJSON tag:@"network,POST,200"];
[logger warnWithName:@"network" msg:@"retry #2" tag:@"network"];
[logger errorWithName:@"flutter" msg:stack tag:@"crash"];
[logger fatalWithName:@"database" msg:@"connection lost" tag:@"db,fatal"];

NSLog(@"logs live in %@", logger.diskCachePath);
```

## Android

```java
MXLogger logger = MXLogger.initialize(
        context,
        "com.yourdomain.logger",              // nameSpace
        null,                                 // diskCacheDirectory — null = default
        MXStoragePolicyType.YYYY_MM_DD,
        "mxlog",                              // fileName
        "{\"app_version\":\"2.0.0\"}",        // fileHeader
        "abcuioqbsdguijlk",                   // cryptKey, 16 bytes
        "bccuioqbsdguijiv");                  // iv

logger.setConsoleEnable(true);
logger.setMaxDiskAge(60 * 60 * 24 * 7);
logger.setMaxDiskSize(1024 * 1024 * 10);
logger.setLevel(0);

// Android takes tag first: debug(tag, name, msg)
logger.debug("login,service", "login", "token check started");
logger.info("network,POST,200", "network", responseJson);
logger.warn("network", "network", "retry #2");
logger.error("crash", "flutter", stack);
logger.fatal("db,fatal", "database", "connection lost");

Log.d("MXLogger", "logs live in " + logger.getDiskCachePath());
```

## Flutter

```dart
final MXLogger logger = await MXLogger.initialize(
  nameSpace: "flutter.mxlogger",
  storagePolicy: MXStoragePolicyType.yyyyMMdd,
  fileHeader: jsonEncode(deviceInfo),
  consoleEnable: true,
  cryptKey: "abcuioqbsdguijlk",   // 16 bytes
  iv: "bccuioqbsdguijiv",         // defaults to cryptKey when omitted
);

logger.setMaxDiskAge(60 * 60 * 24 * 7);
logger.setMaxDiskSize(1024 * 1024 * 10);
logger.setLevel(0);

logger.debug("token check started", name: "login", tag: "login,service");
logger.info(jsonEncode(response), name: "network", tag: "network,POST,200");
logger.warn("retry #2", name: "network", tag: "network");
logger.error(stack, name: "flutter", tag: "crash");
logger.fatal("connection lost", name: "database", tag: "db,fatal");

debugPrint("logs live in ${logger.diskcachePath}");
```

---

<a id="api-reference"></a>

# API リファレンス

各プラットフォーム共通で、ロガーは **nameSpace + diskCacheDirectory** によって識別され、同じ組み合わせには同じ C++ インスタンスが使われます。その組み合わせの MD5 が **loggerToken** です。モジュール間でこの値を渡せば、ロガーオブジェクトを保持せずにクラスメソッドで書き込めます。

ネイティブ macOS Core は、同じディレクトリを共有するプロセス間でアクセスを調整します。追記前にディレクトリ単位のファイルロックを取得し、確定済みの長さ、ファイル識別情報、マッピング容量を更新します。読み込みは共有ロック下で確定済みスナップショットをコピーし、解除後に復号・解析します。参加するすべてのプロセスで同じ方式、暗号化設定、アクセス可能な共有ディレクトリを使ってください。異なるディレクトリ間では待ち合わせません。iOS / Android のファイルアクセス方式は従来どおりで、Windows の複数プロセス向け実装はまだありません。

macOS の調整用ファイル `.mxlogger.lock` は、ログ一覧、容量計算、クリーンアップの対象外です。ロガーが動作している間は手動で削除しないでください。期間・容量による削除と `removeBeforeAllData` は、他のプロセスが使用中のファイルを保持します。`removeAllData` は全ログを削除し、動作中のロガーは次回書き込み前にファイルを開き直します。`.mx` 形式は変更しておらず、CRC や電源断に対する耐久性保証を追加するものではありません。macOS では、ロック失敗または確定長が 32 ビット上限に達した場合に `-4` を返します。詳細は `errorDesc` で確認してください。

> **非推奨 API について。** `loggerToken` の旧称は `loggerKey` で、暗号化用の `cryptKey` と混同しやすい名前でした。iOS / Android / Flutter の各 `loggerKey` API は現在も対応する `loggerToken` API に転送されますが、非推奨であり、**将来のリリースで削除されます**。`loggerKey` → `loggerToken`、`xxxWithLoggerKey:` → `xxxWithLoggerToken:`、`getLoggerKey()` → `getLoggerToken()`、`logLoggerKey` → `logLoggerToken`、`destroyWithLoggerKey` → `destroyWithLoggerToken` に移行してください。

<a name="ios-api"></a>

## iOS / macOS — `MXLogger`（Objective-C）

### 生成と解放

| API | 説明 |
| --- | --- |
| `+ initializeWithNamespace:` | iOS の既定値：`Library/com.mxlog.LoggerCache`。macOS：`Application Support/<bundle-id>/MXLogger` |
| `+ initializeWithNamespace:fileHeader:` | ファイルヘッダーを指定 |
| `+ initializeWithNamespace:cryptKey:iv:fileHeader:` | 暗号化を有効化 |
| `+ initializeWithNamespace:storagePolicy:fileName:fileHeader:` | 保存ポリシーとファイル名を指定 |
| `+ initializeWithNamespace:storagePolicy:fileName:fileHeader:cryptKey:iv:` | 保存ポリシーと暗号化を指定 |
| `+ initializeWithNamespace:diskCacheDirectory:storagePolicy:fileName:fileHeader:cryptKey:iv:` | すべての引数を指定 |
| `- initWithNamespace:fileHeader:` | 同じ組み合わせのインスタンス初期化メソッド |
| `- initWithNamespace:diskCacheDirectory:fileHeader:` | |
| `- initWithNamespace:cryptKey:iv:fileHeader:` | |
| `- initWithNamespace:storagePolicy:fileName:fileHeader:` | |
| `- initWithNamespace:diskCacheDirectory:storagePolicy:fileName:fileHeader:cryptKey:iv:` | 指定イニシャライザー |
| `+ destroyWithNamespace:` | nameSpace を指定して解放（既定ディレクトリ） |
| `+ destroyWithNamespace:diskCacheDirectory:` | nameSpace とディレクトリを指定して解放 |
| `+ destroyWithLoggerToken:` | loggerToken を指定して解放 |
| `+ valueForLoggerToken:` | 既存のロガーを取得。存在しない場合は `nil` |
| `+ destroyWithLoggerKey:` / `+ valueForLoggerKey:` | **非推奨**。上記の `LoggerToken` 版に転送。将来のリリースで削除予定 |

### プロパティ

| プロパティ | 型 | 説明 |
| --- | --- | --- |
| `enable` | `BOOL` | ログ書き込みの全体スイッチ |
| `consoleEnable` | `BOOL` | コンソール出力。既定は無効。Release / Profile ではコンパイル時に除去（保持するには `MXLOGGER_CONSOLE_ENABLED=1` を定義） |
| `level` | `NSInteger` | ディスクに書き込む最小レベル。0 debug ～ 4 fatal |
| `maxDiskAge` | `NSUInteger` | 最大保存期間（秒）。0 は無制限 |
| `maxDiskSize` | `NSUInteger` | 最大合計サイズ（バイト）。0 は無制限 |
| `shouldRemoveExpiredDataWhenEnterBackground` | `BOOL` | iOS のバックグラウンド移行時に削除。既定は `YES`。macOS では無効 |
| `diskCachePath` | `NSString`（読み取り専用） | ログディレクトリ |
| `logSize` | `NSUInteger`（読み取り専用） | ディスク上のログサイズ（バイト） |
| `loggerToken` | `NSString`（読み取り専用） | nameSpace とディレクトリの MD5 |
| `loggerKey` | `NSString`（読み取り専用） | **非推奨**。`loggerToken` と同じ値。将来のリリースで削除予定 |

### 書き込み

| API | 説明 |
| --- | --- |
| `- logWithLevel:name:msg:tag:` | 成功は 0。失敗は -1（拡張）、-2（マッピング解除）、-3（mmap） |
| `- debugWithName:msg:tag:` | レベル 0 |
| `- infoWithName:msg:tag:` | レベル 1 |
| `- warnWithName:msg:tag:` | レベル 2 |
| `- errorWithName:msg:tag:` | レベル 3 |
| `- fatalWithName:msg:tag:` | レベル 4 |
| `+ debugWithLoggerToken:name:msg:tag:` | loggerToken 経由の書き込み。ロガーオブジェクトは不要 |
| `+ infoWithLoggerToken:name:msg:tag:` | |
| `+ warnWithLoggerToken:name:msg:tag:` | |
| `+ errorWithLoggerToken:name:msg:tag:` | |
| `+ fatalWithLoggerToken:name:msg:tag:` | |
| `+ xxxWithLoggerKey:name:msg:tag:` | **非推奨**。`xxxWithLoggerToken:` に転送。将来のリリースで削除予定 |

### ファイル、クリーンアップ、解析

| API | 説明 |
| --- | --- |
| `- logFiles` | 辞書の配列：`name` / `size` / `last_timestamp` / `create_timestamp` |
| `- errorDesc` | 直近の書き込みエラーの説明 |
| `- removeExpireData` | 期限切れファイルを削除し、`maxDiskSize` を超える場合は古いものから削除 |
| `- removeAllData` | すべてのログファイルを削除 |
| `- removeBeforeAllData` | 書き込み中のファイル以外をすべて削除 |
| `+ selectWithDiskCacheFilePath:cryptKey:iv:` | ファイルを解析して新しい順に返す：`name` / `msg` / `tag` / `level` / `timestamp` / `thread_id` / `is_main_thread` / `error_code` |

### `MXStoragePolicyType` (iOS / Objective-C)

`MXStoragePolicyYYYYMMDD`（日単位、既定）· `MXStoragePolicyYYYYMMDDHH`（時間単位）· `MXStoragePolicyYYYYWW`（週単位）· `MXStoragePolicyYYYYMM`（月単位）

<a name="android-api"></a>

## Android — `com.dongjiayi.mxlogger.MXLogger` (Java)

### 生成と解放

| API | 説明 |
| --- | --- |
| `MXLogger(Context, String nameSpace, String diskCacheDirectory, MXStoragePolicyType, String fileName, String fileHeader, String cryptKey, String iv)` | すべての引数を受け取るコンストラクター |
| `MXLogger(Context, String nameSpace, String fileHeader)` | 既定ディレクトリ |
| `MXLogger(Context, String nameSpace, String fileHeader, String cryptKey, String iv)` | 暗号化を有効化 |
| `MXLogger(Context, String fileHeader, String nameSpace, String diskCacheDirectory)` | ディレクトリを指定 |
| `static MXLogger initialize(Context, nameSpace, diskCacheDirectory, storagePolicy, fileName, fileHeader, cryptKey, iv)` | すべての引数を指定 |
| `static MXLogger initialize(Context, nameSpace, fileHeader)` | |
| `static MXLogger initialize(Context, nameSpace, fileHeader, cryptKey, iv)` | |
| `static void destroy(Context, String nameSpace, String diskCacheDirectory)` | nameSpace とディレクトリを指定して解放 |
| `static void destroy(String loggerToken)` | loggerToken を指定して解放 |

### 設定と状態

設定値は Java 側ではキャッシュしません。各 getter は常にネイティブの現在値を参照します。複数の Java ラッパーが 1 つのネイティブインスタンスを共有していても、同じ状態を取得できます。

| API | 説明 |
| --- | --- |
| `void setEnable(boolean)` / `boolean isEnable()` | ログ書き込みの全体スイッチ |
| `void setConsoleEnable(boolean)` / `boolean isConsoleEnable()` | コンソール出力 |
| `void setLevel(int)` / `int getLevel()` | ディスクに書き込む最小レベル。0 debug ～ 4 fatal |
| `void setMaxDiskAge(long)` / `long getMaxDiskAge()` | 最大保存期間（秒）。0 は無制限 |
| `void setMaxDiskSize(long)` / `long getMaxDiskSize()` | 最大合計サイズ（バイト）。0 は無制限 |
| `long getLogSize()` | ディスク上のログサイズ（バイト） |
| `String getDiskCachePath()` | ログディレクトリ |
| `String getLoggerToken()` | nameSpace とディレクトリの MD5 |
| `String getLoggerKey()` | **非推奨**。`getLoggerToken()` と同じ値。将来のリリースで削除予定 |
| `String getErrorDesc()` | 直近の書き込みエラーの説明 |

### 書き込み

Android の引数の順番に注意してください。**tag が最初**です。

| API | 説明 |
| --- | --- |
| `int debug(String tag, String name, String msg)` | レベル 0 |
| `int info(String tag, String name, String msg)` | レベル 1 |
| `int warn(String tag, String name, String msg)` | レベル 2 |
| `int error(String tag, String name, String msg)` | レベル 3 |
| `int fatal(String tag, String name, String msg)` | レベル 4 |
| `int log(String tag, int level, String name, String msg)` | 成功は 0、失敗は -1 / -2 / -3 |
| `static int log(String loggerToken, String tag, int level, String name, String msg)` | loggerToken 経由で書き込み |

### ファイル、クリーンアップ、解析

| API | 説明 |
| --- | --- |
| `String[] logFiles()` | ファイルごとに JSON 文字列を返す：`name` / `size` / `last_timestamp` / `create_timestamp` |
| `void removeExpireData()` | 期限切れファイルを削除し、`maxDiskSize` を超える場合は古いものから削除。Android にはライフサイクルの自動フックがないため、`onStop` などで明示的に呼び出す |
| `void removeAll()` | すべてのログファイルを削除 |
| `void removeBeforeAllData()` | 書き込み中のファイル以外をすべて削除 |
| `static String[] selectWithFilePath(String diskCacheFilePath, String cryptKey, String iv)` | ファイルを解析し、レコードごとに JSON 文字列を新しい順に返す |

### `MXStoragePolicyType` (Android / Java)

`YYYY_MM_DD`（日単位、既定）· `YYYY_MM_DD_HH`（時間単位）· `YYYY_WW`（週単位）· `YYYY_MM`（月単位）

Android Java では上記の大文字の列挙値を引き続き使用します。Flutter / Dart では `yyyyMMdd`、`yyyyMMddHH`、`yyyyWw`、`yyyyMM` を使用します。[Flutter API](#flutter-api) を参照してください。

<a name="flutter-api"></a>

## Flutter — `flutter_mxlogger`

読み書きはすべて `dart:ffi` を通じて行います。MethodChannel は `initialize` でプラットフォームの既定ディレクトリを取得するときだけ使用します。

### 生成と解放

| API | 説明 |
| --- | --- |
| `static Future<MXLogger> initialize({required String nameSpace, String? directory, bool consoleEnable = false, MXStoragePolicyType storagePolicy = MXStoragePolicyType.yyyyMMdd, String? fileName, String? fileHeader, String? cryptKey, String? iv})` | 推奨。プラットフォームの既定ディレクトリを解決（iOS：`Library/com.mxlog.LoggerCache/nameSpace`、Android：`files/com.mxlog.LoggerCache/nameSpace`） |
| `MXLogger({required String nameSpace, required String directory, ...})` | 同期コンストラクター。ディレクトリの明示指定が必要 |
| `static void destroy({required String nameSpace, String? directory})` | 解放前に対応する Dart インスタンスを無効化し、解放済みメモリへのアクセスを防ぐ |
| `static void destroyWithLoggerToken(String loggerToken)` | loggerToken を指定して解放 |
| `static void destroyWithLoggerKey(String loggerKey)` | **非推奨**。`destroyWithLoggerToken` に転送。将来のリリースで削除予定 |

### getter

| getter | 型 | 説明 |
| --- | --- | --- |
| `enable` | `bool` | 書き込みが有効かどうか |
| `consoleEnable` | `bool` | コンソール出力が有効かどうか |
| `diskcachePath` | `String` | ログディレクトリ（directory + nameSpace） |
| `diskcacheErrorPath` | `String` | ローカルエラーファイル `error.txt` のパス |
| `loggerToken` | `String?` | nameSpace とディレクトリの MD5 |
| `loggerKey` | `String?` | **非推奨**。`loggerToken` と同じ値。将来のリリースで削除予定 |
| `logSize` | `int` | ディスク上のログサイズ（バイト） |
| `logFiles` | `List<MXFileEntity>` | 保存されているログファイル |
| `errorDesc` | `String?` | 直近のネイティブ書き込みエラー。なければ `null` |
| `cryptKey` / `iv` | `String?` | 初期化時に指定した暗号化パラメーター。解析ツールにも同じ値を渡す |

### スイッチとディスク管理

| API | 説明 |
| --- | --- |
| `void setEnable(bool enable)` | ログ書き込みの全体スイッチ |
| `void setConsoleEnable(bool enable)` | コンソール出力。Release / Profile では tree shaking によって除去 |
| `void setLevel(int lvl)` | ディスクに書き込む最小レベル。0 debug ～ 4 fatal |
| `void setMaxDiskAge(int age)` | 最大保存期間（秒）。0 は無制限 |
| `void setMaxDiskSize(int size)` | 最大合計サイズ（バイト）。0 は無制限 |
| `void shouldRemoveExpiredDataWhenEnterBackground(bool should)` | モバイルでバックグラウンド移行時に自動削除。既定は `true`。macOS は明示的な呼び出しが必要 |
| `void removeExpireData()` | 期限切れファイルを削除し、容量上限を超える場合は古いものから削除 |
| `void removeAll()` | すべてのログファイルを削除 |
| `void removeBeforeAllData()` | 書き込み中のファイル以外をすべて削除 |
| `int getLogSize()` / `String getDiskcachePath()` / `String? getLoggerToken()` / `List<MXFileEntity> getLogFiles()` | 上記 getter のメソッド形式 |

### 書き込み

| API | 説明 |
| --- | --- |
| `int debug(String msg, {String? name, String? tag})` | レベル 0 |
| `int info(String msg, {String? name, String? tag})` | レベル 1 |
| `int warn(String msg, {String? name, String? tag})` | レベル 2 |
| `int error(String msg, {String? name, String? tag})` | レベル 3 |
| `int fatal(String msg, {String? name, String? tag})` | レベル 4 |
| `int log(int lvl, String msg, {String? name, String? tag})` | 成功は 0。失敗は -1（拡張）、-2（マッピング解除）、-3（mmap） |
| `static void logLoggerToken(String? loggerToken, int lvl, String msg, {String? name, String? tag})` | loggerToken 経由で書き込み |
| `static void logLoggerKey(...)` | **非推奨**。`logLoggerToken` に転送。将来のリリースで削除予定 |
| `static void debugLog(String? loggerToken, String msg, {String? name, String? tag})` | `infoLog` / `warnLog` / `errorLog` / `fatalLog` も同じ形式 |

### 書き込みエラーの記録と解析

| API | 説明 |
| --- | --- |
| `void writeFail({required int code, required String errorDesc, String? other})` | `log` が 0 以外を返したときに呼び出す。`diskcacheErrorPath` に JSON 行を追記 |
| `void deleteFailFile()` | ローカルエラーファイルを削除 |
| `void closeFailFile()` | エラーファイルの書き込みストリームを閉じる |
| `static List<Map<String, dynamic>> selectLogmsg({required String diskcacheFilePath, String? cryptKey, String? iv})` | ファイルを解析して新しい順に返す：`name` / `msg` / `tag` / `level` / `timestamp` / `thread_id` / `is_main_thread` / `error_code`。`error_code == "1"` は復号失敗（cryptKey または iv が不正） |
| `static List<Map<String, dynamic>> selectLogfiles({required String directory})` | **未実装**。すべてのプラットフォームで空のリストを返す。`logFiles` を使用 |

### `MXFileEntity`

`name`（`String?`）· `size`（`int`、バイト）· `createTimeStamp` / `lastTimeStamp`（`int`、秒）· `createTime` / `lastTime`（`DateTime`、タイムスタンプから算出）

### `MXStoragePolicyType` (Flutter / Dart)

`yyyyMMdd`（日単位、既定）· `yyyyMMddHH`（時間単位）· `yyyyWw`（週単位）· `yyyyMM`（月単位）

<a name="analyzer-api"></a>

## 解析ツール — `mxlogger_analyzer_lib`

### ホストアプリへの組み込み：`MXAnalyzer`

| API | 説明 |
| --- | --- |
| `static void initialize({String? databasePath, MXPrefs? prefs})` | 任意の事前設定。SQLite の保存先（既定は `getApplicationSupportDirectory()`）と、テーマ・言語・暗号化キーの組を保存する実装を指定。省略時はメモリ内のみ |
| `static Future<void> showDebug(OverlayState overlayState, {required String diskcachePath, required List<MxCryptPair> cryptPairs, required MXShareHandler onShare, String? databasePath})` | フローティングボタンを表示。ドラッグで移動、タップでシートを開き、ダブルタップで閉じる。表示中の再呼び出しは無視 |
| `static void dismiss()` | フローティングボタンを削除し、データベースを解放 |

```dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// MaterialApp(navigatorKey: navigatorKey, ...)

await MXAnalyzer.showDebug(
  navigatorKey.currentState!.overlay!,
  diskcachePath: logger.diskcachePath,
  // Pass an empty list for plain logs; several pairs are tried in order,
  // per record — so a file whose writer rotated keys still comes out whole.
  cryptPairs: [
    MxCryptPair(key: logger.cryptKey ?? "", iv: logger.iv ?? ""),
    // MxCryptPair(key: "legacy-key", iv: "legacy-iv"),
  ],
  onShare: _shareWithSharePlus,   // return false to degrade to the clipboard
);

MXAnalyzer.dismiss();
```

シートを開くだけでは**解析しません**。ユーザーが「更新」を押すと `diskcachePath` 配下の `.mx` ファイルを走査します。更新のたびにデータベースをクリアし、最初から解析します。結果は SQLite に保存されるため、アプリを再起動しても前回のデータを表示できます。

### ホスト側の型

| 型 | 説明 |
| --- | --- |
| `MxCryptPair({required String key, String iv = ""})` | 復号キーの組。`iv` が空の場合はネイティブと同じく `key` を使用 |
| `MXShareHandler` = `Future<bool> Function(MXShareRequest)` | ホストが提供する共有処理。`false` を返すとクリップボードへのコピーに切り替える |
| `MXShareRequest` | `title` / `text` / `fileName`（null 以外ならテキストファイル共有）/ `origin`（呼び出し元の画面上の矩形。iPad / macOS のポップオーバーに必要） |
| `MXHost({required MXPrefs prefs, MXPickLogFiles? pickLogFiles, MXDropTargetBuilder? dropTargetBuilder, MXShareHandler? share})` | デスクトップ用機能の注入。未指定の機能はエラーにせず、対応する入口を非表示にする |
| `MXPrefs` / `MXMemoryPrefs` | 設定の永続化。既定はメモリ内の実装 |
| `MXStore` / `MXScope` / `MXState` / `MXAsyncState` | 独自の組み込み画面向けの、Stream を使った軽量な状態管理 |
| `MXLoggerAnalyzerApp` | 独自のデスクトップシェルに組み込める解析アプリ全体 |

---

<a id="storage-policy-and-levels"></a>

# 保存ポリシーとログレベル

**保存ポリシー**はファイルを切り替えるタイミングとファイル名を決定します。

| ポリシー | ファイル名 | |
| --- | --- | --- |
| 日単位（既定） | `2023-01-11_mxlog.mx` | 1 日につき 1 ファイル |
| 時間単位 | `2023-01-11-15_mxlog.mx` | 1 時間につき 1 ファイル |
| 週単位 | `2023-01-02w_mxlog.mx` | `02w` はその年の第 2 週 |
| 月単位 | `2023-01_mxlog.mx` | 1 か月につき 1 ファイル |

**ログレベル**は `0:debug 1:info 2:warn 3:error 4:fatal` です。レベルを *n* に設定すると、*n* 以上のログだけをファイルに保存します。例えば `level = 2` なら debug と info は除外され、warn / error / fatal を記録します。この設定が制御するのは**ディスクへの書き込み**のみです。コンソール出力が有効なら、コンソールにはすべてのレベルを出力します。

**コンソール出力**は開発用です。書き込み性能に影響するため、性能測定時は無効にしてください。Release ビルドではコンパイルまたは tree shaking によって除去されます。

**暗号化**には AES-CFB-128 を使用します。高速な書き込みのため、[MMKV](https://github.com/Tencent/MMKV/tree/master/Core/aes) のアセンブリ実装を利用しています。`cryptKey` と `iv` は 16 バイトで、長い場合は切り詰め、短い場合はゼロで埋めます。`iv` の省略時は `cryptKey` と同じ値になります。解析時に同じ組が必要なので、保存しておいてください。

**ファイルヘッダー**（`fileHeader`）はファイル作成時に 1 回だけ書き込まれます。アプリのバージョン、プラットフォーム、端末情報などの環境情報を入れる用途に適しています。解析ツールではスカラー値の一覧と JSON ツリーに展開して表示します。

---

<a id="performance"></a>

# 性能

iOS での書き込み性能測定（デモは[こちら](./性能测试demo.zip)）：

- iPhone 11、iOS 14.6、Xcode Build Configuration = Release
- 1 件あたり約 134 バイト、10 万件をループで書き込み
- 10 回実行した平均値

| | MXLogger | Xlog | Logan |
| --- | --- | --- | --- |
| 所要時間 | **~0.13s** | ~0.57s | ~14.0s |
| ファイルサイズ | 14008320 B (14M) | 905753 B (0.9M) | 922452 B (0.9M) |

<img src="./icon/haoshi.jpg" alt="性能測定結果" width="520" />

Logan と Xlog はデータを圧縮するため、ファイルサイズが小さくなります。MXLogger でも今後ログ圧縮への対応を予定しています。

---

<a id="notes"></a>

# 注意事項

- iOS の `Library/Caches` など、OS に削除される可能性のある場所をログディレクトリに**指定しないでください**。ディレクトリは起動時にだけ作成し、書き込みごとには作成しません。実行中に OS が削除すると、クラッシュや通知なしに記録されなくなる場合があります。
- **nameSpace + diskCacheDirectory** ごとにネイティブロガーは 1 つです。再初期化したラッパーも同じインスタンスを参照するため、設定変更はすべてに反映されます。
- nameSpace は逆ドメイン形式で指定し、重複を避けてください。
- モジュール化したアプリでは、サブモジュールに **loggerToken** を渡し、クラスメソッドで書き込めます。ロガーオブジェクトを渡す必要はありません。
- `maxDiskAge` / `maxDiskSize` は書き込みごとには適用されません。削除は `removeExpireData` で行います。iOS と Flutter モバイルではバックグラウンド移行時に自動実行し、ネイティブ Android と macOS では明示的な呼び出しが必要です。


<a id="license"></a>

# ライセンス

MXLogger は BSD 3-Clause ライセンスで公開されています。[LICENSE.TXT](./LICENSE.TXT) を参照してください。
