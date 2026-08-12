import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';

/// 回归：tag 列多 tag 用逗号分隔（如 "net,login"），必须拆成独立 tag，
/// 不能整体显示成一个 "#net,login"。
void main() {
  LogModel model(String? tag) => LogModel(level: 0, timestamp: 0, tag: tag);

  test("tags 按逗号/空格分词", () {
    expect(model("net,login").tags, ["net", "login"]);
    expect(model("net login").tags, ["net", "login"]);
    expect(model("a, b ,c").tags, ["a", "b", "c"]);
    expect(model("single").tags, ["single"]);
    expect(model("").tags, isEmpty);
    expect(model(null).tags, isEmpty);
  });

  test("分享文本多 tag 输出为 #a #b", () {
    expect(model("net,login").toShareText(), contains("#net #login"));
  });
}
