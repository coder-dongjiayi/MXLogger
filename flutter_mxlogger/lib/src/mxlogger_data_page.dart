import 'package:flutter/material.dart';
class MXLoggerDataPage extends StatefulWidget {
  const MXLoggerDataPage({Key? key}) : super(key: key);

  @override
  _MXLoggerDataPageState createState() => _MXLoggerDataPageState();
}

class _MXLoggerDataPageState extends State<MXLoggerDataPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 200,
      color: Colors.red,
    );
  }
}
