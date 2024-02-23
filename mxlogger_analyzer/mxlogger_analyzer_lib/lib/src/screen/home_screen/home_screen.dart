import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';
import 'package:mxlogger_analyzer_lib/src/page/lis_page/log_model.dart';
import 'package:mxlogger_analyzer_lib/src/provider/mxlogger_provider.dart';
import 'package:mxlogger_analyzer_lib/src/screen/home_screen/search_dialog.dart';
import 'package:mxlogger_analyzer_lib/src/screen/home_screen/widget/search_app_bar.dart';
import 'package:mxlogger_analyzer_lib/src/screen/home_screen/widget/search_result_wrap.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MXTheme.themeColor,
      appBar: SearchAppBar(
        onLevelCallback: (list) {
          ref.read(mxLogDataSourceProvider.notifier).levelSearch(levels: list);
        },
        onSearch: () {
          showSearchDialog(context, onCondition: (result) {
            ref
                .read(mxLogDataSourceProvider.notifier)
                .conditionSearch(searchState: result.key, value: result.value);
          });
        },
      ),
      body: Consumer(builder: (context, ref, child) {
        final asyncData = ref.watch(mxLogDataSourceProvider);
        return asyncData.when(
            data: (list) {

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(left: 10,top: 10),
                    child: SearchResultWrap(
                    ),
                  ),
                  Container(
                    margin:
                        const EdgeInsets.only(top: 10, left: 10, bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        MXLoggerText(
                            text: "共产生${list.length}条数据",
                            style: TextStyle(
                                color: MXTheme.subText, fontSize: 13)),
                        GestureDetector(
                          onTap: () {
                            ref
                                .read(mxLogDataSourceProvider.notifier)
                                .sortSearch();
                          },
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.only(left: 30, right: 10),
                            child: Icon(
                              Icons.swap_vert_rounded,
                              color: ref
                                          .read(
                                              mxLogDataSourceProvider.notifier)
                                          .sort ==
                                      true
                                  ? MXTheme.subText
                                  : MXTheme.buttonColor,
                              size: 15,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  Expanded(
                      child: ListView.builder(
                          itemCount: list.length,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            LogModel log = list[index];
                            DateTime time = DateTime.fromMicrosecondsSinceEpoch(
                                log.timestamp);
                            return GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                      MaterialPageRoute(builder: (context) {
                                    return MXLoggerDetailPage(logModel: log);
                                  }));
                                },
                                child: Container(
                                  padding:
                                      const EdgeInsets.fromLTRB(10, 0, 10, 0),
                                  color: index % 2 == 0
                                      ? MXTheme.themeColor
                                      : MXTheme.itemBackground,
                                  child: _item(
                                      name: log.name ?? "",
                                      msg: log.msg ?? "",
                                      level: log.level,
                                      time: time.toString(),
                                      tag: log.tag),
                                ));
                          }))
                ],
              );
            },
            error: (Object error, StackTrace stackTrace) {
              return const SizedBox();
            },
            loading: () => const Center(
                child: CupertinoActivityIndicator(color: Colors.white)));
      }),
    );
  }

  Widget _item(
      {required String name,
      required String msg,
      required int level,
      required String time,
      String? tag}) {
    List<String>? tagList = tag?.split(",");

    return Stack(
      children: [
        Container(
            margin: const EdgeInsets.only(left: 20),
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(time,
                        style: TextStyle(color: MXTheme.subText, fontSize: 13)),
                    Expanded(
                        child: Text("【$name】",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: MXTheme.subText, fontSize: 13)))
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: List.generate(tagList?.length ?? 0, (index) {
                    return _tag(tagList?[index]);
                  }),
                ),
                const SizedBox(height: 5),
                Text(
                  msg,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: MXTheme.text, fontSize: 16),
                ),
              ],
            )),
        Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 3),
              decoration: BoxDecoration(
                  color: MXTheme.colorLevel(level),
                  borderRadius: const BorderRadius.all(Radius.circular(5))),
            )),
        Positioned(
            left: 4,
            top: 10 + 3,
            bottom: 0,
            width: 2,
            child: Container(
              decoration: BoxDecoration(
                  color: MXTheme.itemBackground,
                  borderRadius: const BorderRadius.all(Radius.circular(3))),
            ))
      ],
    );
  }

  Widget _tag(String? tag) {
    if (tag == null || tag == "") return SizedBox();
    return Container(
      decoration: BoxDecoration(
          color: MXTheme.tag,
          borderRadius: BorderRadius.all(Radius.circular(5))),
      margin: EdgeInsets.only(right: 10),
      padding: EdgeInsets.fromLTRB(5, 2, 5, 4),
      child: Text(tag, style: TextStyle(color: MXTheme.text, fontSize: 12)),
    );
  }
}
