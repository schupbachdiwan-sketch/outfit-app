import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

/// AI 生成试穿效果对话框
///
/// 显示 AI 生成进度、结果展示、保存/分享操作。
///
/// 用法：
/// ```dart
/// final result = await AiEffectDialog.show(context, store);
/// ```
class AiEffectDialog extends StatelessWidget {
  final bool isGenerating;
  final double progress;
  final Uint8List? resultImage;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback? onSave;
  final VoidCallback? onShare;

  const AiEffectDialog({
    super.key,
    required this.isGenerating,
    this.progress = 0.0,
    this.resultImage,
    this.error,
    this.onRetry,
    this.onSave,
    this.onShare,
  });

  /// 弹出 AI 效果对话框
  static Future<void> show(
    BuildContext context, {
    required bool isGenerating,
    required double progress,
    Uint8List? resultImage,
    String? error,
    VoidCallback? onRetry,
    VoidCallback? onSave,
    VoidCallback? onShare,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AiEffectDialog(
        isGenerating: isGenerating,
        progress: progress,
        resultImage: resultImage,
        error: error,
        onRetry: onRetry,
        onSave: onSave,
        onShare: onShare,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.large + 4),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            _buildHeader(context),
            const SizedBox(height: AppSpacing.md),

            // 内容
            if (error != null)
              _buildError(context)
            else if (resultImage != null)
              _buildResult(context)
            else
              _buildGenerating(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.auto_awesome,
          size: 22,
          color: resultImage != null ? AppColors.success : AppColors.primary,
        ),
        const SizedBox(width: 8),
        Text(
          resultImage != null ? '试穿效果' : 'AI 生成中',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        if (resultImage != null || error != null)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
          ),
      ],
    );
  }

  /// 生成中：进度动画
  Widget _buildGenerating() {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: progress > 0 ? progress : null,
                  strokeWidth: 4,
                  color: AppColors.primary,
                  backgroundColor: AppColors.border,
                ),
              ),
              Icon(
                Icons.auto_awesome,
                size: 28,
                color: AppColors.primary.withAlpha(200),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'AI 正在生成试穿效果...',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary.withAlpha(220),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          progress > 0 ? '${(progress * 100).toInt()}%' : '正在连接 AI 服务',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        // 预估时间
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            '预计需要 10–30 秒，请耐心等待',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withAlpha(180)),
          ),
        ),
      ],
    );
  }

  /// 结果展示
  Widget _buildResult(BuildContext context) {
    return Column(
      children: [
        // 结果图
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: Image.memory(
            resultImage!,
            fit: BoxFit.contain,
            width: double.infinity,
            height: 300,
            errorBuilder: (_, __, ___) => Container(
              height: 200,
              color: AppColors.background,
              alignment: Alignment.center,
              child: const Text('图片加载失败', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // 操作按钮
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onSave ?? () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已保存到"我的搭配"'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
                icon: const Icon(Icons.save_alt_outlined, size: 18),
                label: const Text('保存'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onShare ?? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('分享功能将在后续版本上线'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('分享'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // 重新生成
        if (onRetry != null)
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onRetry!.call();
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重新生成'),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          ),
      ],
    );
  }

  /// 错误展示
  Widget _buildError(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.error.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.cloud_off, size: 32, color: AppColors.error),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          '生成失败',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary.withAlpha(200),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                ),
                child: const Text('关闭'),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onRetry!.call();
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('重试'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
