import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 一条过滤规则匹配的字段
enum FilterField {
  all,
  tag,
  name,
  msg,
}

extension FilterFieldExtension on FilterField {
  String get label {
    switch (this) {
      case FilterField.all:
        return "全部";
      case FilterField.tag:
        return "tag";
      case FilterField.name:
        return "name";
      case FilterField.msg:
        return "msg";
    }
  }

  /// 对应 mxlog 表中要匹配的列，全部字段时任一列命中即算命中
  List<String> get columns {
    switch (this) {
      case FilterField.all:
        return const ["msg", "tag", "name"];
      case FilterField.tag:
        return const ["tag"];
      case FilterField.name:
        return const ["name"];
      case FilterField.msg:
        return const ["msg"];
    }
  }

  static FilterField parse(String? value) {
    return FilterField.values.firstWhere((element) => element.name == value,
        orElse: () => FilterField.all);
  }
}

/// 白名单 / 黑名单里的一条规则。
///
/// [enabled] 表示这条规则当前是否参与过滤：条目添加后一直留在名单里，
/// 用户可以随时勾选 / 取消勾选，不用反复删了再加。
@immutable
class FilterRule {
  final String keyword;
  final FilterField field;
  final bool enabled;

  const FilterRule({
    required this.keyword,
    this.field = FilterField.all,
    this.enabled = true,
  });

  /// (字段, 关键词) 就是一条规则的身份，用来去重和做列表 key
  String get identity => "${field.name}:$keyword";

  FilterRule copyWith({bool? enabled}) => FilterRule(
        keyword: keyword,
        field: field,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() =>
      {"keyword": keyword, "field": field.name, "enabled": enabled};

  factory FilterRule.fromJson(Map<String, dynamic> json) => FilterRule(
        keyword: json["keyword"] as String? ?? "",
        field: FilterFieldExtension.parse(json["field"] as String?),
        enabled: json["enabled"] as bool? ?? true,
      );
}

@immutable
class AdvancedFilter {
  /// 只保留命中其中任意一条的日志
  final List<FilterRule> whitelist;

  /// 排除命中其中任意一条的日志
  final List<FilterRule> blacklist;

  const AdvancedFilter({this.whitelist = const [], this.blacklist = const []});

  int get enabledCount =>
      whitelist.where((e) => e.enabled).length +
      blacklist.where((e) => e.enabled).length;

  bool get isEmpty => whitelist.isEmpty && blacklist.isEmpty;

  /// 拼出 SQL 条件片段，没有任何启用中的规则时返回 null。
  ///
  /// 语义：`(命中任一白名单) and not (命中任一黑名单)`。
  /// 白名单为空表示不限制来源，黑名单为空表示不排除任何内容。
  String? get sqlCondition {
    final List<String> parts = [];
    final String? white = _matchAnyCondition(whitelist);
    final String? black = _matchAnyCondition(blacklist);
    if (white != null) parts.add(white);
    if (black != null) parts.add("not $black");
    if (parts.isEmpty) return null;
    return parts.join(" and ");
  }

  static String? _matchAnyCondition(List<FilterRule> rules) {
    final List<String> parts = [];
    for (final FilterRule rule in rules) {
      if (rule.enabled == false) continue;
      if (rule.keyword.isEmpty) continue;

      /// 关键词由用户输入，单引号要转义掉，否则会截断 SQL 语句
      final String keyword = rule.keyword.replaceAll("'", "''");
      for (final String column in rule.field.columns) {
        /// ifnull 兜底：字段为 NULL 时 like 结果也是 NULL，
        /// 取反后整行会被丢掉，黑名单会误伤没有该字段的日志
        parts.add("ifnull($column,'') like '%$keyword%'");
      }
    }
    if (parts.isEmpty) return null;
    return "(${parts.join(" or ")})";
  }

  AdvancedFilter copyWith({
    List<FilterRule>? whitelist,
    List<FilterRule>? blacklist,
  }) =>
      AdvancedFilter(
        whitelist: whitelist ?? this.whitelist,
        blacklist: blacklist ?? this.blacklist,
      );
}

/// 名单归属
enum FilterListType { white, black }

class AdvancedFilterState extends StateNotifier<AdvancedFilter> {
  AdvancedFilterState() : super(const AdvancedFilter()) {
    _restore();
  }

  static const String _storeKey = "com.dongjiayi.mxlogger.advancedFilter";

  List<FilterRule> _listOf(FilterListType type) =>
      type == FilterListType.white ? state.whitelist : state.blacklist;

  AdvancedFilter _replace(FilterListType type, List<FilterRule> rules) =>
      type == FilterListType.white
          ? state.copyWith(whitelist: rules)
          : state.copyWith(blacklist: rules);

  /// 添加一条规则。同字段同关键词的规则已存在时不重复添加，
  /// 只把它重新启用，避免用户以为没加上。
  void add(FilterListType type, {required String keyword, required FilterField field}) {
    final String trimmed = keyword.trim();
    if (trimmed.isEmpty) return;

    final FilterRule rule = FilterRule(keyword: trimmed, field: field);
    final List<FilterRule> rules = List.of(_listOf(type));
    final int index =
        rules.indexWhere((element) => element.identity == rule.identity);
    if (index >= 0) {
      rules[index] = rules[index].copyWith(enabled: true);
    } else {
      rules.add(rule);
    }
    state = _replace(type, rules);
    _persist();
  }

  void remove(FilterListType type, FilterRule rule) {
    final List<FilterRule> rules = List.of(_listOf(type))
      ..removeWhere((element) => element.identity == rule.identity);
    state = _replace(type, rules);
    _persist();
  }

  /// 勾选 / 取消勾选，条目本身保留
  void toggle(FilterListType type, FilterRule rule) {
    final List<FilterRule> rules = List.of(_listOf(type));
    final int index =
        rules.indexWhere((element) => element.identity == rule.identity);
    if (index < 0) return;
    rules[index] = rules[index].copyWith(enabled: !rules[index].enabled);
    state = _replace(type, rules);
    _persist();
  }

  /// 整个名单全选 / 全不选
  void toggleAll(FilterListType type, bool enabled) {
    final List<FilterRule> rules = _listOf(type)
        .map((element) => element.copyWith(enabled: enabled))
        .toList();
    state = _replace(type, rules);
    _persist();
  }

  void clear(FilterListType type) {
    state = _replace(type, const []);
    _persist();
  }

  void clearAll() {
    state = const AdvancedFilter();
    _persist();
  }

  Future<void> _restore() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? raw = preferences.getString(_storeKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final Map<String, dynamic> json = jsonDecode(raw);
      state = AdvancedFilter(
        whitelist: _decodeRules(json["whitelist"]),
        blacklist: _decodeRules(json["blacklist"]),
      );
    } catch (_) {
      /// 存档格式不认识就当没有，不影响使用
    }
  }

  List<FilterRule> _decodeRules(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(FilterRule.fromJson)
        .where((element) => element.keyword.isNotEmpty)
        .toList();
  }

  Future<void> _persist() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        _storeKey,
        jsonEncode({
          "whitelist": state.whitelist.map((e) => e.toJson()).toList(),
          "blacklist": state.blacklist.map((e) => e.toJson()).toList(),
        }));
  }
}

final advancedFilterProvider =
    StateNotifierProvider<AdvancedFilterState, AdvancedFilter>(
        (ref) => AdvancedFilterState());
