# MXLogger Windows C++ SDK

[English](./README.md) | [简体中文](./README_CN.md) | 日本語 | [한국어](./README_KO.md)

**Windows 10/11 x64** 向けのネイティブ **C++17** SDK です。Core バージョンは **2.3.0** です。
NuGet パッケージ ID は `MXLogger.Native`、vcpkg port は `mxlogger` です。
どちらも同じ Core を使います。NuGet には Flutter/Dart 用の C ABI DLL も含まれますが、.NET ラッパーではありません。

## アプリ固有の名前空間を指定する

**`com.company.product` のような、アプリ固有の固定された逆ドメイン形式の名前空間を使用してください。**
この例を自分のドメインと製品名に置き換え、異なるアプリには異なる名前空間を指定します。
これはネイティブ C++ の `ns` 引数と Flutter の `nameSpace` 引数であり、Bundle ID や Windows のパッケージ ID を自動取得するものではありません。

Flutter Windows の既定ログパスは
`%LOCALAPPDATA%/MXLogger/<拡張子を除いた EXE 名>/<nameSpace>/` です。
**EXE 名だけでは一意性を保証できません。** 同じ Windows ユーザーのアプリで EXE 名と名前空間が同じ場合、同じディレクトリを使用します。
ネイティブ C++ または Flutter で `directory` を指定すると Core は `directory/nameSpace/` を使うため、ベースディレクトリもアプリ固有に指定してください。
複数プロセスで意図的にログを共有する場合は、同じディレクトリ、名前空間、暗号化設定を使います。
EXE を改名してもパスを維持したい場合は、`directory` を明示指定してください。

## ローカル NuGet フィードからの導入

`verify-logger` を手動実行してください。全プラットフォームの API テスト成功後、
`3. Windows SDK + Flutter Release Demo` ジョブが `MXLogger.Native.2.3.0.nupkg` をビルド・検証します。
このファイルをローカルフィードとして利用します。nuget.org への自動公開は行いません。

1. nupkg を `D:\NuGetFeed` などのフォルダーに保存します。展開は不要です。
2. Visual Studio の **Tools → NuGet Package Manager → Package Manager Settings → Package Sources** にそのフォルダーを追加します。
3. C++ プロジェクトで x64 を選び、そのソースから `MXLogger.Native` 2.3.0 をインストールします。

Package Manager Console からも実行できます。

```powershell
Install-Package MXLogger.Native -Version 2.3.0 -Source D:\NuGetFeed
```

NuGet がネイティブ `.targets`、公開ヘッダーの検索パス、対応する静的ライブラリを自動設定します。
ネイティブ C++ の静的リンクでは `.lib` の手動コピーや MXLogger DLL の配布は不要です。

```cpp
#include <mxlogger.hpp>
#include <mxlogger_util.hpp>

const char* version = mx_logger::version(); // "2.3.0"
auto* logger = mx_logger::initialize_namespace(
    "com.company.product", "C:/MyApp/Logs", "yyyy_MM_dd", "app", nullptr, nullptr, nullptr);
if (logger) {
    logger->log(1, "App", "Hello from Windows", "demo", true);
    mx_logger::destroy();
}
```

ログディレクトリはアプリから書き込める場所に変更してください。Visual Studio 2022/v143 または互換性のある新しいツールチェーンを使います。
利用側の MSVC バージョンは、パッケージをビルドしたバージョン以降である必要があります。

| プロジェクトのランタイム | Debug | Release |
|---|---|---|
| 動的 CRT（既定） | `/MDd` | `/MD` |
| 静的 CRT | `/MTd` | `/MT` |

両方の構成と CRT 系列を同じパッケージに含みます。`UseDebugLibraries` で Debug/Release を選択し、
未設定の場合は構成名 `Debug` を判定に使います。既定は MD 系列です。MT の場合は `.vcxproj` に追加します。

```xml
<PropertyGroup>
  <MXLoggerRuntimeLibrary>MT</MXLoggerRuntimeLibrary>
</PropertyGroup>
```

プロジェクトの **C/C++ → Code Generation → Runtime Library** も `/MTd` または `/MT` に設定してください。
SDK は設定を上書きせず、不一致をエラーにします。独自の構成では `MXLoggerUseDebugLibraries` を `true` / `false` に設定できます。
言語設定が未設定、`Default`、C++14 の場合は、ソースファイルごとの設定も含め C++17 に引き上げます。
C++20 以降の指定は維持します。パッケージ CI でこれらの規則と実際の利用プロジェクトを検証します。

## NuGet パッケージのローカルビルド

Windows に VS 2022 の Desktop development with C++（v143）、CMake、PowerShell 7、Python、NuGet CLI を用意し、リポジトリのルートで実行します。

```powershell
pwsh -File scripts/build_windows_nuget.ps1
```

出力は `build/windows-sdk/packages/MXLogger.Native.2.3.0.nupkg`、ローカルログは `build/windows-sdk/logs/` です。
スクリプトは MD/MT × Debug/Release の Core とインストール済み CMake SDK を検証し、FFI DLL と nupkg を生成します。
さらにローカルフィードから復元したパッケージを独立した `.vcxproj` で利用し、バージョン取得、暗号化書き込み、復号、CRT 不一致の拒否を確認します。パッケージの公開は行いません。

## Flutter 用プリビルド DLL

