# flutter_mxlogger

[English](./README.md) | [简体中文](./README_CN.md) | [日本語](./README_JA.md) | 한국어

MXLogger는 mmap 메모리 매핑을 기반으로 하고 AES-CFB-128 암호화를 지원하는 크로스 플랫폼 로깅 라이브러리입니다. 코어는 C/C++로 작성되어 있고 레코드는 Google FlatBuffers로 직렬화됩니다. Flutter 쪽은 `dart:ffi`로 코어를 직접 호출하므로 성능은 네이티브와 거의 동일합니다.

전체 프로젝트는 [MXLogger 메인 저장소](https://github.com/coder-dongjiayi/MXLogger)를 참고하세요.

- **버전**: 2.1.0
- **요구 사항**: Dart SDK `>=2.18.0 <4.0.0`, Flutter `>=3.3.0`
- **지원 플랫폼**: iOS(>= 9.0), Android(minSdk 21)

## 목차

- [설치](#설치)
- [빠른 시작](#빠른-시작)
- [1. 아키텍처](#1-아키텍처)
- [2. Dart API](#2-dart-api)
  - [2.1 초기화](#21-초기화)
  - [2.2 저장 정책 `MXStoragePolicyType`](#22-저장-정책-mxstoragepolicytype)
  - [2.3 로그 기록](#23-로그-기록)
  - [2.4 스위치와 레벨](#24-스위치와-레벨)
  - [2.5 디스크 관리](#25-디스크-관리)
  - [2.6 상태](#26-상태)
  - [2.7 기록 실패 남기기](#27-기록-실패-남기기)
  - [2.8 로그 파일 파싱](#28-로그-파일-파싱)
  - [2.9 로거 파기](#29-로거-파기)
- [3. `loggerToken`: 모듈과 언어를 넘어 하나의 로거 공유하기](#3-loggertoken-모듈과-언어를-넘어-하나의-로거-공유하기)
  - [3.1 무엇인가](#31-무엇인가)
  - [3.2 하위 모듈에서 기록하기(Dart)](#32-하위-모듈에서-기록하기dart)
  - [3.3 네이티브 코드에서 기록하기(Android / iOS)](#33-네이티브-코드에서-기록하기android--ios)
  - [3.4 수명](#34-수명)
- [4. `.mx` 로그 파일 읽기](#4-mx-로그-파일-읽기)
  - [4.1 파일 위치](#41-파일-위치)
  - [4.2 데스크톱 분석기(macOS / Windows / Linux)](#42-데스크톱-분석기macos--windows--linux)
  - [4.3 앱 내장 분석기(`mxlogger_analyzer_lib`)](#43-앱-내장-분석기mxlogger_analyzer_lib)
  - [4.4 Dart로 파싱하기](#44-dart로-파싱하기)
- [Example](#example)
- [License](#license)

## 설치

```yaml
dependencies:
  flutter_mxlogger: ^2.1.0
```

네이티브 의존성은 자동으로 포함되므로 수동 설정이 필요하지 않습니다.

- iOS(CocoaPods, 기본): `MXLogger 2.1.0` → `MXLoggerCore 2.1.0`에 의존
- iOS(Swift Package Manager): 호스트 앱에서 Flutter의 SwiftPM 지원을 켠 경우(`flutter config --enable-swift-package-manager`) 플러그인은 `ios/flutter_mxlogger/Package.swift`로 통합되며, 대신 [MXLogger-SwiftPM](https://github.com/coder-dongjiayi/MXLogger-SwiftPM) `2.1.0`에 의존합니다
- Android: Gradle이 `io.github.coder-dongjiayi:mxlogger:2.1.0`에 의존

## 빠른 시작

```dart
import 'package:flutter_mxlogger/flutter_mxlogger.dart';

final logger = await MXLogger.initialize(
  nameSpace: "flutter.mxlogger",
  storagePolicy: MXStoragePolicyType.yyyyMMddHH,
  consoleEnable: true,
  cryptKey: "abcuioqbsdguijlk",   // 16바이트
  iv: "bccuioqbsdguijiv",         // 생략하면 cryptKey와 같은 값
);

logger.setMaxDiskAge(60 * 60 * 24 * 7); // 최대 7일 보관
logger.setMaxDiskSize(1024 * 1024 * 10); // 최대 10 MB 사용
logger.setLevel(0);                      // 0:debug — 모두 파일에 기록

logger.debug("this is debug message", name: "mxlogger", tag: "net,response");
logger.info("this is info message", name: "mxlogger", tag: "tag1,tag2");
logger.warn("this is warn message");
logger.error("this is error message");
logger.fatal("this is fatal message");
```

---

# 1. 아키텍처

```
┌──────────────────────────────────────────────────────────────┐
│  Dart      lib/src/flutter_mxlogger.dart                     │
│  · MethodChannel("flutter_mxlogger") — 기본 디렉터리 조회 전용    │
│  · dart:ffi — 모든 읽기/쓰기, 채널 오버헤드 없음                 │
│  · WidgetsBindingObserver — 백그라운드 진입 시 정리              │
└──────────────┬───────────────────────────┬───────────────────┘
               │ ffi lookup                │ ffi lookup
               │ (flutter_mxlogger_ 접두사 심벌)                │
┌──────────────▼──────────────┐ ┌──────────▼───────────────────┐
│ iOS  flutter-bridge.mm      │ │ Android flutter-bridge.cpp   │
│ Objective-C MXLogger 브리지   │ │ C++ mx_logger 브리지          │
└──────────────┬──────────────┘ └──────────┬───────────────────┘
               │                           │
        ┌──────▼───────────────────────────▼──────┐
        │  Core (C/C++): mmap + AES-CFB-128       │
        │  + FlatBuffers 직렬화                    │
        └─────────────────────────────────────────┘
```

핵심은 **로그 기록 경로에 MethodChannel이 없다**는 점입니다. `log()`는 Dart에서 디스크까지 동기 FFI 호출로 끝나며, 메시지 큐도, 코덱 인코딩도, 플랫폼 스레드 대기도 없습니다.

---

# 2. Dart API

## 2.1 초기화

### `MXLogger.initialize`(권장)

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

| 매개변수 | 설명 |
|---|---|
| `nameSpace` | 로그 파일의 네임스페이스. 고유성을 위해 역순 도메인 표기를 권장. 최종 디렉터리는 `directory/nameSpace` |
| `directory` | 사용자 지정 디렉터리. 생략하면 MethodChannel로 플랫폼 기본값을 조회: iOS `<Library>/com.mxlog.LoggerCache`, Android `<filesDir>/com.mxlog.LoggerCache` |
| `consoleEnable` | 콘솔 출력 여부. debug 빌드에서만 동작 |
| `storagePolicy` | 파일 분할 정책. 2.2 참고 |
| `fileName` | 사용자 지정 파일 이름. 기본값 `mxlog` |
| `fileHeader` | 파일 헤더. 파일이 **생성될 때** 한 번만 기록됨. 앱 버전, 플랫폼, 기기 모델 같은 컨텍스트를 넣기에 적합 |
| `cryptKey` | AES 키. **16바이트: 길면 잘리고 짧으면 0으로 채움.** 생략하면 암호화하지 않음 |
| `iv` | 초기화 벡터. 규칙은 `cryptKey`와 동일. 생략하면 `cryptKey`와 같은 값 |

> ⚠️ 16바이트보다 짧은 `cryptKey` / `iv`의 0 채움은 v2.0.0에서 완전히 수정되었습니다. 짧은 키로 기록된 이전 로그는 분석기에서 읽지 못할 수 있습니다. 정확히 16바이트 키를 사용하세요.

### 동기 생성자

```dart
MXLogger({required String nameSpace, required String directory, ...})
```

`directory`는 필수이고, MethodChannel을 사용하지 않으며, 호출은 동기입니다.

**초기화는 예외를 던지지 않습니다.** 네이티브가 null 핸들을 반환하면(예: 디렉터리를 만들 수 없음) 인스턴스는 자동으로 `enable == false`가 되고, 이후의 모든 호출은 안전하게 단락되며 null 포인터가 네이티브로 전달되는 일은 없습니다. `logger.enable`로 감지할 수 있습니다.

## 2.2 저장 정책 `MXStoragePolicyType`

| 값 | 단위 | 파일 이름 예시 |
|---|---|---|
| `yyyyMMdd`(기본) | 일 | `2023-01-11_mxlog.mx` |
| `yyyyMMddHH` | 시간 | `2023-01-11-15_mxlog.mx` |
| `yyyyWw` | 주 | `2023-01-02w_mxlog.mx`(`02w` = 그 해의 2번째 주) |
| `yyyyMM` | 월 | `2023-01_mxlog.mx` |

## 2.3 로그 기록

### 인스턴스 메서드

```dart
int debug(String msg, {String? name, String? tag});
int info (String msg, {String? name, String? tag});
int warn (String msg, {String? name, String? tag});
int error(String msg, {String? name, String? tag});
int fatal(String msg, {String? name, String? tag});

int log(int lvl, String msg, {String? name, String? tag});
```

- `lvl`: `0` debug, `1` info, `2` warn, `3` error, `4` fatal
- `name`: 로거 이름. 보통 모듈 이름
- `tag`: 태그. 여러 개는 쉼표로 구분(`"net,response"`). 분석기에서 태그로 필터링 가능
- `msg`가 유효한 JSON이면 콘솔에 들여쓰기된 형태로 출력됨

**반환값:**

| 값 | 의미 |
|---|---|
| `0` | 성공 |
| `-1` | 파일 확장 실패 |
| `-2` | unmap 실패 |
| `-3` | mmap 실패 |

### 클래스 메서드(모듈화된 앱)

큰 앱을 모듈로 나누면 하위 모듈이 로거 객체를 들고 있기 어려운 경우가 많습니다. 그럴 때는 `loggerToken` 문자열을 전달하세요.

```dart
// 메인 프로젝트
final token = logger.loggerToken;   // 저장하거나 전역 서비스에 등록

// 하위 모듈 — 로거 인스턴스에 의존하지 않음
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

같은 `loggerToken`은 네이티브 쪽에서도 쓸 수 있습니다. Android는 `FlutterMxloggerPlugin.info(...)`, iOS는 `[FlutterMxloggerPlugin info:...]`이며 같은 파일에 기록됩니다. 토큰이 무엇인지, 유효 기간, 네이티브에서의 사용법은 [3장](#3-loggertoken-모듈과-언어를-넘어-하나의-로거-공유하기)에서 설명합니다.

## 2.4 스위치와 레벨

```dart
void setLevel(int lvl);        // level >= lvl 인 로그만 파일에 기록
void setEnable(bool enable);   // 마스터 스위치. false면 아무것도 기록하지 않음
void setConsoleEnable(bool enable);
void shouldRemoveExpiredDataWhenEnterBackground(bool should); // 기본값 true
```

- `setLevel(2)`로 설정하면 warn 이상만 디스크에 도달하고 debug/info는 버려집니다. **콘솔에는 영향이 없으며** 모든 레벨이 그대로 출력됩니다.
- `setConsoleEnable`은 **static 필드**에 기록하므로 모든 로거 인스턴스에 전역으로 적용됩니다. 로거 생성 시 넘긴 `consoleEnable`도 이 전역 값을 덮어씁니다.

> 🔁 1.x에서 이전: `setFileLevel(int)`은 `setLevel(int)`으로 이름이 바뀌었습니다. 의미는 같습니다.

## 2.5 디스크 관리

```dart
void setMaxDiskAge(int seconds);  // 기본값 0 = 무제한
void setMaxDiskSize(int bytes);   // 기본값 0 = 무제한

void removeExpireData();      // 위 두 임계값에 따라 정리
void removeBeforeAllData();   // 기록 중인 파일을 제외한 모든 로그 파일 삭제
void removeAll();             // 모든 로그 파일 삭제
```

`removeExpireData()`는 두 단계로 정리합니다. 먼저 마지막 수정 시각이 `maxDiskAge`보다 오래된 파일을 삭제하고, 그래도 총 크기가 `maxDiskSize`를 넘으면 가장 오래된 파일부터 계속 삭제합니다. **현재 기록 중인 파일은 절대 삭제되지 않습니다.**

앱이 백그라운드로 들어갈 때 자동으로 한 번 호출됩니다. `shouldRemoveExpiredDataWhenEnterBackground(false)`로 끌 수 있습니다.

## 2.6 상태

| 멤버 | 타입 | 설명 |
|---|---|---|
| `enable` | `bool` | 로깅 사용 가능 여부 |
| `consoleEnable` | `bool` | 콘솔 스위치(전역) |
| `loggerToken` | `String?` | 기반 로거의 고유 토큰. 모듈 간 전달용 |
| `diskcachePath` | `String` | 로그 디렉터리(`directory` + `nameSpace`) |
| `diskcacheErrorPath` | `String` | 오류 기록 파일 경로, 즉 `diskcachePath/error.txt` |
| `logSize` | `int` | 저장된 로그의 총 크기(바이트) |
| `logFiles` | `List<MXFileEntity>` | 로그 파일 목록 |
| `errorDesc` | `String?` | 가장 최근 기록 실패의 설명. 없으면 `null` |
| `cryptKey` / `iv` | `String?` | 초기화 시 전달한 암호화 매개변수 |

### `MXFileEntity`

```dart
class MXFileEntity {
  String? name;          // 파일 이름
  int size;              // 크기(바이트)
  int createTimeStamp;   // 생성 타임스탬프(초)
  int lastTimeStamp;     // 마지막 수정 타임스탬프(초)

  DateTime get createTime;
  DateTime get lastTime;
}
```

## 2.7 기록 실패 남기기

`log()`가 0이 아닌 값을 반환하면 해당 항목은 기록되지 않은 것입니다. 나중에 조사할 수 있도록 실패를 별도의 텍스트 파일에 남길 수 있습니다.

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

항목은 JSON 라인으로 `diskcacheErrorPath`에 추가됩니다.

```json
{"code":-3,"error":"mmap failed","other":"userId=123"}
```

```dart
void writeFail({required int code, required String errorDesc, String? other});
void deleteFailFile();  // 오류 파일 삭제
void closeFailFile();   // 기록 스트림 닫기
```

> 경로가 유효하지 않으면(초기화되지 않음, 비활성화됨, 파기됨) `writeFail`은 파일 시스템 루트에 기록하는 대신 즉시 반환합니다.

## 2.8 로그 파일 파싱

```dart
static List<Map<String, dynamic>> selectLogmsg({
  required String diskcacheFilePath,
  String? cryptKey,
  String? iv,
});
```

로그 파일의 전체 경로와 기록 시 사용한 암호화 매개변수를 전달합니다(암호화하지 않은 파일이면 생략). 항목은 **최신 순**으로 반환되며 각 항목은 다음 필드를 가집니다.

| 필드 | 설명 |
|---|---|
| `name` | 로거 이름 |
| `tag` | 태그 |
| `msg` | 로그 메시지 |
| `level` | 레벨 |
| `timestamp` | 타임스탬프 |
| `thread_id` | 스레드 ID |
| `is_main_thread` | 메인 스레드였는지 여부 |
| `error_code` | `"1"`은 해당 항목의 디코딩 실패를 뜻함. 대개 `cryptKey` / `iv` 오류 |

동기 FFI 호출이므로 큰 파일에서는 블로킹됩니다. isolate에서 실행하세요.

```dart
final records = await Isolate.run(() => MXLogger.selectLogmsg(
      diskcacheFilePath: path,
      cryptKey: key,
      iv: iv,
    ));
```

`logFiles`와 함께 쓰면 앱 내 로그 뷰어를 만들기에 충분합니다. example의 `log_viewer_page.dart`가 바로 그렇게 구현되어 있습니다. UI를 직접 만들고 싶지 않다면 [4장](#4-mx-로그-파일-읽기)에 있는 데스크톱 분석기와 앱 내장 분석기를 참고하세요.

> `selectLogfiles({required String directory})`는 구현되지 않은 스텁으로, 모든 플랫폼에서 빈 리스트를 반환합니다. 사용하지 마세요.

## 2.9 로거 파기

```dart
static void destroy({required String nameSpace, String? directory});
static void destroyWithLoggerToken(String loggerToken);
```

파기는 먼저 해당하는 Dart 인스턴스를 무효화하고(라이프사이클 옵저버 제거, 오류 파일 싱크 닫기, 네이티브 핸들 초기화), 그 다음에 네이티브 객체를 해제합니다.

이 순서가 중요합니다. 네이티브를 먼저 해제하면 백그라운드 진입 시 정리 콜백이 해제된 포인터로 네이티브 코드를 호출하게 되어 use-after-free로 크래시합니다.

같은 `nameSpace + directory`로 만든 여러 Dart 인스턴스는 하나의 네이티브 객체를 공유하며, `destroy`는 그 **전부**를 무효화합니다. 이전 인스턴스가 남겨지는 일은 없습니다.

---

# 3. `loggerToken`: 모듈과 언어를 넘어 하나의 로거 공유하기

## 3.1 무엇인가

`loggerToken`은 하나의 네이티브 로거를 식별하는 문자열입니다. C++ 코어가 로그 디렉터리에서 유도합니다: `md5(directory/nameSpace)`, 즉 `diskcachePath`의 MD5입니다. 여기서 세 가지 특성이 나옵니다.

- 같은 `nameSpace` + `directory`는 항상 같은 토큰을 만듭니다. 실행마다 같고, iOS와 Android에서도 같습니다. 디렉터리가 다르면 토큰도 다릅니다.
- 코어는 전역 테이블 `token → logger`를 유지합니다. 토큰을 받는 모든 API는 이 테이블에서 로거를 찾으므로, 토큰은 해당 로거가 현재 프로세스에서 초기화된 동안에만 동작합니다.
- 비밀 값이 아니며 `cryptKey` / `iv`와 무관합니다. 저장하거나 모듈 간에 전달하거나 출력해도 문제 없습니다.

`logger.loggerToken`(또는 `getLoggerToken()`)으로 읽습니다. 인스턴스가 비활성화된 경우, 예를 들어 초기화가 실패했을 때(2.1)는 `null`입니다.

## 3.2 하위 모듈에서 기록하기(Dart)

모듈화된 앱에서는 메인 프로젝트가 로거를 소유하고 디렉터리와 암호화 설정을 알고 있습니다. 하위 모듈은 둘 다에 의존하지 않아야 합니다. 토큰을 넘겨주고 2.3에 나온 클래스 메서드를 쓰게 하세요.

```dart
// 메인 프로젝트: 한 번 초기화하고 토큰을 공개
final logger = await MXLogger.initialize(nameSpace: "com.example.app", cryptKey: key, iv: iv);
AppServices.loggerToken = logger.loggerToken;   // 어떤 서비스 로케이터 / DI 컨테이너든 가능

// 하위 모듈: MXLogger가 어떻게 설정됐는지 전혀 모름
MXLogger.infoLog(AppServices.loggerToken, "user tapped pay", name: "pay", tag: "ui");
MXLogger.errorLog(AppServices.loggerToken, "payment failed: $error", name: "pay", tag: "order");
```

모든 항목은 같은 파일에 기록되며 메인 프로젝트 인스턴스와 같은 레벨 필터, 암호화, 콘솔 스위치를 따릅니다. 토큰이 `null`이거나 알 수 없는 값이면 클래스 메서드는 그 항목을 버립니다. 예외는 던지지 않습니다.

## 3.3 네이티브 코드에서 기록하기(Android / iOS)

토큰은 공유 C++ 코어에서 계산되므로 네이티브 계층도 같은 문자열을 이해합니다. 자체 채널(MethodChannel, Pigeon, 네이티브 싱글턴 등)로 전달하면 Flutter 로거의 파일에 바로 기록할 수 있습니다.

```java
// Android: com.coderdjy.mxlogger.FlutterMxloggerPlugin
FlutterMxloggerPlugin.info(loggerToken, /*tag*/ "network", /*name*/ "okhttp", /*msg*/ "GET /user 200");
```

```objc
// iOS: FlutterMxloggerPlugin.h
[FlutterMxloggerPlugin info:loggerToken name:@"URLSession" msg:@"GET /user 200" tag:@"network"];
```

매개변수 순서에 주의하세요. Android는 `(token, tag, name, msg)`, iOS는 `(token, name, msg, tag)`입니다. 둘 다 `debug` / `info` / `warn` / `error` / `fatal`을 제공합니다. 네이티브 코드가 MXLogger SDK 자체를 링크하고 있다면 SDK의 토큰 메서드도 사용할 수 있습니다: Android `MXLogger.log(token, tag, level, name, msg)`, iOS `[MXLogger infoWithLoggerToken:name:msg:tag:]`(Swift: `MXLogger.info(loggerToken:name:message:tag:)`).

## 3.4 수명

- 토큰은 `MXLogger.initialize`부터 `destroy` / `destroyWithLoggerToken`(2.9)까지 유효합니다. 같은 `nameSpace` + `directory`를 두 번 생성하면 하나의 네이티브 로거가 재사용되므로 두 Dart 인스턴스가 같은 토큰을 반환합니다.
- `MXLogger.destroyWithLoggerToken(token)`은 문자열만 가진 코드를 위한 파기 방법입니다. 그 토큰에 해당하는 모든 Dart 인스턴스를 무효화하고(`enable`이 `false`가 되고 이후 호출은 아무 동작도 하지 않음) 네이티브 객체를 해제합니다. 그 뒤로 그 토큰으로 기록한 항목은 버려집니다.
- 같은 매개변수로 다시 초기화하면 동일한 토큰 문자열이 나오고 기록이 재개됩니다. 따라서 저장해 둔 토큰은 실행을 넘어도 만료되지 않지만, 메인 프로젝트가 이 프로세스에서 로거를 초기화한 뒤에만 동작합니다.

빠른 참조:

| 필요한 것 | API |
|---|---|
| 토큰 얻기 | `logger.loggerToken` |
| Dart에서 기록 | `MXLogger.debugLog / infoLog / warnLog / errorLog / fatalLog(token, msg, name:, tag:)`, `MXLogger.logLoggerToken(token, lvl, msg, name:, tag:)` |
| Android에서 기록 | `FlutterMxloggerPlugin.debug / info / warn / error / fatal(token, tag, name, msg)` |
| iOS에서 기록 | `[FlutterMxloggerPlugin debug / info / warn / error / fatal:token name: msg: tag:]` |
| 토큰으로 파기 | `MXLogger.destroyWithLoggerToken(token)` |

# 4. `.mx` 로그 파일 읽기

`.mx` 파일은 텍스트가 아닙니다. 모든 레코드는 flatbuffer이고, 로거가 `cryptKey` / `iv`로 생성되었다면 파일 전체가 AES-CFB-128로 암호화되어 있어 에디터로 열면 바이너리 잡음만 보입니다. 읽는 방법은 세 가지이며 상황에 따라 고릅니다.

| 상황 | 사용할 것 |
|---|---|
| 기기에서 꺼낸 파일이나 사용자가 업로드한 파일을 컴퓨터에서 분석 | [4.2 데스크톱 분석기](#42-데스크톱-분석기macos--windows--linux) |
| 테스트 중 컴퓨터 없이 휴대폰에서 로그 읽기 | [4.3 앱 내장 분석기](#43-앱-내장-분석기mxlogger_analyzer_lib) |
| Dart로 직접 뷰어나 업로드 파이프라인 만들기 | [4.4 Dart로 파싱하기](#44-dart로-파싱하기) |

## 4.1 파일 위치

- **디렉터리**: `logger.diskcachePath`, 즉 `directory/nameSpace`. 기본 디렉터리를 쓰면 iOS는 `<Library>/com.mxlog.LoggerCache/<nameSpace>`, Android는 `<filesDir>/com.mxlog.LoggerCache/<nameSpace>`(`/data/data/<package>/files/...`)입니다.
- **파일 이름**은 저장 정책(2.2)을 따릅니다. 예: `2023-01-11_mxlog.mx`. 옆에 있는 `error.txt`(2.7)는 일반 텍스트라 파서가 필요 없습니다.
- **Dart에서 목록 얻기**: `logger.logFiles`는 `MXFileEntity(name, size)`를 반환합니다. 전체 경로는 `"${logger.diskcachePath}/${file.name}"`입니다.

파일을 컴퓨터로 가져오는 방법:

- **iOS 실기기**: Xcode > Window > Devices and Simulators > 기기와 앱 선택 > ⚙︎ > *Download Container…*. `.xcappdata`를 우클릭 > *패키지 내용 보기* > `AppData/Library/com.mxlog.LoggerCache/<nameSpace>/`.
- **iOS 시뮬레이터**:

  ```bash
  open "$(xcrun simctl get_app_container booted <bundle id> data)/Library/com.mxlog.LoggerCache/<nameSpace>"
  ```

- **Android**(debuggable 빌드. 디렉터리는 앱 전용 영역):

  ```bash
  adb shell run-as <package> ls files/com.mxlog.LoggerCache/<nameSpace>
  adb exec-out run-as <package> cat files/com.mxlog.LoggerCache/<nameSpace>/2023-01-11_mxlog.mx > 2023-01-11_mxlog.mx
  ```

- **릴리스 빌드 / 실제 사용자**: 앱이 직접 파일을 내보내야 합니다. 예를 들어 `share_plus`로 공유하거나 `logFiles`의 경로로 서버에 업로드합니다. 로거가 열려 있는 상태에서도 파일을 복사할 수 있습니다. 아래의 앱 내장 분석기도 같은 방식으로 실시간 디렉터리를 읽습니다.

## 4.2 데스크톱 분석기(macOS / Windows / Linux)

[Releases](https://github.com/coder-dongjiayi/MXLogger/releases)에서 자신의 OS용 `mxlogger_analyzer`를 다운로드합니다. 첫 실행은 3단계 마법사입니다.

1. **파일 선택**: 하나 이상의 `.mx` 파일을 창으로 드래그하거나 클릭해서 선택합니다.
2. **복호화**: 로거를 만들 때 쓴 `cryptKey` / `iv`를 입력합니다. 암호화하지 않은 로그는 둘 다 비워 둡니다. 키를 교체한 적이 있다면 모든 쌍을 추가하세요. 번호가 붙은 체크박스 순서대로 레코드가 디코딩될 때까지 시도합니다. 값은 다음을 위해 기억됩니다.
3. **가져오기**: 실제 진행률 표시줄(파싱한 바이트, 기록한 행)이 표시되고 완료되면 데이터 페이지가 자동으로 열립니다.

데이터 페이지 헤더에는 총 건수, 시간 범위, 파일 이름이 표시됩니다. 그 아래에는 클릭으로 필터링되는 레벨 분포 막대와 DEBUG–FATAL 칩, 시간 범위 필터가 있는 키워드 검색(전체 / 메시지 / 태그 / 이름), 카드의 `@name`이나 `#tag`를 클릭해 필터링, JSON 메시지의 구문 색상 트리, 한 레코드의 전체 화면 상세(Esc로 닫기), 공유 버튼을 통한 `.txt` 내보내기가 있습니다. 파일 변경, 키 변경, 데이터 삭제는 헤더 메뉴에 있습니다.

파싱이 실패하면 마법사는 2단계로 돌아갑니다. 거의 항상 `cryptKey` / `iv`가 틀린 경우입니다. v2.0.0 이전에 16바이트보다 짧은 키로 기록된 로그는 디코딩되지 않을 수 있습니다(2.1의 주석 참고).

스크린샷과 전체 기능 목록은 저장소 [README](https://github.com/coder-dongjiayi/MXLogger#log-analyzer)에 있습니다.

## 4.3 앱 내장 분석기(`mxlogger_analyzer_lib`)

분석기 코어는 Flutter 패키지로도 제공됩니다. 앱의 `Overlay`에 드래그 가능한 플로팅 볼을 올리고, 탭하면 바텀 시트가 열려 `diskcachePath`를 필요할 때 파싱하므로 테스터가 컴퓨터 없이 기기에서 로그를 읽을 수 있습니다.

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
  // 모든 복호화 쌍. 순서대로 시도됨. 암호화하지 않은 로그는 [] 전달
  cryptPairs: [
    MxCryptPair(key: logger.cryptKey ?? "", iv: logger.iv ?? ""),
    // MxCryptPair(key: "legacy-key", iv: "legacy-iv"),
  ],
  // 공유는 호스트가 연결한다(share_plus, 자체 업로더 등).
  // false를 반환하면 클립보드 복사로 대체된다
  onShare: (MXShareRequest request) async => false,
);

MXAnalyzer.dismiss(); // 볼을 제거하고 데이터베이스를 해제
```

디버깅 도구이므로 최종 사용자에게 배포하지 말고 debug 플래그 뒤에서만 켜세요. 전체 API와 모바일 레이아웃 설명: [mxlogger_analyzer_lib README](https://github.com/coder-dongjiayi/MXLogger/blob/main/mxlogger_analyzer/mxlogger_analyzer_lib/README.md).

## 4.4 Dart로 파싱하기

`MXLogger.selectLogmsg`(2.8)는 한 파일을 분석기가 표시하는 것과 같은 필드를 가진 `List<Map<String, dynamic>>`로 디코딩합니다. 자체 UI를 만들고 싶거나 업로드 전에 로그를 JSON / 텍스트로 변환하고 싶을 때 사용합니다. 동기 FFI이므로 isolate에서 실행하세요. example의 `log_viewer_page.dart`가 완전한 참고 구현입니다.

# Example

`example/`은 이 문서의 모든 API를 다루는 완전한 데모 앱입니다: 초기화, 다섯 레벨 전부, 모듈화 앱을 위한 loggerToken 기반 기록, 저장 정책, 파일 목록, 로그 뷰어와 파싱, 파기.

```bash
cd example && flutter run
```

# License

BSD 3-Clause. [LICENSE](LICENSE)를 참고하세요.
