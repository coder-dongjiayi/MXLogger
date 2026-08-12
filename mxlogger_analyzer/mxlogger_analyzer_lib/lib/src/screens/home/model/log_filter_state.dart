import 'package:mxlogger_analyzer_lib/src/data/database/analyzer_database.dart';

const Object _unset = Object();

/// 日志过滤条件（对齐设计稿）：关键词 + 搜索范围 + 等级多选 +
/// #tag / @name 多选过滤（同类多值取「或」）+ 时间范围。
class LogFilterState {
  const LogFilterState({
    this.keyword = "",
    this.scope = MxSearchScope.all,
    this.levels = const <int>{},
    this.tags = const <String>[],
    this.names = const <String>[],
    this.fromUs,
    this.toUs,
  });

  final String keyword;
  final MxSearchScope scope;

  /// 空集合表示不过滤等级
  final Set<int> levels;

  /// 选中的 tag / name（各自多值取「或」；tags 与 names 之间取「与」）
  final List<String> tags;
  final List<String> names;
  final int? fromUs;
  final int? toUs;

  bool get timeActive => fromUs != null || toUs != null;

  bool get hasFilter =>
      keyword.isNotEmpty ||
      levels.isNotEmpty ||
      tags.isNotEmpty ||
      names.isNotEmpty ||
      timeActive;

  LogFilterState copyWith({
    String? keyword,
    MxSearchScope? scope,
    Set<int>? levels,
    List<String>? tags,
    List<String>? names,
    Object? fromUs = _unset,
    Object? toUs = _unset,
  }) {
    return LogFilterState(
      keyword: keyword ?? this.keyword,
      scope: scope ?? this.scope,
      levels: levels ?? this.levels,
      tags: tags ?? this.tags,
      names: names ?? this.names,
      fromUs: identical(fromUs, _unset) ? this.fromUs : fromUs as int?,
      toUs: identical(toUs, _unset) ? this.toUs : toUs as int?,
    );
  }

  LogFilterState toggleLevel(int level) {
    final Set<int> next = Set<int>.from(levels);
    if (next.contains(level)) {
      next.remove(level);
    } else {
      next.add(level);
    }
    return copyWith(levels: next);
  }

  /// tag 选中态切换（已选则移除），供日志卡片 #tag 点击复用
  LogFilterState toggleTag(String tag) {
    final List<String> next = List<String>.from(tags);
    if (next.contains(tag)) {
      next.remove(tag);
    } else {
      next.add(tag);
    }
    return copyWith(tags: next);
  }

  LogFilterState toggleName(String name) {
    final List<String> next = List<String>.from(names);
    if (next.contains(name)) {
      next.remove(name);
    } else {
      next.add(name);
    }
    return copyWith(names: next);
  }

  /// 追加（去重），供搜索框联想选中
  LogFilterState addTag(String tag) =>
      tags.contains(tag) ? this : copyWith(tags: [...tags, tag]);

  LogFilterState addName(String name) =>
      names.contains(name) ? this : copyWith(names: [...names, name]);

  LogFilterState removeTag(String tag) =>
      copyWith(tags: List<String>.from(tags)..remove(tag));

  LogFilterState removeName(String name) =>
      copyWith(names: List<String>.from(names)..remove(name));

  LogFilterState clearAll() => LogFilterState(scope: scope);

  LogQuery toQuery({int? limit, int? offset}) {
    return LogQuery(
      keyword: keyword,
      scope: scope,
      levels: levels.toList(),
      tags: tags,
      names: names,
      fromUs: fromUs,
      toUs: toUs,
      limit: limit,
      offset: offset,
    );
  }
}
