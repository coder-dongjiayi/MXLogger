class LogModel {
  final String? name;
  final String? tag;
  final String? msg;
  final int level;
  final int? threadId;
  final int? isMainThread;
  final int timestamp;
  LogModel(
      {this.name,
      this.tag,
      this.msg,
      required this.level,
      this.threadId,
      this.isMainThread,
      required this.timestamp});

  @override
  String toString() {
    return "name:$name\ntag:$tag\nlevel:$level\nthreadId:$threadId\nisMainThread:$isMainThread\ntimestamp:$timestamp msg:$msg\n";
  }
}
