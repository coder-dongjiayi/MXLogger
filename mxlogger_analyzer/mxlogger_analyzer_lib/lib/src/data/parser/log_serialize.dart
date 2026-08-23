import 'package:mxlogger_analyzer_lib/src/dependencies/flat_buffers/flat_buffers.dart' as fb;

/// MXLogger 单条日志的 flatbuffer 结构（与 native 端 schema 对齐）：
/// name(4) tag(6) msg(8) level:int8(10) threadId:int32(12)
/// isMainThread:uint8(14) timestamp:uint64(16)
class LogSerialize {
  LogSerialize._(this._bc, this._bcOffset);

  factory LogSerialize(List<int> bytes) {
    final fb.BufferContext rootRef = fb.BufferContext.fromBytes(bytes);
    return reader.read(rootRef, 0);
  }

  static const fb.Reader<LogSerialize> reader = _LogSerializeReader();

  final fb.BufferContext _bc;
  final int _bcOffset;

  String get name => const fb.StringReader().vTableGet(_bc, _bcOffset, 4, "");
  String get tag => const fb.StringReader().vTableGet(_bc, _bcOffset, 6, "");
  String get msg => const fb.StringReader().vTableGet(_bc, _bcOffset, 8, "");
  int get level => const fb.Int8Reader().vTableGet(_bc, _bcOffset, 10, 0);
  int get threadId => const fb.Int32Reader().vTableGet(_bc, _bcOffset, 12, 0);
  int get isMainThread => const fb.Uint8Reader().vTableGet(_bc, _bcOffset, 14, 0);
  int get timestamp => const fb.Uint64Reader().vTableGet(_bc, _bcOffset, 16, 0);
}

class _LogSerializeReader extends fb.TableReader<LogSerialize> {
  const _LogSerializeReader();

  @override
  LogSerialize createObject(fb.BufferContext bc, int offset) => LogSerialize._(bc, offset);
}

/// 仅供单元测试构造 .mx 二进制使用。
class LogSerializeBuilder {
  LogSerializeBuilder(this.fbBuilder);

  final fb.Builder fbBuilder;

  void begin() {
    fbBuilder.startTable(7);
  }

  void addNameOffset(int offset) => fbBuilder.addOffset(0, offset);
  void addTagOffset(int offset) => fbBuilder.addOffset(1, offset);
  void addMsgOffset(int offset) => fbBuilder.addOffset(2, offset);
  void addLevel(int level) => fbBuilder.addInt8(3, level);
  void addThreadId(int threadId) => fbBuilder.addInt32(4, threadId);
  void addIsMainThread(int isMainThread) => fbBuilder.addUint8(5, isMainThread);
  void addTimestamp(int timestamp) => fbBuilder.addUint64(6, timestamp);

  int finish() {
    return fbBuilder.endTable();
  }
}
