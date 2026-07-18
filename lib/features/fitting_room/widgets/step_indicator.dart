import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 四步进度指示器
///
/// 显示试衣间四步流程的当前进度：
///   1. 设定身体 → 2. 上传衣服 → 3. 拖拽穿搭 → 4. AI效果
///
/// [currentStep] 当前激活的步骤（1-4）。
/// [completedSteps] 已完成的步骤集合。
class StepIndicator extends StatelessWidget {
  final int currentStep;
  final Set<int> completedSteps;

  const StepIndicator({
    super.key,
    required this.currentStep,
    this.completedSteps = const {},
  });

  static const _steps = [
    _StepInfo(icon: Icons.accessibility_new, label: '身体'),
    _StepInfo(icon: Icons.add_a_photo, label: '衣服'),
    _StepInfo(icon: Icons.touch_app, label: '穿搭'),
    _StepInfo(icon: Icons.auto_awesome, label: '效果'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < _steps.length; i++) ...[
            _buildStep(i + 1, _steps[i]),
            if (i < _steps.length - 1) _buildConnector(i + 1),
          ],
        ],
      ),
    );
  }

  Widget _buildStep(int index, _StepInfo info) {
    final isActive = currentStep == index;
    final isCompleted = completedSteps.contains(index);
    final isPast = index < currentStep || isCompleted;

    final bgColor = isActive
        ? AppColors.primary
        : isPast
            ? AppColors.primary.withAlpha(200)
        : AppColors.border;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: isCompleted
              ? const Icon(Icons.check, size: 15, color: Colors.white)
              : Icon(
                  info.icon,
                  size: 15,
                  color: isPast || isActive ? Colors.white : AppColors.textPlaceholder,
                ),
        ),
        const SizedBox(height: 2),
        Text(
          info.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(int leftIndex) {
    final isPast = leftIndex < currentStep;
    return Container(
      width: 20,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: isPast ? AppColors.primary.withAlpha(150) : AppColors.border,
    );
  }
}

class _StepInfo {
  final IconData icon;
  final String label;
  const _StepInfo({required this.icon, required this.label});
}
