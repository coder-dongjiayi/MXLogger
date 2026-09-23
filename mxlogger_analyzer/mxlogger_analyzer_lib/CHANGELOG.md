## 2.0.2
1. Add the ability to view the surrounding context of a log entry after filtering (anchored positioning).
2. Add search to the log detail dialog.
## 2.0.1
* Fix an issue where log files could not be fully parsed in some cases.
## 2.0.0
* Remove the `flutter_riverpod` dependency in favor of a built-in, lightweight Stream-based state management (`MXStore` / `MXAsyncStore` / `MXBuilder`), avoiding version conflicts with the host app's state management library when integrated as a plugin.
* Breaking change: `flutter_riverpod` is no longer exported; `MXLoggerButton.onPressed` changed from `ValueChanged<WidgetRef>` to `VoidCallback`.
* `share_plus` is no longer bundled when embedded on mobile.
## 1.2.2
* update `share_plus`-> ^11.0.0
## 1.2.1
* update `share_plus` `share_plus` `sqlite3`, support flutter 3.19.5 dart 3.3.0.
## 1.2.0
* Refactor the search box to open in a dialog.
* Support searching multiple fields at once (tag, name, msg). Keywords are fuzzy-matched by default; type `tag:` in the input to search only the tag (same for name and msg).
* Double-tap a search result to remove that search filter.
## 1.1.1
* Support Android
## 1.1.0
* Upgrading sqlite
## 1.0.9
* Add system share. Delete sqlite3_flutter_libs.
## 1.0.8
* Update Flutter dependencies, set Flutter >=3.3.0 and Dart to >=2.18.0 <4.0.0
## 1.0.7
* Adaptation flutter 3.10.0.
## 1.0.6
* Add hidden future when on double tap.
## 1.0.5
* Add switch 'tag','name','msg'
## 1.0.4
* Remove isDebug arg.
## 1.0.3
* Fix bug.
## 1.0.2
* Use SelectionArea.
## 1.0.1+1
* Add sqlite3_flutter_libs dependencie.
## 1.0.1
* Add isDebugMode arg.
## 1.0.0
* MXLogger debugger.

