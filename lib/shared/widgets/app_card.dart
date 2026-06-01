import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

enum ClothingSource { owned, wishlist }

class AppCard extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final ClothingSource source;
  final String? category;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.name,
    this.imageUrl,
    this.source = ClothingSource.owned,
    this.category,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), offset: Offset(0, 2), blurRadius: 8),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xs),
                  _buildSourceTag(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        color: AppColors.background,
        child: imageUrl != null
            ? Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder())
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return const Center(child: Icon(Icons.checkroom, size: 40, color: AppColors.textPlaceholder));
  }

  Widget _buildSourceTag() {
    final isOwned = source == ClothingSource.owned;
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: isOwned ? AppColors.success : AppColors.warning,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(isOwned ? '衣橱' : '心愿', style: AppTextStyles.small),
      ],
    );
  }
}
