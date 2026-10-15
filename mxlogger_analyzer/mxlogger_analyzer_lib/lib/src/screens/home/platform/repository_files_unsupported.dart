import 'package:mxlogger_analyzer_lib/src/screens/home/home_repository.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';

Future<List<int>> fileSizes(List<String> paths) async =>
    throw UnsupportedError('Inject a browser repository.');
Future<List<LoadedFile>> readFiles({
  required List<String> paths,
  required List<int> sizes,
  void Function(double)? onProgress,
}) async => throw UnsupportedError('Inject a browser repository.');
Future<List<ParsedFile>> parseFiles({
  required List<LoadedFile> files,
  List<MxCryptPair> cryptPairs = const [],
  void Function(int, double)? onProgress,
}) async => throw UnsupportedError('Inject a browser repository.');
Future<List<String>> listLogFiles(String directory) async => [];
