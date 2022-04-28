import 'package:flutter/material.dart';
import 'package:flutter_mxlogger/src/theme/mx_theme.dart';
class MXLoggerDetailPage extends StatefulWidget {
  const MXLoggerDetailPage({Key? key}) : super(key: key);

  @override
  _MXLoggerDetailPageState createState() => _MXLoggerDetailPageState();
}

class _MXLoggerDetailPageState extends State<MXLoggerDetailPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MXTheme.themeColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}

