import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';
import 'package:mxlogger_analyzer_lib/src/provider/mxlogger_provider.dart';
import 'package:mxlogger_analyzer_lib/src/screen/home_screen/search_dialog.dart';
import 'package:mxlogger_analyzer_lib/src/screen/home_screen/widget/home_log_list_view.dart';
import 'package:mxlogger_analyzer_lib/src/screen/home_screen/widget/search_app_bar.dart';
import 'package:mxlogger_analyzer_lib/src/screen/home_screen/widget/search_result_wrap.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key, this.menuCallback, this.refreshCallback})
      : super(key: key);
  final VoidCallback? menuCallback;
  final VoidCallback? refreshCallback;
  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MXTheme.themeColor,
      appBar: SearchAppBar(
        menuCallback: widget.menuCallback,
        onLevelCallback: (list) {
          ref.read(mxLogDataSourceProvider.notifier).levelSearch(levels: list);
        },
        onSearch: () {
          showSearchDialog(context,
              margin: const EdgeInsets.only(left: 70, right: 70),
              onCondition: (result) {
            ref
                .read(mxLogDataSourceProvider.notifier)
                .search(searchState: result.key, value: result.value);
          });
        },
      ),
      body: Consumer(builder: (context, ref, child) {
        final asyncData = ref.watch(mxLogDataSourceProvider);
        return asyncData.when(
            data: (result) {
              if (result.isSearch == false &&
                  result.dataSource.isEmpty == true) {
                return _empty(isSearch: false);
              }

              String timeRang = "";
              if (result.dataSource.isNotEmpty) {
                int first = result.dataSource.first.timestamp;
                int last = result.dataSource.last.timestamp;
                int f = first < last ? first : last;
                int l = last > first ? last : first;

                DateTime firstTime = DateTime.fromMicrosecondsSinceEpoch(f);
                DateTime lastTime = DateTime.fromMicrosecondsSinceEpoch(l);
                String firstString = firstTime.toString().split(".").first;
                String lastString = lastTime.toString().split(".").first;
                timeRang = " $firstString 至 $lastString";
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(
                      left: 10,
                    ),
                    child: SearchResultWrap(
                      onChange: (searchState) {
                        ref
                            .read(mxLogDataSourceProvider.notifier)
                            .deleteSearch(searchState: searchState);
                      },
                    ),
                  ),
                  Container(
                    margin:
                        const EdgeInsets.only(top: 10, left: 10, bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: MXLoggerText(
                            text: "共产生${result.dataSource.length}条数据 $timeRang",
                            style: TextStyle(
                                color: MXTheme.subText, fontSize: 13))),
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
                  result.dataSource.isEmpty == true
                      ? Expanded(child: _empty(isSearch: true))
                      : Expanded(
                          child: HomeLogListView(
                          dataSource: result.dataSource,
                        ))
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

  Widget _empty({bool? isSearch}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: () {
              widget.refreshCallback?.call();
            },
            child: Icon(
              isSearch == true ? Icons.hourglass_empty : _initIconData(),
              size: 40,
              color: MXTheme.buttonColor,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            isSearch == true ? "没有搜索到任何数据" : _initText(),
            style: TextStyle(color: MXTheme.subText),
          )
        ],
      ),
    );
  }

  IconData _initIconData() {
    if (analyzerPlatform == AnalyzerPlatform.desktop) {
      return Icons.file_copy_sharp;
    }
    return Icons.refresh;
  }

  String _initText() {
    if (analyzerPlatform == AnalyzerPlatform.desktop) {
      return "拖拽日志文件到窗口";
    }
    return "点击以导入日志数据";
  }
}
