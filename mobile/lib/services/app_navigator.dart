import 'package:flutter/material.dart';

class AppNavigator {
  static final rootKey = GlobalKey<NavigatorState>();

  static BuildContext? get context => rootKey.currentContext;
}
