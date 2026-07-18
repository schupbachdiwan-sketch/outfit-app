import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('我的消息'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 消息列表（空态示例卡片）
          _buildMessageCard(
            icon: Icons.campaign_outlined,
            iconColor: const Color(0xFFFFB347),
            title: '系统通知',
            subtitle: '暂无新通知',
            time: '',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildMessageCard(
            icon: Icons.auto_awesome,
            iconColor: AppColors.primary,
            title: 'AI 额度提醒',
            subtitle: '你的 AI 生图余额已用尽，点击获取更多次数',
            time: '刚刚',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildMessageCard(
            icon: Icons.card_giftcard,
            iconColor: AppColors.accent,
            title: '兑换成功',
            subtitle: '兑换码 "FOLLOW2026" 已兑换 50 次 AI 生图',
            time: '2 小时前',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildMessageCard(
            icon: Icons.new_releases_outlined,
            iconColor: const Color(0xFF4CAF93),
            title: '新功能上线',
            subtitle: '虚拟试衣功能已上线，快来体验吧！',
            time: '1 天前',
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String time,
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                Row(
                  children: [
                    Expanded(child: Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600))),
                    if (time.isNotEmpty)
                      Text(time, style: AppTextStyles.small.copyWith(color: AppColors.textPlaceholder)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
