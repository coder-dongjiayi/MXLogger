English | [简体中文](README.zh-CN.md)

# mxlogger_analyzer_lib

The MXLogger 2.0 log analyzer core: import, decrypt (AES-CFB-128), parse and search the `.mx`
mmap binary logs written by [MXLogger](https://github.com/coder-dongjiayi/MXLogger).
JSON-lines text logs (`.log/.txt/.json`) are supported too. Records land in sqlite, which backs
full-text search, level/time/Tag/Name filtering and a JSON syntax tree view.

Two ways to use it, one `main` in this repository for each:

| Mode | Entry point | What it is |
| --- | --- | --- |
| Standalone app | [`lib/main_desktop.dart`](../lib/main_desktop.dart) | macOS/Windows/Linux desktop shell — drop or pick a log file to analyze |
| Embedded in a host app | [`lib/main_package.dart`](../lib/main_package.dart) | Inspect on-device logs inside an iOS/Android app via a floating ball + bottom sheet |

## Screens

**Data page**: level distribution bar + level chips, search and time filters, syntax-colored JSON
tree inside each log card, click-to-filter `@name` / `#tag`, and per-record info / share /
fullscreen / copy. The top-right toggle switches to the light theme (both token sets are fully
aligned).

![Data page](screenshots/desktop_dark.png)

**Three-step first-run wizard**: ① drop or pick log files → ② configure the decryption KEY/IV
(multiple pairs allowed) → ③ import with real progress.

![First-run wizard](screenshots/desktop_wizard.png)

**Fullscreen detail of a single record** (Esc closes): Name / Tags / time / type plus the complete
JSON tree, shareable or copyable as a whole.

![Fullscreen log detail](screenshots/desktop_detail.png)

**Embedded in a host app** (phone): a bottom sheet covering 85% of the screen — tighter padding,
icons instead of labels, horizontally scrolling level chips, cards collapsed by default and
actions folded into the "⋯" menu.

![Embedded bottom sheet](screenshots/mobile_embed.png)

## Standalone app: the desktop shell entry

The core does not depend on shared_preferences / file_picker / desktop_drop / share_plus directly.
The shell implements `MXHost` (settings persistence / file picking / file dropping / system share)
with those plugins and injects it, which keeps the entry point thin — the whole of
[`lib/main_desktop.dart`](../lib/main_desktop.dart):

```dart
import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';

import 'package:mxlogger_analyzer/src/host/desktop_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The desktop shell injects platform capabilities (shared_preferences /
  // file_picker / desktop_drop); the core itself depends on none of them.
  final MXHost host = await createDesktopHost();
  runApp(MXScope(
    store: MXStore(host: host),
    child: const MXLoggerAnalyzerApp(),
  ));
}
```

The `MXHost` returned by `createDesktopHost()` (see
[`lib/src/host/desktop_host.dart`](../lib/src/host/desktop_host.dart)) carries four capabilities.
Leaving one out removes the matching entry point instead of throwing:

| Capability | Desktop shell implementation | When absent |
| --- | --- | --- |
| `prefs` | shared_preferences | falls back to `MXMemoryPrefs`, settings live in memory only |
| `pickLogFiles` | file_picker | the "pick a file" entry is not shown |
| `dropTargetBuilder` | desktop_drop | pages render as-is, no drop target wrapper |
| `share` | share_plus | "share" degrades to copying to the clipboard |

Run it:

```bash
flutter run -t lib/main_desktop.dart -d macos   # or windows / linux
```

## Embedded in a host app: the on-device entry

[`lib/main_package.dart`](../lib/main_package.dart) closes the loop on a real device:
flutter_mxlogger writes genuine encrypted `.mx` files locally, then the floating ball opens the
analyzer against that same directory.

```bash
flutter run -t lib/main_package.dart -d <iOS/Android device>
```

### 1. The host writes logs first

`fileHeader` carries the device environment (device_info_plus); the analyzer's Header dialog
expands it into a compact scalar grid plus a JSON tree:

```dart
final MXLogger logger = await MXLogger.initialize(
  nameSpace: "flutter.mxlogger",
  storagePolicy: MXStoragePolicyType.yyyy_MM_dd,
  fileHeader: jsonEncode(header),      // writer-side environment info
  consoleEnable: true,
  cryptKey: "bnijioijuojiuoju",        // 16 bytes
  iv: "njkoiuhjbjuiasdh",
);

logger.debug("token check started", name: "login", tag: "login,service");
logger.info(jsonEncode(response), name: "network", tag: "network,POST,200");
logger.error(flutterErrorStack, name: "flutter", tag: "flutter,crash");
logger.fatal("database connection lost", name: "database", tag: "db,fatal");
```

### 2. The floating ball opens the analyzer

`MXAnalyzer` mounts on the host app's `Overlay` (drag to move, single tap to open the sheet,
double tap to dismiss) and stays visible across route pushes:

```dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// MaterialApp(navigatorKey: navigatorKey, ...)

await MXAnalyzer.showDebug(
  navigatorKey.currentState!.overlay!,
  diskcachePath: logger.diskcachePath,   // MXLogger's log directory
  // The host passes every decryption pair (empty list when logs are plain);
  // multiple pairs are tried in the given order.
  cryptPairs: [
    MxCryptPair(key: logger.cryptKey ?? "", iv: logger.iv ?? ""),
    // MxCryptPair(key: "legacy-key", iv: "legacy-iv"),
  ],
  onShare: _shareWithSharePlus,
);

MXAnalyzer.dismiss();   // removes the ball and releases the database
```

### 3. Sharing is the host's job (with a fallback)

