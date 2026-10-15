import 'dart:io';
import 'dart:typed_data';
import 'package:mxlogger_analyzer_lib/src/screens/home/home_repository.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/parse_isolate.dart';

/// 各文件字节大小（进度权重与文件标签用）。IO 失败抛出。
Future<List<int>> fileSizes(List<String> paths) async {
  final List<int> sizes = [];
  for (final String path in paths) {
    sizes.add(await File(path).length());
  }
  return sizes;
}

/// 读取文件字节，按**累计已读字节**回报真实进度（0.0-1.0）。
///
/// 分块读而不是一次 `readAsBytes`：单个大文件光读就要几百毫秒
/// （127 MiB 实测约 350ms），整块读期间无从回报，进度条只能僵在起点。
/// 读取与解析拆成两步也是为此——原先 readAsBytes 藏在 [parseFiles] 内部，
/// 那段耗时被算进了解析阶段的开头且不回报，表现为进度条卡在解析起点不动。
/// IO 失败直接抛出，由上层归类为读取错误。
Future<List<LoadedFile>> readFiles({
  required List<String> paths,
  required List<int> sizes,
  void Function(double fraction)? onProgress,
}) async {
  const int chunkSize = 4 * 1024 * 1024;
  final int totalBytes = sizes.fold(0, (int sum, int size) => sum + size);
  final List<LoadedFile> files = [];
  int done = 0;
  for (int i = 0; i < paths.length; i++) {
    final String path = paths[i];
    final int size = sizes[i];
    final Uint8List bytes = Uint8List(size);
    final RandomAccessFile handle = await File(path).open();
    int offset = 0;
    try {
      while (offset < size) {
        final int end = offset + chunkSize < size ? offset + chunkSize : size;
        final int read = await handle.readInto(bytes, offset, end);
        // 读到 0 说明文件在 stat 之后被截短了，按实际读到的长度收尾
        if (read <= 0) break;
        offset = offset + read;
        done = done + read;
        if (totalBytes > 0) onProgress?.call(done / totalBytes);
      }
    } finally {
      await handle.close();
    }
    files.add((
      name: path.split(Platform.pathSeparator).last,
      // 文件被截短时不能把尾部的零字节交给解析器
      bytes: offset == size ? bytes : Uint8List.sublistView(bytes, 0, offset),
    ));
  }
  if (totalBytes <= 0) onProgress?.call(1);
  return files;
}

/// 解析已读入内存的 `.mx` 文件（不落库）：AES 解密 + flatbuffer 反序列化，
/// 在独立 isolate 内执行。[cryptPairs] 为多组解密参数，
/// 按顺序依次尝试（第一组解不开换下一组）。
/// [onProgress] 回报（文件下标, 该文件内 0.0-1.0 真实进度）。
///
/// 注意：字节所有权会转移给解析 isolate（见 [ParseIsolate.run]），
/// 调用方在此之后不可再读 [files] 里的 bytes。
Future<List<ParsedFile>> parseFiles({
  required List<LoadedFile> files,
  List<MxCryptPair> cryptPairs = const <MxCryptPair>[],
  void Function(int fileIndex, double fraction)? onProgress,
}) async {
  final List<ParsedFile> results = [];
  for (int i = 0; i < files.length; i++) {
    final LoadedFile file = files[i];
    onProgress?.call(i, 0);
    final MxParseResult? result = await ParseIsolate.run(
      bytes: file.bytes,
      cryptPairs: cryptPairs,
      onProgress: (double fraction) => onProgress?.call(i, fraction),
    );
    onProgress?.call(i, 1);
    // result 为 null 仅代表解析异常（格式损坏等）；空记录的结果原样保留，
    // 由上层结合 errorCount 区分「文件里没有日志」与「Key/IV 错误全部解密失败」
    results.add((name: file.name, result: result));
  }
  return results;
}

Future<List<String>> listLogFiles(String directory) async {
  final dir = Directory(directory);
  if (!dir.existsSync()) return [];
  return dir
      .listSync()
      .whereType<File>()
      .map((file) => file.path)
      .where((path) => path.toLowerCase().endsWith('.mx'))
      .toList()
    ..sort();
}
