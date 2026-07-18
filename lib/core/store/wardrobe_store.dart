import 'package:flutter/material.dart';
import '../../data/models/clothing_item.dart';

/// 衣柜共享状态管理（单例）
///
/// 试衣间和衣柜页面通过此 Store 共享衣物数据。
class WardrobeStore extends ChangeNotifier {
  static final WardrobeStore _instance = WardrobeStore._();
  factory WardrobeStore() => _instance;
  WardrobeStore._();

  final List<ClothingItem> _items = [];
  List<ClothingItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.length;

  void addItem(ClothingItem item) {
    _items.add(item);
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  List<ClothingItem> getByCategory(ClothingCategory cat) {
    return _items.where((i) => i.category == cat).toList();
  }
}
