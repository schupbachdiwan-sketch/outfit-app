import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/clothing_item.dart';
import '../fitting_room_store.dart';

/// 模特身上已穿衣物的可交互图层
///
/// 每个 [PlacedClothing] 对应一个 ClothLayerWidget，
/// 支持拖移位置、双指缩放、双指旋转。
///
/// 多层叠放时通过 [layerOrder] 决定 z 轴顺序。
class ClothLayerWidget extends StatefulWidget {
  final PlacedClothing cloth;
  final bool isSelected;
  final Size canvasSize;
  final ValueChanged<Offset>? onPositionChanged;
  final ValueChanged<double>? onScaleChanged;
  final ValueChanged<double>? onRotationChanged;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ClothLayerWidget({
    super.key,
    required this.cloth,
    required this.isSelected,
    required this.canvasSize,
    this.onPositionChanged,
    this.onScaleChanged,
    this.onRotationChanged,
    this.onTap,
    this.onDelete,
  });

  @override
  State<ClothLayerWidget> createState() => _ClothLayerWidgetState();
}

class _ClothLayerWidgetState extends State<ClothLayerWidget> {
  // 缩放+旋转组合手势的中间值
  double _baseScale = 1.0;
  double _baseRotation = 0.0;

  @override
  void initState() {
    super.initState();
    _baseScale = widget.cloth.scale;
    _baseRotation = widget.cloth.rotation;
  }

  @override
  void didUpdateWidget(covariant ClothLayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 同步外部状态变化
    if (oldWidget.cloth.scale != widget.cloth.scale) {
      _baseScale = widget.cloth.scale;
    }
    if (oldWidget.cloth.rotation != widget.cloth.rotation) {
      _baseRotation = widget.cloth.rotation;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloth = widget.cloth;
    final pos = cloth.position;
    final size = _clothDisplaySize();

    return Positioned(
      left: pos.dx - size.width / 2,
      top: pos.dy - size.height / 2,
      child: GestureDetector(
        onTap: widget.onTap,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: Transform.rotate(
          angle: cloth.rotation,
          child: Container(
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: widget.isSelected
                  ? Border.all(color: AppColors.primary, width: 2)
                  : Border.all(color: Colors.white.withAlpha(60), width: 1),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(60),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final cloth = widget.cloth;

    if (cloth.imageBytes != null && cloth.imageBytes!.isNotEmpty) {
      return Image.memory(
        cloth.imageBytes!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    final cloth = widget.cloth;
    return Container(
      color: cloth.color.withAlpha(160),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _iconForCategory(cloth.category),
            size: 18,
            color: Colors.white.withAlpha(200),
          ),
          const SizedBox(height: 2),
          Text(
            cloth.name,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(220),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 根据衣物类别计算默认显示尺寸
  Size _clothDisplaySize() {
    final cloth = widget.cloth;
    final baseW = 60.0;

    switch (cloth.category) {
      case ClothingCategory.top:
        return Size(baseW * cloth.scale, 50 * cloth.scale);
      case ClothingCategory.bottom:
        return Size(baseW * cloth.scale, 70 * cloth.scale);
      case ClothingCategory.dress:
        return Size(baseW * cloth.scale, 120 * cloth.scale);
      case ClothingCategory.outer:
        return Size(baseW * 1.2 * cloth.scale, 60 * cloth.scale);
      case ClothingCategory.shoes:
        return Size(30 * cloth.scale, 20 * cloth.scale);
      case ClothingCategory.accessory:
        return Size(25 * cloth.scale, 25 * cloth.scale);
    }
  }

  // ── 手势处理 ──

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = widget.cloth.scale;
    _baseRotation = widget.cloth.rotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final cloth = widget.cloth;

    // 单指拖移
    if (details.pointerCount == 1) {
      final movedPos = Offset(
        cloth.position.dx + details.focalPointDelta.dx,
        cloth.position.dy + details.focalPointDelta.dy,
      );
      widget.onPositionChanged?.call(movedPos);
      return;
    }

    // 双指缩放 + 旋转
    if (details.pointerCount >= 2) {
      final newScale = (_baseScale * details.scale).clamp(0.3, 2.5);
      widget.onScaleChanged?.call(newScale);

      if (details.rotation != 0.0) {
        final newRotation = _baseRotation + details.rotation;
        widget.onRotationChanged?.call(newRotation);
      }
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _baseScale = widget.cloth.scale;
    _baseRotation = widget.cloth.rotation;
  }

  IconData _iconForCategory(ClothingCategory cat) {
    return switch (cat) {
      ClothingCategory.top => Icons.checkroom,
      ClothingCategory.bottom => Icons.straighten,
      ClothingCategory.dress => Icons.woman,
      ClothingCategory.outer => Icons.shop,
      ClothingCategory.shoes => Icons.hiking,
      ClothingCategory.accessory => Icons.watch,
    };
  }
}

// 解决 ClothingCategory 在 cloth_layer_widget 中无法直接访问的问题
// ClothingCategory 定义在 clothing_item.dart 中，通过 fitting_room_store.dart 间接导入
// 因为 PlacedClothing 的 category 字段本身就是 ClothingCategory 类型
