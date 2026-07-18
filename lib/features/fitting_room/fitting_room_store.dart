import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../data/models/clothing_item.dart';
import '../../data/models/body_profile.dart';

/// 已穿在模特身上的衣物（运行时状态）
///
/// 包含衣物的空间变换信息：位置、缩放、旋转、层级。
class PlacedClothing {
  final String clothId;
  final String name;
  final ClothingCategory category;
  final Color color;
  final Uint8List? imageBytes;

  /// 画布坐标系中的锚点（衣物的中心位置）
  Offset position;

  /// 缩放比例（0.3 ~ 2.5）
  double scale;

  /// 旋转角度（弧度）
  double rotation;

  /// z 轴层级（越大越靠前）
  int layerOrder;

  PlacedClothing({
    required this.clothId,
    required this.name,
    required this.category,
    required this.color,
    this.imageBytes,
    this.position = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.layerOrder = 0,
  });

  /// 从 ClothingItem 创建（初始位置由 category 决定默认分区）
  factory PlacedClothing.fromItem(ClothingItem item, {Offset? position}) {
    return PlacedClothing(
      clothId: item.id,
      name: item.name,
      category: item.category,
      color: _colorForCategory(item.category),
      imageBytes: item.imageBytes,
      position: position ?? Offset.zero,
    );
  }

  /// 按类别返回默认颜色
  static Color _colorForCategory(ClothingCategory cat) {
    switch (cat) {
      case ClothingCategory.top:    return const Color(0xFFF5F5F5);
      case ClothingCategory.bottom: return const Color(0xFF5B7DB1);
      case ClothingCategory.dress:  return const Color(0xFFFFB7C5);
      case ClothingCategory.outer:  return const Color(0xFFC8A882);
      case ClothingCategory.shoes:  return const Color(0xFF4A4A4A);
      case ClothingCategory.accessory: return const Color(0xFFFFD700);
    }
  }
}

/// 试衣间状态管理
///
/// 管理四步流程的全部状态：
/// 1. 身体设定 → 2. 衣柜准备(外部) → 3. 拖拽穿衣 → 4. AI生图
///
/// 作为页面的 State 的一部分，不使用全局单例
/// （因为 IndexedStack 会保持页面状态）。
class FittingRoomStore extends ChangeNotifier {
  // ── 身体设定（步骤 1）──
  BodyProfile _bodyProfile = BodyProfile.empty;
  BodyProfile get bodyProfile => _bodyProfile;
  bool get isBodySet => _bodyProfile.isSet;

  // ── 可用衣物（从衣柜读取）──
  List<ClothingItem> _availableClothes = [];
  List<ClothingItem> get availableClothes => List.unmodifiable(_availableClothes);

  // ── 已穿上的衣物（步骤 3）──
  final List<PlacedClothing> _placedClothes = [];
  List<PlacedClothing> get placedClothes => List.unmodifiable(_placedClothes);
  bool get hasPlacedClothes => _placedClothes.isNotEmpty;

  // ── AI 生成（步骤 4）──
  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  Uint8List? _generatedImage;
  Uint8List? get generatedImage => _generatedImage;

  String? _generationError;
  String? get generationError => _generationError;

  double _generationProgress = 0.0;
  double get generationProgress => _generationProgress;

  // ── 服务器状态 ──
  bool _serverOnline = false;
  bool get serverOnline => _serverOnline;

  bool _checkingServer = false;
  bool get checkingServer => _checkingServer;

  // ── 当前建议步骤（UI 引导用）──
  int _activeStep = 1;
  int get activeStep => _activeStep;

  // ═══════════════════════════════════════
  //  身体设定
  // ═══════════════════════════════════════

  void setBodyProfile(BodyProfile profile) {
    _bodyProfile = profile;
    _activeStep = _placedClothes.isEmpty ? 3 : 4;
    notifyListeners();
  }

  void clearBodyProfile() {
    _bodyProfile = BodyProfile.empty;
    _activeStep = 1;
    notifyListeners();
  }

  // ═══════════════════════════════════════
  //  可用衣物
  // ═══════════════════════════════════════

  void setAvailableClothes(List<ClothingItem> clothes) {
    _availableClothes = List.from(clothes);
    notifyListeners();
  }

  void addAvailableCloth(ClothingItem item) {
    _availableClothes.add(item);
    notifyListeners();
  }

