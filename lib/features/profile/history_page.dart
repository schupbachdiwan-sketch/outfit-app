import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('历史记录'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              // TODO: 清除历史
            },
            child: Text('清除', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 分组标题
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
            child: Text('今天', style: AppTextStyles.small),
          ),
          _buildHistoryCard(
            icon: Icons.auto_awesome,
            iconColor: AppColors.primary,
            title: 'AI 虚拟试衣',
            subtitle: '白色衬衫 × 黑色西裤',
            detail: '消耗 1 次 · 14:32',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildHistoryCard(
            icon: Icons.checkroom,
            iconColor: const Color(0xFF48B8E0),
            title: '一键搭配',
            subtitle: '牛仔外套 → 推荐 3 套搭配',
            detail: '消耗 3 次 · 10:15',
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
            child: Text('昨天', style: AppTextStyles.small),
          ),
          _buildHistoryCard(
            icon: Icons.auto_awesome,
            iconColor: AppColors.primary,
            title: 'AI 虚拟试衣',
            subtitle: '碎花连衣裙 × 白色凉鞋',
            detail: '消耗 1 次 · 18:45',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildHistoryCard(
            icon: Icons.image_outlined,
            iconColor: const Color(0xFF4CAF93),
            title: 'AI 抠图',
            subtitle: '黑色毛衣 · 上传图片抠图',
            detail: '消耗 0 次（抠图免费）· 15:20',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildHistoryCard(
            icon: Icons.checkroom,
            iconColor: const Color(0xFF48B8E0),
            title: '一键搭配',
            subtitle: '卡其色风衣 → 推荐 4 套搭配',
            detail: '消耗 3 次 · 09:08',
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildHistoryCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String detail,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(22),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(detail, style: AppTextStyles.small.copyWith(color: AppColors.textPlaceholder)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textPlaceholder, size: 22),
        ],
      ),
    );
  }
}
