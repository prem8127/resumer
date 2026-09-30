import 'package:flutter/material.dart';

/// Pushes a [MaterialPageRoute] once: taps that arrive while the previous
/// push is still animating (or the route below is no longer current) are
/// ignored, so double-taps can't stack duplicate screens.
Future<T?> pushRouteOnce<T extends Object?>(
  BuildContext context,
  WidgetBuilder builder,
) {
  final route = ModalRoute.of(context);
  if (route != null && !route.isCurrent) {
    return Future<T?>.value();
  }
  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(builder: builder),
  );
}
