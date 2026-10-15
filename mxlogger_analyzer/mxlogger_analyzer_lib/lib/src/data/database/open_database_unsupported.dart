import 'package:sqlite3/common.dart';

CommonDatabase openNativeDatabase(String path) => throw UnsupportedError(
  'On the web, inject a WASM connection with AnalyzerDatabase.fromConnection.',
);
