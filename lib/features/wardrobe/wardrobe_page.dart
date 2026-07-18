import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/store/wardrobe_store.dart';
import '../../data/models/clothing_item.dart';

/// 衣柜页面 — 共享 WardrobeStore
///
/// 与试衣间通过 [WardrobeStore] 共享衣物数据。
class WardrobePage extends StatefulWidget {
  const WardrobePage({super.key});

  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  final WardrobeStore _wardrobeStore = WardrobeStore();
  bool _isProcessing = false;
  String? _errorMessage;

  static const _categories = [
    ClothingCategory.top,
    ClothingCategory.bottom,
    ClothingCategory.dress,
    ClothingCategory.outer,
    ClothingCategory.shoes,
    ClothingCategory.accessory,
  ];

  int _selectedCatIndex = 0;

  List<ClothingItem> get _clothes => _wardrobeStore.items;

  List<ClothingItem> get _filtered {
    final cat = _categories[_selectedCatIndex];
    return _clothes.where((c) => c.category == cat).toList();
  }

  @override
  void initState() {
    super.initState();
    _wardrobeStore.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _wardrobeStore.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '衣柜',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isProcessing ? null : _addCloth,
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            tooltip: '添加衣物',
          ),
        ],
      ),
      body: _clothes.isEmpty && !_isProcessing ? _buildEmptyState() : _buildContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(AppRadius.large),
            ),
            child: const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            '衣柜还是空的',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '点击右上角 + 添加你的第一件衣服',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withAlpha(200)),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: _addCloth,
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text('拍照添加'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(25),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 14, color: AppColors.error),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 11, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // 分类 Tab
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, i) {
              final selected = _selectedCatIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedCatIndex = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                  ),
                  child: Text(
                    _categories[i].label,
                    style: TextStyle(
                      fontSize: 13,
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

        // 衣物网格
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Text(
                    '暂无${_categories[_selectedCatIndex].label}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textPlaceholder),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _buildClothCard(_filtered[i]),
                  ),
                ),
        ),

        // 处理中提示
        if (_isProcessing)
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            color: AppColors.primaryLight,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: AppSpacing.sm),
                Text('AI 正在抠图中...', style: TextStyle(fontSize: 13, color: AppColors.primary)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildClothCard(ClothingItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border.withAlpha(80)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: item.imageBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      child: Image.memory(item.imageBytes!, fit: BoxFit.contain),
                    )
                  : item.isAiProcessed
                      ? Icon(Icons.auto_awesome, size: 24, color: AppColors.primary.withAlpha(120))
                      : Icon(Icons.checkroom, size: 24, color: AppColors.textPlaceholder.withAlpha(120)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Column(
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 1),
                Text(
                  item.isAiProcessed ? '已处理' : '未处理',
                  style: TextStyle(
                    fontSize: 9,
                    color: item.isAiProcessed ? AppColors.success : AppColors.textPlaceholder,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  //  添加衣物（拍照 → AI抠图）
  // ═══════════════════════════════════════

  Future<void> _addCloth() async {
    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final xfile = await picker.pickImage(source: source, imageQuality: 90);
    if (xfile == null) return;

    final rawBytes = await xfile.readAsBytes();

    // 询问分类和名称
    final info = await _showAddClothDialog();
    if (info == null || !mounted) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // 调用 AI 增强（rembg抠图 → 白底合成 → Wan2.7 电商产品图）
      final client = ApiClient();
      Uint8List? processedBytes;

      try {
        final online = await client.healthCheck();
        if (online) {
          processedBytes = await client.enhanceClothing(rawBytes);
        }
      } catch (_) {
        // AI 服务不可用，保存原始图片
      }

      client.dispose();

      final item = ClothingItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: info['name']!,
        category: info['category']!,
        imageBytes: processedBytes ?? rawBytes,
        isAiProcessed: processedBytes != null,
        source: ClothingSource.owned,
        createdAt: DateTime.now(),
      );

      _wardrobeStore.addItem(item);

      setState(() {
        _isProcessing = false;
      });

      if (processedBytes == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI 服务未连接，衣物已保存原始图片'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<Map<String, dynamic>?> _showAddClothDialog() {
    final nameCtrl = TextEditingController(text: '新衣服');
    ClothingCategory selectedCat = _categories[_selectedCatIndex];

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('添加衣物'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '给这件衣服取个名字',
                ),
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<ClothingCategory>(
                initialValue: selectedCat,
                decoration: const InputDecoration(labelText: '分类'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedCat = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, {
                'name': nameCtrl.text.isNotEmpty ? nameCtrl.text : '未命名',
                'category': selectedCat,
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }
}
