import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer/src/component/mxlogger_text.dart';
import 'package:mxlogger_analyzer/src/extends/date_time_ext.dart';
import 'package:mxlogger_analyzer/src/extends/widget_ext.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/log_model.dart';
import 'package:mxlogger_analyzer/src/provider/mxlogger_provider.dart';

import 'package:mxlogger_analyzer/src/page/lis_page/view/log_app_bar.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/view/log_listview.dart';
import 'package:mxlogger_analyzer/src/extends/async_extends.dart';
import 'package:mxlogger_analyzer/src/util/date_util.dart';

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
    super.initState();
  }

  String startDateStr = "";
  String startTimeStr = "";
  int startTimestamp = 0;
  String endDateStr = "";
  String endTimeStr = "";
  int endTimestamp = 0;

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
            List<LogModel> filter = [];
            filter.addAll(list);

            filter.retainWhere((log) {
              if (startTimestamp > 0 && startTimestamp < endTimestamp) {
                if (log.timestamp / 1000 < startTimestamp) {
                  return false;
                }
              }
              if (endTimestamp > 0 && startTimestamp < endTimestamp) {
                if (log.timestamp / 1000 > endTimestamp) {
                  return false;
                }
              }
              return true;
            });
            debugPrint(
                "LogListPage  filter:${filter.length}========list:${list.length}==========================");

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
                  child: Wrap(
                    children: [
                      MXLoggerText(
                        text: "共产生${list.length}条数据",
                        style: TextStyle(color: MXTheme.subText, fontSize: 13),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          MXLoggerText(
                            text: "选择过滤时间范围：",
                            style:
                                TextStyle(color: MXTheme.subText, fontSize: 13),
                          ),

                          ///开始日期
                          GestureDetector(
                            onTap: () async {
                              DateTime? result = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now()
                                      .subtract(const Duration(days: 30)),
                                  lastDate: DateTime.now());
                              if (result != null) {
                                startDateStr = result.formatDateLogTimeYMD;
                                startTimestamp = DateUtil.getDateMsByTimeStr(
                                        "$startDateStr $startTimeStr") ??
                                    0;
                                setState(() {});
                              }
                            },
                            child: MXLoggerText(
                              text: startDateStr,
                              style: TextStyle(
                                  color: MXTheme.subText,
                                  fontSize: 13,
                                  height: 1),
                            ).decorationEx(
                                bgColor: MXTheme.dropTargetColor,
                                width: 90,
                                margin: const EdgeInsets.only(right: 5)),
                          ),

                          ///开始日期 时间
                          GestureDetector(
                            onTap: () async {
                              TimeOfDay? result = await showTimePicker(
                                context: context,
                                initialTime:
                                    const TimeOfDay(hour: 0, minute: 0),
                              );
                              if (result != null) {
                                startTimeStr = result.formatDateLogTimeHMS;
                                startTimestamp = DateUtil.getDateMsByTimeStr(
                                        "$startDateStr $startTimeStr") ??
                                    0;
                                setState(() {});
                              }
                            },
                            child: MXLoggerText(
                              text: startTimeStr,
                              style: TextStyle(
                                  color: MXTheme.subText,
                                  fontSize: 13,
                                  height: 1),
                            ).decorationEx(
                                bgColor: MXTheme.dropTargetColor,
                                width: 70,
                                radius: 5),
                          ),

                          MXLoggerText(
                            text: "到",
                            style: TextStyle(
                                color: MXTheme.subText,
                                fontSize: 13,
                                height: 1),
                          ).pOnly(left: 5, right: 5),

                          ///结束日期
                          GestureDetector(
                            onTap: () async {
                              DateTime? result = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 30),
                                  ),
                                  lastDate: DateTime.now());
                              if (result != null) {
                                endDateStr = result.formatDateLogTimeYMD;
                                endTimestamp = DateUtil.getDateMsByTimeStr(
                                        "$endDateStr $endTimeStr") ??
                                    0;
                                setState(() {});
                              }
                            },
                            child: MXLoggerText(
                              text: endDateStr,
                              style: TextStyle(
                                  color: MXTheme.subText,
                                  fontSize: 13,
                                  height: 1),
                            ).decorationEx(
                              bgColor: MXTheme.dropTargetColor,
                              width: 90,
                              margin: const EdgeInsets.only(right: 5),
                            ),
                          ),

                          ///结束日期 时间
                          GestureDetector(
                            onTap: () async {
                              TimeOfDay? result = await showTimePicker(
                                context: context,
                                initialEntryMode: TimePickerEntryMode.input,
                                initialTime:
                                    const TimeOfDay(hour: 0, minute: 0),
                              );
                              if (result != null) {
                                endTimeStr = result.formatDateLogTimeHMS;
                                endTimestamp = DateUtil.getDateMsByTimeStr(
                                        "$endDateStr $endTimeStr") ??
                                    0;
                                setState(() {});
                              }
                            },
                            child: MXLoggerText(
                              text: endTimeStr,
                              style: TextStyle(
                                  color: MXTheme.subText,
                                  fontSize: 13,
                                  height: 1),
                            ).decorationEx(
                              bgColor: MXTheme.dropTargetColor,
                              width: 70,
                              radius: 5,
                            ),
                          ),

                          ///清除按钮
                          GestureDetector(
                            onTap: () async {
                              startDateStr = "";
                              startTimeStr = "";
                              startTimestamp = 0;
                              endDateStr = "";
                              endTimeStr = "";
                              endTimestamp = 0;
                              setState(() {});
                            },
                            child: Icon(
                              Icons.delete,
                              color: startTimestamp < endTimestamp &&
                                      filter.isNotEmpty
                                  ? MXTheme.tag
                                  : MXTheme.buttonColor,
                              size: 15,
                            ),
                          ).mOnly(right: 10, left: 10),
                          if (startTimestamp < endTimestamp &&
                              filter.isNotEmpty)
                            MXLoggerText(
                              text: "当前查询到${filter.length}条数据",
                              style: TextStyle(
                                  color: MXTheme.subText, fontSize: 13),
                            ),
                          Expanded(child: Container()),
                          GestureDetector(
                            onTap: () {
                              ref.read(sortTimeProvider.notifier).state = !sort;
                            },
                            child: Icon(
                              Icons.swap_vert_rounded,
                              color: sort == true
                                  ? MXTheme.subText
                                  : MXTheme.buttonColor,
                              size: 15,
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                    child: LogListView(
                  dataSource: filter,
                  callback: (index) {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (context) {
                      return MXLoggerDetailPage(logModel: filter[index]);
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
