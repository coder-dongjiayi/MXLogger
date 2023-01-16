import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer_lib/src/component/mxlogger_text.dart';
import 'package:mxlogger_analyzer_lib/src/provider/mxlogger_provider.dart';

import 'package:mxlogger_analyzer_lib/src/page/lis_page/view/log_app_bar.dart';
import 'package:mxlogger_analyzer_lib/src/page/lis_page/view/log_listview.dart';
import 'package:mxlogger_analyzer_lib/src/extends/async_extends.dart';

import '../../theme/mx_theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../detail_page/mxlogger_detail_page.dart';

class LogListPage extends ConsumerStatefulWidget {
  const LogListPage({Key? key}) : super(key: key);

  @override
  LogListPageState createState() => LogListPageState();
}

class LogListPageState extends ConsumerState<LogListPage>
    with AutomaticKeepAliveClientMixin {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: MXTheme.themeColor,
      appBar: const LogAppBar(),
      body: Consumer(builder: (context, ref, _) {
        var config = ref.watch(logPagesProvider);
        bool sort = ref.read(sortTimeProvider);
        return config.whenExtension(
          empty: (list) {
            return list.isEmpty ? _empty() : null;
          },
          data: (list) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(top: 10, left: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MXLoggerText(
                          text: "共产生${list.length}条数据",
                          style:
                              TextStyle(color: MXTheme.subText, fontSize: 13)),

                      GestureDetector(
                        onTap: () {
                          ref.read(sortTimeProvider.notifier).state = !sort;
                        },
                        child: Container(
                          color: Colors.transparent,
                          padding: EdgeInsets.only(left: 30,right: 10),
                          child: Icon(Icons.swap_vert_rounded,
                            color: sort == true
                                ? MXTheme.subText
                                : MXTheme.buttonColor,size: 15,),
                        ),
                      )
                    ],
                  ),
                ),
                Expanded(
                    child: LogListView(
                  dataSource: list,
                  callback: (index) {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (context) {
                      return MXLoggerDetailPage(logModel: list[index]);
                    }));
                  },
                ))
              ],
            );
          },
        );
      }),
    );
  }

  Widget _empty() {
    bool dataEmpty = ref.read(emptyLogProvider);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            dataEmpty != true ? Icons.hourglass_empty : Icons.file_copy_sharp,
            size: 40,
            color: MXTheme.buttonColor,
          ),
          const SizedBox(height: 15),
          Text(
            dataEmpty != true ? "没有搜索到任何数据" : "拖拽日志文件到窗口",
            style: TextStyle(color: MXTheme.subText),
          )
        ],
      ),
    );
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;
}
