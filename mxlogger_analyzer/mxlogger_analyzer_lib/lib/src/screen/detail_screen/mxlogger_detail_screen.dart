import 'dart:convert' as JSON;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';
import 'package:mxlogger_analyzer_lib/src/screen/detail_screen/view/flutter_json_viewer.dart';


import 'package:mxlogger_analyzer_lib/src/screen/home_screen/log_model.dart';
import 'package:share_plus/share_plus.dart';
import '../../level/mx_level.dart';
import '../../provider/mxlogger_provider.dart';
import '../../theme/mx_theme.dart';

class MXLoggerDetailScreen extends StatefulWidget {
  const MXLoggerDetailScreen({Key? key, required this.logModel})
      : super(key: key);
  final LogModel logModel;
  @override
  _MXLoggerDetailScreenState createState() => _MXLoggerDetailScreenState();
}

class _MXLoggerDetailScreenState extends State<MXLoggerDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MXTheme.themeColor,
      appBar: AppBar(
        elevation: 0,
        title: Text("MXAnalyzer", style: TextStyle(color: MXTheme.white)),
        backgroundColor: MXTheme.themeColor,
        leading: GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
          },
          child: Icon(Icons.arrow_back, color: MXTheme.white),
        ),
        actions: _actionList(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              level(widget.logModel.level),
              Expanded(child: name(widget.logModel.name)),
            ],
          ),
          tags(widget.logModel.tag),
          thread(
              "${widget.logModel.threadId}", widget.logModel.isMainThread == 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              time(widget.logModel.timestamp),
              GestureDetector(
                onTap: () {
                  _copyClipboard(context, widget.logModel.msg);
                },
                child: Icon(
                  Icons.copy,
                  color: MXTheme.subText,
                ),
              )
            ],
          ),
          const SizedBox(height: 10),
          message((widget.logModel.msg))
        ],
      ),
    );
  }

  List<Widget> _actionList() {
    List<Widget> source = [];
    if(analyzerPlatform != AnalyzerPlatform.desktop){
      source.add(  Padding(
          padding: const EdgeInsets.only(right: 20),
          child: GestureDetector(
            onTap: () {
              Share.share(widget.logModel.toString());
            },
            child: const Icon(Icons.ios_share, color: Colors.white),
          )));
    }
    if (widget.logModel.fileHeader != null) {
      source.add(Padding(
        padding: const EdgeInsets.only(right: 20),
        child: GestureDetector(
          onTap: () {
            showModalBottomSheet(
                context: context,
                builder: (context) {
                  return Container(
                    color: MXTheme.themeColor,
                    padding: const EdgeInsets.all(20),
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: SingleChildScrollView(
                      child: message(widget.logModel.fileHeader),
                    ),
                  );
                });
          },
          child: const Icon(
            Icons.info_outlined,
            color: Colors.white,
          ),
        ),
      ));
    }

    return source;
  }

  Widget name(String? name) {
    return Text("【$name】", style: TextStyle(color: MXTheme.text, fontSize: 18));
  }

  Widget tags(String? tags) {
    if (tags == null) return const SizedBox();
    List<String> tagList =
        tags.split(",").where((element) => element != "").toList();
    if (tagList.isEmpty) {
      return const SizedBox();
    }

    return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 10),
        child: Row(
          children: List.generate(tagList.length, (index) {
            return _tag(tagList[index]);
          }),
        ));
  }

  Widget level(int level) {
    return Text(levelName(level),
        style: TextStyle(
            color: MXTheme.colorLevel(level),
            fontWeight: FontWeight.w900,
            fontSize: 20));
  }

  Widget time(int timestamp) {
    DateTime time = DateTime.fromMicrosecondsSinceEpoch(timestamp);
    return Text("$time", style: TextStyle(color: MXTheme.text, fontSize: 17));
  }

  Widget thread(String? threadId, bool? isMain) {
    return Row(
      children: [
        Text("线程ID:$threadId",
            style: TextStyle(color: MXTheme.text, fontSize: 17)),
        const SizedBox(width: 10),
        Text(isMain == true ? "[main]" : "[child]",
            style: TextStyle(color: MXTheme.text, fontSize: 17))
      ],
    );
  }

  Widget _tag(String? tag) {
    if (tag == null || tag == "") return const SizedBox();
    return Container(
      decoration: BoxDecoration(
          color: MXTheme.tag,
          borderRadius: const BorderRadius.all(Radius.circular(5))),
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.fromLTRB(5, 2, 5, 4),
      child: Text(tag, style: TextStyle(color: MXTheme.text, fontSize: 12)),
    );
  }

  Widget message(String? msg) {

    var jsonMap = _verifyJson(msg);
    return SelectionArea(
        child: Container(
            width: MediaQuery.of(context).size.width,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            color: MXTheme.itemBackground,
            child: jsonMap != null
                ? JsonViewer(jsonMap)
                : Text(msg ?? "",
                    style: TextStyle(color: MXTheme.text, fontSize: 18))));
  }

  Map<String, dynamic>? _verifyJson(String? msg) {
    Map<String, dynamic>? jsonMap;
    try {
      jsonMap = JSON.jsonDecode(msg ?? "");
      return jsonMap;
    } catch (error) {
      return null;
    }
  }

  void _copyClipboard(BuildContext context, String? msg) {
    if (msg == null) return;
    Clipboard.setData(ClipboardData(text: msg));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: MXTheme.warn,
      content: Text(
        "内容已复制到剪切板",
        textAlign: TextAlign.center,
        style: TextStyle(color: MXTheme.white, fontSize: 18),
      ),
    ));
  }
}
