import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

class OutfitApp extends StatelessWidget {
  const OutfitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '穿搭助手',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.homeRoute,
    );
  }
}
