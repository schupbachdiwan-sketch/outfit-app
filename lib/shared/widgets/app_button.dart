import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

enum AppButtonVariant { primary, secondary }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
  });

  bool get _isDisabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final child = _buildChild();

    switch (variant) {
      case AppButtonVariant.primary:
        return SizedBox(
          width: isFullWidth ? double.infinity : null,
          height: 48,
          child: ElevatedButton(
            onPressed: _isDisabled ? null : onPressed,
            child: child,
          ),
        );
      case AppButtonVariant.secondary:
        return SizedBox(
          width: isFullWidth ? double.infinity : null,
          height: 48,
          child: OutlinedButton(
            onPressed: _isDisabled ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.small)),
              textStyle: AppTextStyles.h3,
            ),
            child: child,
          ),
        );
    }
  }

  Widget _buildChild() {
    if (isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnDark),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(label),
        ],
      );
    }

    return Text(label);
  }
}
