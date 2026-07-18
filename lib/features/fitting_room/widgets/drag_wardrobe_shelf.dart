import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/clothing_item.dart';

/// 可拖拽的衣柜架子
///
/// 显示在试衣间底部，支持：
/// - 分类 Tab 筛选
/// - 长按衣物 → 拖拽到画布
/// - DraggableScrollableSheet 展开/收起
class DragWardrobeShelf extends StatefulWidget {
  final List<ClothingItem> clothes;
  final int? activeTabIndex;
  final ValueChanged<int>? onTabChanged;
  final VoidCallback? onClose;

  const DragWardrobeShelf({
    super.key,
    required this.clothes,
    this.activeTabIndex,
    this.onTabChanged,
    this.onClose,
  });

  /// 从衣柜弹出可拖拽架子
  static Future<void> show(BuildContext context, {
    required List<ClothingItem> clothes,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        builder: (_, scrollController) {
          return _DragWardrobeSheetContent(
            clothes: clothes,
            scrollController: scrollController,
          );
        },
      ),
    );
  }

  @override
  State<DragWardrobeShelf> createState() => _DragWardrobeShelfState();
}

class _DragWardrobeShelfState extends State<DragWardrobeShelf> {
  static const _tabs = ['全部', '上衣', '下装', '连衣裙', '外套', '配饰'];
  static const _categories = [
    null,
    ClothingCategory.top,
    ClothingCategory.bottom,
    ClothingCategory.dress,
    ClothingCategory.outer,
    ClothingCategory.accessory,
  ];

  int _tabIndex = 0;

  List<ClothingItem> get _filtered {
    final cat = _categories[_tabIndex];
    if (cat == null) return widget.clothes;
    return widget.clothes.where((c) => c.category == cat).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 12, offset: const Offset(0, -2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽手柄
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 标题行
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
            child: Row(
              children: [
                const Text(
                  '衣柜',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '长按拖到模特身上',
                  style: TextStyle(fontSize: 11, color: AppColors.textPlaceholder.withAlpha(200)),
                ),
                const Spacer(),
                Text(
                  '${widget.clothes.length} 件',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // 分类 Tab
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) => _buildTab(i),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // 衣物拖拽列表
          Expanded(
            child: _buildClothesGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index) {
    final selected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          _tabs[index],
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildClothesGrid() {
    final items = _filtered;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checkroom, size: 32, color: AppColors.textPlaceholder.withAlpha(120)),
            const SizedBox(height: AppSpacing.xs),
            const Text('该分类暂无衣物', style: TextStyle(fontSize: 13, color: AppColors.textPlaceholder)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '去「衣柜」Tab 上传衣服吧',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withAlpha(150)),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: GridView.builder(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.85,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _buildDraggableCard(items[i]),
      ),
    );
  }

  Widget _buildDraggableCard(ClothingItem item) {
    final card = _ClothDragCard(item: item);

    return LongPressDraggable<ClothingItem>(
      data: item,
      delay: const Duration(milliseconds: 300),
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.85,
          child: Transform.scale(
            scale: 0.8,
            child: SizedBox(
              width: 90,
              height: 100,
              child: _ClothDragCard(item: item, compact: true),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: card,
      ),
      child: card,
    );
  }
}

/// 单个可拖拽衣物卡片
class _ClothDragCard extends StatelessWidget {
  final ClothingItem item;
  final bool compact;

  const _ClothDragCard({required this.item, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border.withAlpha(80)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 衣物图片或占位图标
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _colorForCategory(item.category).withAlpha(30),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: item.imageBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      child: Image.memory(item.imageBytes!, fit: BoxFit.contain),
                    )
                  : Icon(
                      _iconForCategory(item.category),
                      size: compact ? 24 : 30,
                      color: _colorForCategory(item.category).withAlpha(180),
                    ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, compact ? 4 : 8),
            child: Column(
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  item.category.label,
                  style: const TextStyle(fontSize: 9, color: AppColors.textPlaceholder),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForCategory(ClothingCategory cat) {
    switch (cat) {
      case ClothingCategory.top: return const Color(0xFF6C5CE7);
      case ClothingCategory.bottom: return const Color(0xFF5B7DB1);
      case ClothingCategory.dress: return const Color(0xFFFF6B6B);
      case ClothingCategory.outer: return const Color(0xFFC8A882);
      case ClothingCategory.shoes: return const Color(0xFF4A4A4A);
      case ClothingCategory.accessory: return const Color(0xFFFFD700);
    }
  }

  IconData _iconForCategory(ClothingCategory cat) {
    switch (cat) {
      case ClothingCategory.top: return Icons.checkroom;
      case ClothingCategory.bottom: return Icons.straighten;
      case ClothingCategory.dress: return Icons.woman;
      case ClothingCategory.outer: return Icons.shop;
      case ClothingCategory.shoes: return Icons.hiking;
      case ClothingCategory.accessory: return Icons.watch;
    }
  }
}

/// DraggableScrollableSheet 中使用的内部组件
class _DragWardrobeSheetContent extends StatefulWidget {
  final List<ClothingItem> clothes;
  final ScrollController scrollController;

  const _DragWardrobeSheetContent({
    required this.clothes,
    required this.scrollController,
  });

  @override
  State<_DragWardrobeSheetContent> createState() => _DragWardrobeSheetContentState();
}

class _DragWardrobeSheetContentState extends State<_DragWardrobeSheetContent> {
  static const _tabs = ['全部', '上衣', '下装', '连衣裙', '外套', '配饰'];
  static const _categories = [
    null,
    ClothingCategory.top,
    ClothingCategory.bottom,
    ClothingCategory.dress,
    ClothingCategory.outer,
    ClothingCategory.accessory,
  ];

  int _tabIndex = 0;

  List<ClothingItem> get _filtered {
    final cat = _categories[_tabIndex];
    if (cat == null) return widget.clothes;
    return widget.clothes.where((c) => c.category == cat).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large + 4)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
            child: Row(
              children: [
                const Text('衣柜', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(width: AppSpacing.xs),
                Text('长按拖到模特身上', style: TextStyle(fontSize: 11, color: AppColors.textPlaceholder.withAlpha(200))),
                const Spacer(),
                Text('${widget.clothes.length} 件', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) {
                final selected = _tabIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => _tabIndex = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      _tabs[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _buildGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checkroom, size: 36, color: AppColors.textPlaceholder.withAlpha(120)),
            const SizedBox(height: AppSpacing.xs),
            const Text('该分类暂无衣物', style: TextStyle(fontSize: 13, color: AppColors.textPlaceholder)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: GridView.builder(
        controller: widget.scrollController,
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.85,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          return LongPressDraggable<ClothingItem>(
            data: item,
            delay: const Duration(milliseconds: 300),
            feedback: Material(
              color: Colors.transparent,
              child: Opacity(
                opacity: 0.85,
                child: Transform.scale(
                  scale: 0.7,
                  child: SizedBox(
                    width: 90,
                    height: 100,
                    child: _ClothDragCard(item: item, compact: true),
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: _ClothDragCard(item: item)),
            child: _ClothDragCard(item: item),
          );
        },
      ),
    );
  }
}
