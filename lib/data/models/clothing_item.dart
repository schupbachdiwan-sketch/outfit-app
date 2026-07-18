import 'dart:typed_data';

/// 衣物分类
enum ClothingCategory {
  top('上衣'),
  bottom('下装'),
  dress('连衣裙'),
  outer('外套'),
  shoes('鞋子'),
  accessory('配饰');

  const ClothingCategory(this.label);
  final String label;
}

/// 衣物来源
enum ClothingSource {
  owned('自有'),
  wishlist('心愿单');

  const ClothingSource(this.label);
  final String label;
}

/// 衣物数据模型
///
/// 在衣柜和试衣间之间共享。
/// [imageBytes] 存储 AI 抠图后的透明 PNG。
class ClothingItem {
  final String id;
  final String name;
  final ClothingCategory category;
  final Uint8List? imageBytes;
  final String? imagePath;
  final bool isAiProcessed;
  final ClothingSource source;
  final DateTime createdAt;

  const ClothingItem({
    required this.id,
    required this.name,
    required this.category,
    this.imageBytes,
    this.imagePath,
    this.isAiProcessed = false,
    this.source = ClothingSource.owned,
    required this.createdAt,
  });

  /// 便捷创建：尚未 AI 处理的衣物
  factory ClothingItem.raw({
    required String id,
    required String name,
    required ClothingCategory category,
    required String imagePath,
    ClothingSource source = ClothingSource.owned,
  }) {
    return ClothingItem(
      id: id,
      name: name,
      category: category,
      imagePath: imagePath,
      isAiProcessed: false,
      source: source,
      createdAt: DateTime.now(),
    );
  }

  ClothingItem copyWith({
    String? id,
    String? name,
    ClothingCategory? category,
    Uint8List? imageBytes,
    String? imagePath,
    bool? isAiProcessed,
    ClothingSource? source,
    DateTime? createdAt,
    bool clearImageBytes = false,
  }) {
    return ClothingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      imageBytes: clearImageBytes ? null : (imageBytes ?? this.imageBytes),
      imagePath: imagePath ?? this.imagePath,
      isAiProcessed: isAiProcessed ?? this.isAiProcessed,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
