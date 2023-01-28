import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
extension AsyncValueExtension<T> on AsyncValue<T> {
  Widget whenExtension<Widget>({
    bool skipLoadingOnReload = false,
    bool skipLoadingOnRefresh = true,
    bool skipError = false,
    Widget Function(Object error, StackTrace stackTrace)? error,
    Widget Function()? loading,
    Widget? Function(T data)? empty,
    required Widget Function(T data) data,
  }) {
    return when(
        data: (d){
         Widget? emptyWidget =  empty?.call(d);
         return emptyWidget ?? data.call(d);
        },
        error: error ??
            (Object error, StackTrace stackTrace) {
              return const SizedBox() as Widget;
            },
        loading: loading ??
            () {
              return const Center(
                      child: CupertinoActivityIndicator(color: Colors.white))
                  as Widget;
            });
  }
}
