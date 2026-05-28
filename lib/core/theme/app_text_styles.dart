import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const _defaultColor = AppColors.textPrimary;

  static const h1 = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 32 / 24, color: _defaultColor);
  static const h2 = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 28 / 20, color: _defaultColor);
  static const h3 = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 24 / 16, color: _defaultColor);
  static const body = TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 22 / 15, color: _defaultColor);
  static const caption = TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 18 / 13, color: AppColors.textSecondary);
  static const small = TextStyle(fontSize: 11, fontWeight: FontWeight.w400, height: 16 / 11, color: AppColors.textSecondary);
}
