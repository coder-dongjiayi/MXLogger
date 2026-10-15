import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

CommonDatabase openNativeDatabase(String path) => sqlite3.open(path);