nupkg には `build/native/ffi/x64/{Debug,Release}/mxlogger_ffi.dll`、`manifest.json`、
`build/native/include/mxlogger_ffi.h` が含まれます。manifest は Core/ABI バージョン、アーキテクチャ、ハッシュとソースの由来を記録します。
DLL は静的 CRT を使います。DLL が確保した文字列・配列は同じ DLL の対応する解放関数で解放し、呼び出し側の `free` を使わないでください。
ネイティブ C++ の静的リンクでは、この FFI DLL を自動リンク・コピーしません。

自分の Windows マシンがなくても、Windows CI が DLL のビルドと実際の Dart FFI テストを実行します。
nupkg をダウンロードしたら macOS または Windows のリポジトリルートで実行してください。

```bash
python3 scripts/prepare_flutter_windows.py --package /path/to/MXLogger.Native.2.3.0.nupkg
python3 scripts/prepare_flutter_windows.py --check
```

出力先は `platform/flutter_mxlogger/windows/bin/x64/` です。Flutter CMake はバイナリの検証とコピーだけを行います。
両方の DLL と manifest を一緒にコミットし、pub 公開前にも含めてください。`.pubignore` はこれらを公開パッケージに残します。
Flutter Windows の利用側に NuGet や Core ソースは不要です。準備済みの `flutter_mxlogger-windows-prebuilt` CI 成果物も利用できます。
Core を変更したら新しいパッケージをビルド・取り込み直し、古い DLL を使い続けないでください。

## Flutter Windows Release デモ

全プラットフォームの API テスト成功後、CI は `MXLoggerFlutterDemo-windows-x64-Release` を生成します。
全体を展開して `MXLoggerFlutterDemo.exe` を実行します。DLL、VC++ ランタイムと `data/` を EXE の隣に保持してください。
これは `example/lib/main.dart` の対話型デモです。CI は最初の表示フレームと、別の FFI スモークテストを検証します。
テスト出力は GitHub Actions の各ステップで確認でき、ログだけの成果物はアップロードしません。

## vcpkg による導入

リポジトリ内の **overlay port** は隣接する Core ソースをビルドします。公開 vcpkg registry には登録していません。
port ディレクトリだけでなく、完全な checkout を保持してください。`vcpkg.json` のないディレクトリから classic モードで実行します。

```powershell
vcpkg install mxlogger:x64-windows --overlay-ports=D:/src/MXLogger/platform/Windows/vcpkg/ports --no-binarycaching
```

静的 CRT の場合は `mxlogger:x64-windows-static` を使います。両 triplet は静的 MXLogger ライブラリを生成し、CRT はそれぞれ MD / MT 系列です。
manifest モードでは `vcpkg.json` に依存関係を追加します。

```json
{ "dependencies": ["mxlogger"] }
```

`vcpkg-configuration.json` に overlay のパスを指定します。

```json
{ "overlay-ports": ["../MXLogger/platform/Windows/vcpkg/ports"] }
```

CMake では同じ公開 target を使います。

```cmake
find_package(MXLoggerCore 2.3 CONFIG REQUIRED)
target_link_libraries(MyApp PRIVATE MXLogger::Core)
```

vcpkg toolchain とプロジェクトの CRT に合う triplet を指定してください。MT では CMake 3.20 以降を使い、
`CMAKE_MSVC_RUNTIME_LIBRARY` を `MultiThreaded$<$<CONFIG:Debug>:Debug>` に明示設定します。
同じバージョンのローカル変更を検証する場合、バイナリキャッシュを無効にし、既存の mxlogger を削除して再インストールしてください。
CI は独立したインストール先と無効化したキャッシュで両 triplet を検証します。

```powershell
pwsh -File scripts/verify_windows_vcpkg.ps1 -VcpkgRoot C:/vcpkg
```

## 単独の CMake SDK とバージョン管理

パッケージマネージャーを使わずに Core をインストールすることもできます。

```powershell
cmake -S Core -B build/core-sdk -A x64 -DMXLOGGER_INSTALL=ON
cmake --build build/core-sdk --config Debug --parallel
cmake --install build/core-sdk --config Debug --prefix D:/MXLoggerSDK
cmake --build build/core-sdk --config Release --parallel
cmake --install build/core-sdk --config Release --prefix D:/MXLoggerSDK
```

利用側で `CMAKE_PREFIX_PATH=D:/MXLoggerSDK` を指定し、`find_package(MXLoggerCore CONFIG REQUIRED)` を呼びます。
Debug は `MXLoggerCored.lib`、Release は `MXLoggerCore.lib` を使い、CMake が選択します。ソースを直接組み込む方式も利用できます。

`Core/mxlogger_version.hpp` が Core API、CMake、NuGet のバージョン情報源です。
更新時は overlay の `vcpkg.json` も変更してください。不一致の場合 port はビルドを拒否します。
将来 nuget.org へ公開する場合は、実際の Windows CI とパッケージ ID の所有権を確認後、自分の API Key で実行します。

```powershell
nuget push build/windows-sdk/packages/MXLogger.Native.2.3.0.nupkg -Source https://api.nuget.org/v3/index.json -ApiKey $env:NUGET_API_KEY
```

[NuGet のネイティブパッケージ](https://learn.microsoft.com/en-us/nuget/guides/native-packages) と
[vcpkg overlay](https://learn.microsoft.com/en-us/vcpkg/concepts/overlay-ports) の説明も参照してください。
