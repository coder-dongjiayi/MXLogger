import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer/src/controller/mxlogger_repository.dart';
import 'package:mxlogger_analyzer/src/storage/mxlogger_storage.dart';

///  查询所有日志数据
final logPagesProvider = FutureProvider.autoDispose((ref) {
  final repository = ref.watch(mxloggerRepositoryProvider);
  final kw = ref.watch(searchKeywordProvider);

  final logResponse =
      repository.fetchLogs(page: null, keyWord: kw, levels: null);

  return logResponse;
});

/// 导入二进制数据
final importBinaryDataProvider = StreamProvider.autoDispose((ref) {
  final repository = ref.watch(mxloggerRepositoryProvider);
  final file = ref.watch(updateBinaryXFileProvider);
  final response = repository.importBinaryData(
      file: file,
      cryptKey: MXLoggerStorage.instance.cryptKey,
      cryptIv: MXLoggerStorage.instance.cryptIv);
  return response;
});


final updateBinaryXFileProvider = StateProvider.autoDispose<XFile?>((ref)=> null);

/// 搜索状态
final searchKeywordProvider = StateProvider.autoDispose<String?>((ref) {
  return null;
});
