import 'package:flutter/material.dart';

class AppRouter {
  AppRouter._();

  static const homeRoute = '/';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case homeRoute:
        return MaterialPageRoute(
          builder: (_) => const _PlaceholderPage(title: '穿搭助手'),
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

class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('欢迎使用穿搭助手')),
    );
  }
}
