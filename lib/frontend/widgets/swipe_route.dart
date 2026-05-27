import 'package:flutter/cupertino.dart';

class SwipeRoute<T> extends CupertinoPageRoute<T> {
  SwipeRoute({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  });
}

Future<T?> pushSwipeable<T>(
  BuildContext context,
  WidgetBuilder builder, {
  RouteSettings? settings,
}) {
  return Navigator.of(context).push<T>(
    SwipeRoute<T>(builder: builder, settings: settings),
  );
}
