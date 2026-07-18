import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_button.dart';

class RedeemPage extends StatefulWidget {
  const RedeemPage({super.key});

  @override
  State<RedeemPage> createState() => _RedeemPageState();
}

class _RedeemPageState extends State<RedeemPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入兑换码')),
      );
      return;
    }

    // TODO Phase 5+: 调用后端验证兑换码
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('兑换码 "$code" 验证中...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('兑换中心'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xl),
            // 图标
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.card_giftcard,
                size: 40,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('输入兑换码', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '关注我们的社交媒体账号获取免费兑换码',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            // 输入框
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              style: AppTextStyles.h2.copyWith(letterSpacing: 4),
              decoration: InputDecoration(
                hintText: '请输入兑换码',
                hintStyle: AppTextStyles.body.copyWith(color: AppColors.textPlaceholder),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // 兑换按钮
            AppButton(
              label: '立即兑换',
              onPressed: _onSubmit,
              icon: Icons.check,
            ),
            const SizedBox(height: AppSpacing.xl),
            // 获取兑换码提示
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('如何获取兑换码？', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.md),
                  _buildTip(Icons.play_circle_outline, '关注抖音/B站/小红书官方账号'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildTip(Icons.thumb_up_outlined, '参与官方活动与福利'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildTip(Icons.share_outlined, '分享 App 给好友'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: AppTextStyles.body)),
      ],
    );
  }
}
