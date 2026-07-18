import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_button.dart';

class RechargePage extends StatelessWidget {
  const RechargePage({super.key});

  // 套餐数据
  static final List<_Package> _packages = [
    _Package(times: 10, price: 5, isPopular: false),
    _Package(times: 50, price: 20, isPopular: true),
    _Package(times: 100, price: 35, isPopular: false),
    _Package(times: 500, price: 150, isPopular: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI 生图充值'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 当前余额卡片
            _buildBalanceCard(),
            const SizedBox(height: AppSpacing.lg),
            // 套餐标题
            Text('选择充值套餐', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.sm),
            Text('次数永久有效，用完可继续购买', style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.md),
            // 套餐列表
            ..._packages.map((pkg) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _buildPackageCard(context, pkg),
            )),
            const SizedBox(height: AppSpacing.lg),
            // 价格声明
            _buildDisclaimer(),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  /// 当前余额
  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text('当前余额', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '0',
                style: AppTextStyles.h1.copyWith(fontSize: 48, height: 1),
              ),
              const SizedBox(width: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('次', style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 套餐卡片
  Widget _buildPackageCard(BuildContext context, _Package pkg) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: pkg.isPopular ? AppColors.primary : AppColors.border,
          width: pkg.isPopular ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // 套餐信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${pkg.times} 次',
                      style: AppTextStyles.h3,
                    ),
                    if (pkg.isPopular) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          '推荐',
                          style: AppTextStyles.small.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '¥${pkg.price}（约 ¥${(pkg.price / pkg.times).toStringAsFixed(2)}/次）',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          // 购买按钮
          AppButton(
            label: '¥${pkg.price}',
            onPressed: () {
              // TODO Phase 5+: 接入支付SDK
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('支付功能即将上线，敬请期待')),
              );
            },
            isFullWidth: false,
            variant: pkg.isPopular ? AppButtonVariant.primary : AppButtonVariant.secondary,
          ),
        ],
      ),
    );
  }

  /// 底部价格声明
  Widget _buildDisclaimer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '价格说明',
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '价格已包含平台服务费，平台不在 AI 费用上盈利。\n购买后次数永久有效，不支持退款。',
                  style: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 套餐数据模型
class _Package {
  final int times;
  final int price;
  final bool isPopular;

  const _Package({
    required this.times,
    required this.price,
    required this.isPopular,
  });
}
