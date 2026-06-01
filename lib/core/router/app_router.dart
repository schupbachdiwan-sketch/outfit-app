import 'package:flutter/material.dart';
import 'app_shell.dart';

class AppRouter {
  AppRouter._();

  static const homeRoute = '/';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case homeRoute:
        return MaterialPageRoute(
          builder: (_) => const AppShell(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(body: Center(child: Text('页面未找到'))),
          settings: settings,
        );
    }
  }
}