  void removeAvailableCloth(String id) {
    _availableClothes.removeWhere((c) => c.id == id);
    // 同时从已穿列表移除
    _placedClothes.removeWhere((p) => p.clothId == id);
    notifyListeners();
  }

  // ═══════════════════════════════════════
  //  穿衣操作（步骤 3）
  // ═══════════════════════════════════════

  /// 拖拽放入一件衣物
  void addCloth(ClothingItem item, Offset canvasPosition) {
    final placed = PlacedClothing.fromItem(item, position: canvasPosition);
    placed.layerOrder = _placedClothes.length;
    _placedClothes.add(placed);
    _activeStep = 4;
    notifyListeners();
  }

  /// 更新衣物位置
  void updateClothPosition(String clothId, Offset newPosition) {
    final idx = _placedClothes.indexWhere((p) => p.clothId == clothId);
    if (idx == -1) return;
    _placedClothes[idx].position = newPosition;
    notifyListeners();
  }

  /// 更新衣物缩放
  void updateClothScale(String clothId, double newScale) {
    final idx = _placedClothes.indexWhere((p) => p.clothId == clothId);
    if (idx == -1) return;
    _placedClothes[idx].scale = newScale.clamp(0.3, 2.5);
    notifyListeners();
  }

  /// 更新衣物旋转
  void updateClothRotation(String clothId, double newRotation) {
    final idx = _placedClothes.indexWhere((p) => p.clothId == clothId);
    if (idx == -1) return;
    _placedClothes[idx].rotation = newRotation;
    notifyListeners();
  }

  /// 移除一件衣物
  void removeCloth(String clothId) {
    _placedClothes.removeWhere((p) => p.clothId == clothId);
    if (_placedClothes.isEmpty) {
      _activeStep = isBodySet ? 3 : 1;
    }
    notifyListeners();
  }

  /// 将衣物上移一层
  void bringForward(String clothId) {
    final idx = _placedClothes.indexWhere((p) => p.clothId == clothId);
    if (idx == -1 || idx >= _placedClothes.length - 1) return;
    final item = _placedClothes.removeAt(idx);
    item.layerOrder++;
    _placedClothes.insert(idx + 1, item);
    notifyListeners();
  }

  /// 将衣物下移一层
  void sendBackward(String clothId) {
    final idx = _placedClothes.indexWhere((p) => p.clothId == clothId);
    if (idx <= 0) return;
    final item = _placedClothes.removeAt(idx);
    item.layerOrder--;
    _placedClothes.insert(idx - 1, item);
    notifyListeners();
  }

  /// 撤销最后放入的衣物
  void undo() {
    if (_placedClothes.isNotEmpty) {
      _placedClothes.removeLast();
      if (_placedClothes.isEmpty) {
        _activeStep = isBodySet ? 3 : 1;
      }
      notifyListeners();
    }
  }

  /// 清空所有已穿衣物
  void clearAll() {
    if (_placedClothes.isEmpty) return;
    _placedClothes.clear();
    _activeStep = isBodySet ? 3 : 1;
    _generatedImage = null;
    _generationError = null;
    notifyListeners();
  }

  // ═══════════════════════════════════════
  //  选中状态（画布交互）
  // ═══════════════════════════════════════

  String? _selectedClothId;
  String? get selectedClothId => _selectedClothId;

  void selectCloth(String? clothId) {
    _selectedClothId = clothId;
    notifyListeners();
  }

  // ═══════════════════════════════════════
  //  AI 生成效果（步骤 4）
  // ═══════════════════════════════════════

  /// 标记开始生成
  void startGeneration() {
    _isGenerating = true;
    _generationProgress = 0.0;
    _generationError = null;
    _generatedImage = null;
    notifyListeners();
  }

  /// 更新生成进度
  void updateGenerationProgress(double progress) {
    _generationProgress = progress.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// 生成完成
  void completeGeneration(Uint8List image) {
    _isGenerating = false;
    _generationProgress = 1.0;
    _generatedImage = image;
    _generationError = null;
    notifyListeners();
  }

  /// 生成失败
  void failGeneration(String error) {
    _isGenerating = false;
    _generationError = error;
    notifyListeners();
  }

  // ═══════════════════════════════════════
  //  服务器状态
  // ═══════════════════════════════════════

  void setServerOnline(bool online) {
    _serverOnline = online;
    _checkingServer = false;
    notifyListeners();
  }

  void setCheckingServer(bool checking) {
    _checkingServer = checking;
    notifyListeners();
  }
}
