import 'package:flutter/material.dart';

/// Global navigation service for navigating from outside widget tree
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static NavigatorState? get navigator => navigatorKey.currentState;

  static Future<dynamic>? pushNamed(String routeName, {Object? arguments}) {
    return navigator?.pushNamed(routeName, arguments: arguments);
  }

  static void pop<T extends Object?>([T? result]) {
    navigator?.pop(result);
  }

  static Future<dynamic>? pushReplacementNamed(String routeName, {Object? arguments}) {
    return navigator?.pushReplacementNamed(routeName, arguments: arguments);
  }
}
