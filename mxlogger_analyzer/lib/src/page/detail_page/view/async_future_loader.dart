
import 'package:flutter/material.dart';

import 'package:flutter/cupertino.dart';


class AsyncController extends ChangeNotifier {

  void refresh() {
    notifyListeners();
  }
}

typedef AsyncBuilder<T> = Future<T> Function();

typedef ResultWidgetBuilder<T> = Widget? Function(
    BuildContext context, T? resultData);

typedef AsyncErrorWidgetBuilder = Widget Function(
    BuildContext context, Object? error);

typedef AsyncLoaderWidgetBuilder = Widget? Function(BuildContext context);

class AsyncFutureLoader<T> extends StatefulWidget {
  const AsyncFutureLoader(
      {Key? key,
      required this.asyncBuilder,
      required this.successWidgetBuilder,
      this.asyncController,
      this.emptyWidgetBuilder,
      this.errorWidgetBuilder,
      this.indicatorBuilder})
      : super(key: key);

  final AsyncController? asyncController;
  final AsyncBuilder<T> asyncBuilder;
  final ResultWidgetBuilder<T>? emptyWidgetBuilder;
  final ResultWidgetBuilder<T> successWidgetBuilder;
  final AsyncErrorWidgetBuilder? errorWidgetBuilder;
  final AsyncLoaderWidgetBuilder? indicatorBuilder;
  @override
  _AsyncFutureLoaderState<T> createState() => _AsyncFutureLoaderState<T>();
}

class _AsyncFutureLoaderState<T> extends State<AsyncFutureLoader<T>> {
  late Future<T> _future;

  Widget? _successCache;
  
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _future = widget.asyncBuilder();
    if (mounted == true && widget.asyncController != null) {
      widget.asyncController?.addListener(() {
        _reload();
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<T> snapshot) {
          if(snapshot.hasError == true){
            return _error(snapshot.error);
          }
          if (snapshot.connectionState == ConnectionState.done) {
            return _done(snapshot);
          }
          return _activityIndicator();
        });
  }

  void _reload() {
    _future = widget.asyncBuilder();
    if(mounted == true){
      setState(() {});
    }

  }

  Widget _done(AsyncSnapshot<T> snapshot) {
    if (widget.emptyWidgetBuilder != null ) {
      Widget? _emptyWidget =  widget.emptyWidgetBuilder!.call(context, snapshot.data);
      if(_emptyWidget != null){
        return  _emptyWidget;
      }
    }
    _successCache = widget.successWidgetBuilder.call(context, snapshot.data);
    return _successCache!;
  }

  Widget _error(Object? error) {
    if (widget.errorWidgetBuilder != null) {
      return widget.errorWidgetBuilder!.call(context, error);
    }

   return Center(
     child: FutureAsyncErrorWidget(reloadCallBack: (){
       _reload();
     }),
   );

  }

  Widget _activityIndicator() {
    if (_successCache != null) {
      return _successCache!;
    }

    if(widget.indicatorBuilder?.call(context) != null){
      return widget.indicatorBuilder!.call(context)!;
    }
    return const Center(
      child: CircularProgressIndicator(color: Colors.white,strokeWidth: 2)
    );

  }

}
class FutureAsyncErrorWidget extends StatelessWidget {
  FutureAsyncErrorWidget({this.reloadCallBack});

  final VoidCallback? reloadCallBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      color: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text("error")
          // Image.asset(
          //   Ast.cocoErrorEmpty,
          //   width: 260.sr,
          // ),
          // Container(
          //   margin: EdgeInsets.only(top: 20.sr),
          //   child: ShapeButton(
          //     title: KS.reload,
          //     width: 150.sr,
          //     onTap: () {
          //       if (reloadCallBack != null) {
          //         reloadCallBack!.call();
          //       }
          //     },
          //   ),
          // )
        ],
      ),
    );
  }
}