The core depends on no share plugin: the host wires up share_plus itself and injects it through
`onShare`. Returning `false` (unavailable in the current environment) makes the core degrade to
copying to the clipboard. A non-null `MXShareRequest.fileName` asks for a text-file share
(exporting logs); `origin` is the screen rect of the triggering widget, which the popover-style
share sheet on iPad/macOS needs:

```dart
Future<bool> _shareWithSharePlus(MXShareRequest request) async {
  final ShareResult result;
  if (request.fileName != null) {
    result = await SharePlus.instance.share(ShareParams(
      title: request.title,
      files: [
        XFile.fromData(
          Uint8List.fromList(utf8.encode(request.text)),
          name: request.fileName,
          mimeType: "text/plain",
        ),
      ],
      fileNameOverrides: [request.fileName!],
      sharePositionOrigin: request.origin,
    ));
  } else {
    result = await SharePlus.instance.share(ShareParams(
      title: request.title,
      text: request.text,
      sharePositionOrigin: request.origin,
    ));
  }
  return result.status != ShareResultStatus.unavailable;
}
```

### 4. Optional pre-configuration

```dart
MXAnalyzer.initialize(
  databasePath: dir.path,   // sqlite directory, defaults to getApplicationSupportDirectory()
  prefs: myPrefs,           // implement MXPrefs to persist theme/locale/user-added crypt pairs
);
```

## How the embedded mode behaves

- The sheet hosts a nested MaterialApp with its own Navigator, theme and zh/en localizations.
  The host is **not** required to provide a state container or `AppLocalizations` — only a
  `MaterialApp` (for the Overlay).
- Pairs passed via `cryptPairs` are moved to the top of the settings table and checked (an
  already-present identical pair is only checked). Decryption is attempted **per record** in the
  order shown by the checkbox numbers, moving on when a pair fails — so records encrypted with
  different Key/IV inside one file (the writer rotated keys) all come out.
- **Opening the sheet parses nothing.** Parsing only starts when the user taps "refresh" (parsing
  is slow for large logs and must not block opening the sheet). Whatever the database already
  holds is shown right away; with nothing stored you get an empty page plus a "refresh logs"
  button. The refresh entry sits at the top-right of the header (replacing the desktop
  "change file").
- **Results are persisted in sqlite**, so reopening the sheet after an app restart still shows the
  previous run — tap refresh for the latest logs.
- **Every refresh clears the database and re-parses** the `.mx/.log/.txt/.json` files under
  `diskcachePath` from scratch; results are never merged with the previous run, so what you see is
  exactly this scan.
- **Deliberately few dependencies**: the embedded mode pulls in no KV-storage or file plugins such
  as shared_preferences / file_picker / desktop_drop — Key/IV arrive with each `showDebug` call and
  settings default to memory only (they survive closing and reopening the ball, and reset when the
  process dies). File picking / dropping / persisted settings are host capabilities (`MXHost`),
  provided by the desktop shell.

## Phone layout

One UI serves both desktop and phone, switching on available width (not `Platform`) at two
breakpoints defined in `lib/src/global/util/mx_responsive.dart`
(`context.isMobileLayout` / `isNarrowLayout`):

- **≤720**: side padding 20→14; the brand subtitle and toolbar button labels are hidden (icons
  only); level chips scroll horizontally on a single line up to the screen edge; the search field
  takes a full row; Key/IV and time-range inputs stack full-width; action buttons grow
  (30→38 / 28→36 / floating 36→44); padding around the log area is squeezed to a minimum (list
  sides 2, card left 6, fold button 16, element gap 5 — on a narrow screen every margin eats body
  width); log cards are collapsed by default (a single preview line) with the four actions folded
  into "⋯" that opens a bottom panel; the log detail and Header dialogs go fullscreen (no rounded
  corners, footer buttons split evenly); input font size is unified at 16.
- **≤480**: the Header scalar grid becomes a single column.

Timestamps always show the full `y-M-d H:m:s.SSS`. The design's rule of hiding the date on narrow
screens was not adopted — hours/minutes/seconds alone are not enough when hunting a bug; the width
comes from folding the actions into "⋯" instead.

The filter area (distribution bar + level chips, search field, time range/fold buttons, time
panel) takes up nearly half a phone screen, so a floating button in the bottom-left corner
**collapses and expands it manually** (the brand row and top-right actions always stay).
Collapsing uses `MXCollapsible` (heightFactor animated to 0 plus clipping) rather than
conditional building: the subtree stays mounted, so the search text and focus are not lost.
There is no auto-collapse on scroll — the UI jumping as soon as a finger moves is worse.

Safe areas: the embedded sheet starts at 15% of the screen height, so `MXAnalyzer` removes the top
padding; the bottom home indicator is avoided individually by the list's bottom padding, the
floating buttons, dialog footers and toasts. The regression guard is
`test/mobile_layout_test.dart` (rendered at iPhone sizes — any overflow fails the test).

## Development

- Localization: strings live in `lib/src/app/l10n/app_zh.arb` / `app_en.arb`; run `flutter gen-l10n`
  in the package directory after editing (generated files are committed under
  `lib/src/app/l10n/gen/`).
- Tests: `flutter test` (parser / database / pagination / dialog and page widget tests).
- The screenshots above are generated from code with fixed sizes and fake data, so one rerun
  refreshes the whole set. They run inside a **real macOS app** because the headless
  `flutter test` environment only has placeholder fonts:

  ```bash
  cd ..   # the desktop shell project
  flutter test integration_test/generate_screenshots_test.dart -d macos \
      --dart-define=OUT_DIR=$PWD/mxlogger_analyzer_lib/screenshots
  ```

  A sandboxed app may not be able to write into the repository directory; it then falls back to
  the application support directory and prints the path — copy the PNGs back into
  `mxlogger_analyzer_lib/screenshots/` from there.
