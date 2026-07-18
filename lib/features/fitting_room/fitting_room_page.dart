import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/network/try_on_service.dart';
import '../../core/store/wardrobe_store.dart';
import '../../data/models/clothing_item.dart';
import '../../data/models/body_profile.dart';
import 'fitting_room_store.dart';
import 'widgets/body_template_painter.dart';
import 'widgets/step_indicator.dart';
import 'widgets/body_setup_sheet.dart';
import 'widgets/cloth_layer_widget.dart';
import 'widgets/ai_effect_dialog.dart';
import 'widgets/drag_wardrobe_shelf.dart' as shelf;

/// 试衣间主页面 — 四步流程
///
/// 1. 设定身体 → 2. 上传衣服(衣柜页) → 3. 拖拽穿搭 → 4. AI效果
class FittingRoomPage extends StatefulWidget {
  const FittingRoomPage({super.key});

  @override
  State<FittingRoomPage> createState() => _FittingRoomPageState();
}

class _FittingRoomPageState extends State<FittingRoomPage> {
  late final FittingRoomStore _store;
  final GlobalKey _canvasKey = GlobalKey();

  /// AI 试衣服服务（统一后端路由）
  late final TryOnService _tryOnService;

  /// 身体照片是否已经过 AI 模特化预处理
  bool _isBodyProcessed = false;

  /// 是否正在 AI 提取衣服
  bool _isExtractingCloth = false;

  /// API 客户端
  final ApiClient _apiClient = ApiClient();

  // ── 示例衣物（等 Phase 4 衣柜完成后替换）──
  static final List<ClothingItem> _sampleClothes = [
    ClothingItem(
      id: '1', name: '白衬衫', category: ClothingCategory.top,
      createdAt: DateTime.now(),
    ),
    ClothingItem(
      id: '2', name: '黑T恤', category: ClothingCategory.top,
      createdAt: DateTime.now(),
    ),
    ClothingItem(
      id: '3', name: '牛仔裤', category: ClothingCategory.bottom,
      createdAt: DateTime.now(),
    ),
    ClothingItem(
      id: '4', name: '黑西裤', category: ClothingCategory.bottom,
      createdAt: DateTime.now(),
    ),
    ClothingItem(
      id: '5', name: '碎花裙', category: ClothingCategory.dress,
      createdAt: DateTime.now(),
    ),
    ClothingItem(
      id: '6', name: '风衣', category: ClothingCategory.outer,
      createdAt: DateTime.now(),
    ),
    ClothingItem(
      id: '7', name: '牛仔夹克', category: ClothingCategory.outer,
      createdAt: DateTime.now(),
    ),
    ClothingItem(
      id: '8', name: '运动鞋', category: ClothingCategory.shoes,
      createdAt: DateTime.now(),
    ),
    ClothingItem(
      id: '9', name: '项链', category: ClothingCategory.accessory,
      createdAt: DateTime.now(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _store = FittingRoomStore();
    _store.setAvailableClothes(_sampleClothes);
    _tryOnService = TryOnService();
    _checkServer();
  }

  @override
  void dispose() {
    _store.dispose();
    _tryOnService.dispose();
    super.dispose();
  }

  Future<void> _checkServer() async {
    _store.setCheckingServer(true);
    try {
      final online = await _tryOnService.isBackendAvailable();
      _store.setServerOnline(online);
    } catch (_) {
      _store.setServerOnline(false);
    }
  }

  // ═══════════════════════════════════════
  //  UI 入口
  // ═══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── 画布区域（主视觉）──
          Expanded(child: _buildCanvas()),
          // ── 底部操作栏 ──
          _buildActionBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        '试衣间',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      ),
      centerTitle: true,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final completed = <int>{};
            if (_store.isBodySet) completed.add(1);
            if (_store.availableClothes.isNotEmpty) completed.add(2);
            if (_store.hasPlacedClothes) completed.add(3);
            if (_store.generatedImage != null) completed.add(4);

            return StepIndicator(
              currentStep: _store.activeStep,
              completedSteps: completed,
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  画布区域
  // ═══════════════════════════════════════

  Widget _buildCanvas() {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        return Container(
          key: _canvasKey,
          margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F3),
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: AppColors.border.withAlpha(80)),
          ),
          child: DragTarget<ClothingItem>(
            onAcceptWithDetails: (details) {
              _onClothDropped(details.data);
            },
            builder: (context, candidateData, rejectedData) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.large),
                child: Stack(
                  children: [
                    // ── AI 生成的模特图背景 ──
                    if (_store.bodyProfile.bodyPhotoBytes != null)
                      Positioned.fill(
                        child: Center(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Image.memory(
                                _store.bodyProfile.bodyPhotoBytes!,
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                fit: BoxFit.contain,
                                alignment: Alignment.center,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                              );
                            },
                          ),
                        ),
                      ),

                    // 身体模板（有模特图时只画衣物，无图时画骨架）
                    Positioned.fill(
                      child: CustomPaint(
                        painter: BodyTemplatePainter(
                          clothes: _store.placedClothes,
                          bodyProfile: _store.bodyProfile,
                        ),
                      ),
                    ),

                    // 已穿衣物的交互图层
                    ..._store.placedClothes.map((cloth) => ClothLayerWidget(
                      cloth: cloth,
                      isSelected: _store.selectedClothId == cloth.clothId,
                      canvasSize: _canvasSize,
                      onPositionChanged: (pos) => _store.updateClothPosition(cloth.clothId, pos),
                      onScaleChanged: (s) => _store.updateClothScale(cloth.clothId, s),
                      onRotationChanged: (r) => _store.updateClothRotation(cloth.clothId, r),
                      onTap: () => _store.selectCloth(
                        _store.selectedClothId == cloth.clothId ? null : cloth.clothId,
                      ),
                      onDelete: () => _store.removeCloth(cloth.clothId),
                    )),

                    // 拖拽高亮蒙版
                    if (candidateData.isNotEmpty)
                      Positioned.fill(
                        child: Container(
                          color: AppColors.primary.withAlpha(30),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 18, color: Colors.white),
                                SizedBox(width: 4),
                                Text('松手放置', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // 空态引导
                    if (!_store.isBodySet && _store.placedClothes.isEmpty)
                      _buildEmptyGuide(),

                    // 步骤1完成后的提示
                    if (_store.isBodySet && _store.placedClothes.isEmpty)
                      _buildStep3Hint(),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Size get _canvasSize {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size ?? const Size(360, 500);
  }

  /// 空态：未设定身体
  Widget _buildEmptyGuide() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.accessibility_new, size: 48, color: AppColors.textPlaceholder.withAlpha(140)),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              '请先设定身体数据',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '精准的身体数据能让试衣效果更真实',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withAlpha(180)),
            ),
          ],
        ),
      ),
    );
  }

  /// 已设定身体但未穿衣的提示
  Widget _buildStep3Hint() {
    return Positioned(
      top: AppSpacing.md,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: const Text(
              '👇 从下方衣柜长按拖到模特身上',
              style: TextStyle(fontSize: 12, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  //  底部操作栏
  // ═══════════════════════════════════════

  Widget _buildActionBar() {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 主要操作按钮行
              Row(
                children: [
                  // 设定身体 / 修改身体数据
                  Expanded(
                    child: _actionButton(
                      icon: _store.isBodySet ? Icons.edit : Icons.accessibility_new,
                      label: _store.isBodySet ? '修改身体' : '设定身体',
                      isPrimary: !_store.isBodySet,
                      onTap: _openBodySetup,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // 从衣柜选衣
                  Expanded(
                    child: _actionButton(
                      icon: Icons.inventory_2_outlined,
                      label: '从衣柜选衣',
                      isPrimary: _store.isBodySet && !_store.hasPlacedClothes,
                      enabled: _store.isBodySet,
                      onTap: _openWardrobe,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // 拍照添加衣服 + AI 抠图
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.add_a_photo,
                      label: _isExtractingCloth ? 'AI提取中...' : '拍照加衣',
                      isPrimary: false,
                      enabled: _store.isBodySet && !_isExtractingCloth,
                      onTap: _addClothByPhoto,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.save_alt_outlined,
                      label: '保存到衣柜',
                      isPrimary: false,
                      enabled: _store.hasPlacedClothes,
                      onTap: _saveToWardrobe,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // 辅助操作按钮行
              Row(
                children: [
                  _toolBtn(Icons.undo, '撤销', _store.hasPlacedClothes ? () => _store.undo() : null),
                  const SizedBox(width: 4),
                  _toolBtn(Icons.layers_clear, '清空', _store.hasPlacedClothes ? () => _showClearConfirm() : null),
                  const Spacer(),
                  // AI 生成按钮（主角）
                  Flexible(
                    child: ElevatedButton.icon(
                      onPressed: _store.hasPlacedClothes && !_store.isGenerating
                          ? _generateEffect
                          : null,
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('查看效果', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.border,
                        disabledForegroundColor: AppColors.textPlaceholder,
                        elevation: 0,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // 服务器状态
              if (!_store.serverOnline && !_store.checkingServer && _store.isBodySet)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, size: 12, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        'AI服务器未连接，部分功能不可用',
                        style: TextStyle(fontSize: 10, color: AppColors.warning.withAlpha(200)),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _checkServer,
                        child: const Text('重试', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool enabled = true,
  }) {
    return isPrimary
        ? ElevatedButton.icon(
            onPressed: enabled ? onTap : null,
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.border,
              disabledForegroundColor: AppColors.textPlaceholder,
              elevation: 0,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ),
          )
        : OutlinedButton.icon(
            onPressed: enabled ? onTap : null,
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: BorderSide(color: enabled ? AppColors.border : AppColors.border.withAlpha(100)),
              disabledForegroundColor: AppColors.textPlaceholder,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ),
          );
  }

  Widget _toolBtn(IconData icon, String label, VoidCallback? onTap) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: disabled ? AppColors.textPlaceholder : AppColors.textSecondary),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: disabled ? AppColors.textPlaceholder : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  操作逻辑
  // ═══════════════════════════════════════

  /// 步骤1：打开身体设定
  Future<void> _openBodySetup() async {
    final profile = await BodySetupSheet.show(context);
    if (profile != null && mounted) {
      setState(() {
        _store.setBodyProfile(profile);
        _isBodyProcessed = false;
      });

      // ── 拍照模式：AI 模特化预处理 ──
      if (profile.source == BodySource.photo && profile.bodyPhotoBytes != null) {
        _processBodyPhoto(profile);
      }

      // ── 手动模式：从身材数据 AI 生成模特图 ──
      if (profile.source == BodySource.manual) {
        _generateModelFromMeasurements(profile);
      }
    }
  }

  /// AI 模特化处理身体照片（拍照模式）
  Future<void> _processBodyPhoto(BodyProfile profile) async {
    if (!mounted) return;

    // 显示处理进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _ModelGenerationDialog(isPhotoMode: true),
    );

    try {
      // 直接使用 bodyPhotoBytes（Web 兼容：避免 dart:io File）
      final processedBytes = await _tryOnService.generateModel(
        profile.bodyPhotoBytes!,
        gender: profile.gender?.label,
        heightCm: profile.height,
        weightKg: profile.weight,
        onProgress: (progress, status) {
          // 进度通过 dialog 内部状态更新
        },
      );

      if (mounted) {
        Navigator.pop(context); // 关闭进度 dialog
        _store.setServerOnline(true); // 身体生图成功，说明代理在线
        final updatedProfile = _store.bodyProfile.copyWith(
          bodyPhotoBytes: processedBytes,
        );
        _store.setBodyProfile(updatedProfile);
        _isBodyProcessed = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI模特形象已生成'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _isBodyProcessed = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI处理失败: ${e.toString().replaceFirst("Exception: ", "")}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// 从身材数据 AI 生成模特图（手动输入模式）
  Future<void> _generateModelFromMeasurements(BodyProfile profile) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _ModelGenerationDialog(isPhotoMode: false),
    );

    try {
      final processedBytes = await _tryOnService.generateModelFromMeasurements(
        gender: profile.gender?.label ?? 'female',
        heightCm: profile.height ?? 165,
        weightKg: profile.weight ?? 55,
        bustCm: profile.bust ?? 86,
        waistCm: profile.waist ?? 68,
        hipCm: profile.hip ?? 90,
        onProgress: (progress, status) {},
      );

      if (mounted) {
        Navigator.pop(context);
        final updatedProfile = _store.bodyProfile.copyWith(
          bodyPhotoBytes: processedBytes,
        );
        _store.setBodyProfile(updatedProfile);
        _isBodyProcessed = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI已根据你的身材数据生成模特'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _isBodyProcessed = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI生成失败: ${e.toString().replaceFirst("Exception: ", "")}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// 打开可拖拽衣柜
  void _openWardrobe() {
    shelf.DragWardrobeShelf.show(context, clothes: _store.availableClothes);
  }

  /// 拖拽衣物放到画布上
  void _onClothDropped(ClothingItem item) {
    final canvasSize = _canvasSize;
    final defaultPos = Offset(canvasSize.width / 2, canvasSize.height * 0.35);

    setState(() {
      _store.addCloth(item, defaultPos);
    });
  }

  /// 步骤4：AI 生成效果（使用 TryOnService 统一路由）
  Future<void> _generateEffect() async {
    if (!mounted) return;

    // ── 前置检查：必须有身体照片 ──
    final bodyProfile = _store.bodyProfile;
    if (bodyProfile.source != BodySource.photo || bodyProfile.bodyPhotoBytes == null) {
      _showError('请先在步骤1中通过"拍照生成"模式上传身体照片，才能生成试穿效果');
      return;
    }

    // ── 前置检查：必须有已穿衣物的图片数据 ──
    final clothesWithImages = _store.placedClothes
        .where((c) => c.imageBytes != null && c.imageBytes!.isNotEmpty)
        .toList();
    if (clothesWithImages.isEmpty) {
      _showError('请先拖拽已AI处理过的衣物到模特身上（需含有图片数据）');
      return;
    }

    // ── 身体照片字节（Web 兼容：直接使用 Uint8List）──
    final bodyBytes = bodyProfile.bodyPhotoBytes;
    if (bodyBytes == null || bodyBytes.isEmpty) {
      _showError('身体照片数据缺失，请重新设定身体');
      return;
    }

    // ── 复检服务器状态 ──
    try {
      final online = await _tryOnService.isBackendAvailable();
      _store.setServerOnline(online);
      if (!online) {
        _showError('AI 代理服务器未连接，请确认已启动代理服务');
        return;
      }
    } catch (_) {
      _store.setServerOnline(false);
      _showError('AI 代理服务器未连接，请确认已启动代理服务');
      return;
    }

    // ── 启动生成流程 ──
    _store.startGeneration();
    AiEffectDialog.show(context, isGenerating: true, progress: 0.0);

    final stopwatch = Stopwatch()..start();

    try {
      // 收集所有有效衣物的字节数据
      final garments = <_GarmentData>[];
      for (final placed in clothesWithImages) {
        garments.add(_GarmentData(
          bytes: placed.imageBytes!,
          category: _toApiCategory(placed.category),
        ));
      }

      if (garments.isEmpty) {
        throw Exception('没有可用的衣物数据');
      }

      // ── 使用主衣物（最上层/最新放置的）调用试衣 ──
      final mainGarment = garments.last;

      final result = await _tryOnService.tryOnSingle(
        bodyImageBytes: bodyBytes,
        garmentImageBytes: mainGarment.bytes,
        category: mainGarment.category,
        preprocessBody: !_isBodyProcessed,
        onProgress: (progress, status) {
          if (mounted) {
            _store.updateGenerationProgress(progress);
          }
        },
      );

      stopwatch.stop();

      if (mounted) {
        Navigator.pop(context); // 关闭进度对话框
        _store.completeGeneration(result.imageBytes);

        if (mounted) {
          AiEffectDialog.show(
            context,
            isGenerating: false,
            progress: 1.0,
            resultImage: result.imageBytes,
            onSave: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已保存到"我的搭配"'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.success,
                ),
              );
            },
          );
        }
      }
    } on TryOnException catch (e) {
      if (mounted) {
        _store.failGeneration(e.message);
        Navigator.pop(context);
        AiEffectDialog.show(
          context,
          isGenerating: false,
          progress: 0.0,
          error: e.message,
          onRetry: _generateEffect,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        final msg = '${e.message} (HTTP ${e.statusCode})';
        _store.failGeneration(msg);
        Navigator.pop(context);
        AiEffectDialog.show(
          context,
          isGenerating: false,
          progress: 0.0,
          error: msg,
          onRetry: _generateEffect,
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = _formatError(e);
        _store.failGeneration(msg);
        Navigator.pop(context);
        AiEffectDialog.show(
          context,
          isGenerating: false,
          progress: 0.0,
          error: msg,
          onRetry: _generateEffect,
        );
      }
    }
  }

  void _showError(String msg) {
    AiEffectDialog.show(
      context,
      isGenerating: false,
      progress: 0.0,
      error: msg,
    );
  }

  String _formatError(Object e) {
    if (e is ApiException) return '${e.message} (HTTP ${e.statusCode})';
    if (e is TryOnException) return e.message;
    return e.toString().replaceFirst('Exception: ', '');
  }

  /// 将 ClothingCategory 映射为 API 所需的类别字符串
  String _toApiCategory(ClothingCategory cat) {
    switch (cat) {
      case ClothingCategory.top:
      case ClothingCategory.outer:
        return 'upper_body';
      case ClothingCategory.bottom:
        return 'lower_body';
      case ClothingCategory.dress:
        return 'dress';
      case ClothingCategory.shoes:
      case ClothingCategory.accessory:
        return 'upper_body'; // 默认归类到上半身
    }
  }

  /// 拍照加衣：选图 → AI抠图提取 → 选分类 → 放到画布
  Future<void> _addClothByPhoto() async {
    if (!mounted) return;

    // Step 1: 选图
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (xfile == null || !mounted) return;

    setState(() => _isExtractingCloth = true);

    // 显示处理弹窗
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ClothExtractDialog(),
      );
    }

    try {
      final rawBytes = await xfile.readAsBytes();

      // Step 2: AI 衣服增强（rembg去背景 + 白底合成 + Wan2.7产品图）
      final extractedBytes = await _apiClient.enhanceClothing(rawBytes);

      if (!mounted) return;

      // 关闭处理弹窗
      Navigator.pop(context);

      // Step 3: 选分类
      final category = await _showCategoryPickerDialog();
      if (category == null || !mounted) {
        setState(() => _isExtractingCloth = false);
        return;
      }

      // Step 4: 加入小衣柜，不直接放到模特身上
      final id = 'cloth_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}';
      final item = ClothingItem(
        id: id,
        name: _defaultNameForCategory(category),
        category: category,
        imageBytes: extractedBytes,
        isAiProcessed: true,
        source: ClothingSource.owned,
        createdAt: DateTime.now(),
      );

      _store.addAvailableCloth(item);

      // 只收入小衣柜，不自动放到画布上
      setState(() => _isExtractingCloth = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name}已提取并收入小衣柜'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: '保存',
              textColor: Colors.white,
              onPressed: _saveToWardrobe,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭处理弹窗
        setState(() => _isExtractingCloth = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI提取失败: ${e.toString().replaceFirst("Exception: ", "")}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// 将画布上的衣物保存到衣柜
  void _saveToWardrobe() {
    final wardrobeStore = WardrobeStore();
    int saved = 0;

    for (final placed in _store.placedClothes) {
      // 找到对应的 ClothingItem
      final item = _store.availableClothes.where((c) => c.id == placed.clothId).firstOrNull;
      if (item != null && item.imageBytes != null) {
        wardrobeStore.addItem(item);
        saved++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved > 0 ? '已保存 $saved 件衣物到衣柜' : '没有可保存的衣物（需先拍照加衣）'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: saved > 0 ? AppColors.success : AppColors.warning,
        ),
      );
    }
  }

  /// 选择衣物分类对话框
  Future<ClothingCategory?> _showCategoryPickerDialog() async {
    return showDialog<ClothingCategory>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择衣服类别', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _catOption(ctx, ClothingCategory.top, '👕 上衣', Icons.checkroom),
            const SizedBox(height: 4),
            _catOption(ctx, ClothingCategory.bottom, '👖 下装', Icons.straighten),
            const SizedBox(height: 4),
            _catOption(ctx, ClothingCategory.dress, '👗 连衣裙', Icons.woman),
            const SizedBox(height: 4),
            _catOption(ctx, ClothingCategory.outer, '🧥 外套', Icons.shop),
          ],
        ),
      ),
    );
  }

  Widget _catOption(BuildContext ctx, ClothingCategory cat, String label, IconData icon) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.pop(ctx, cat),
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 15)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.small)),
        ),
      ),
    );
  }

  String _defaultNameForCategory(ClothingCategory cat) {
    switch (cat) {
      case ClothingCategory.top: return '上衣';
      case ClothingCategory.bottom: return '裤子';
      case ClothingCategory.dress: return '连衣裙';
      case ClothingCategory.outer: return '外套';
      case ClothingCategory.shoes: return '鞋子';
      case ClothingCategory.accessory: return '配饰';
    }
  }

  void _showClearConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空画布'),
        content: const Text('确定要清除所有已穿上的衣物吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              _store.clearAll();
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

/// 内部数据结构：衣物的字节数据 + API 类别
class _GarmentData {
  final Uint8List bytes;
  final String category;
  const _GarmentData({required this.bytes, required this.category});
}

/// AI 模特形象生成进度对话框
class _ModelGenerationDialog extends StatefulWidget {
  const _ModelGenerationDialog({required this.isPhotoMode});
  final bool isPhotoMode;
  @override
  State<_ModelGenerationDialog> createState() => _ModelGenerationDialogState();
}

class _ModelGenerationDialogState extends State<_ModelGenerationDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md + 4),
            Text(
              widget.isPhotoMode ? 'AI正在生成你的模特形象' : 'AI正在根据身材数据生成模特',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.isPhotoMode ? '正在去除背景并优化姿态，请稍候...' : '正在根据你的身材比例生成人物形象，请稍候...',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary.withAlpha(200),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

/// AI 衣服提取进度对话框
class _ClothExtractDialog extends StatelessWidget {
  const _ClothExtractDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md + 4),
            const Text(
              'AI 正在提取衣服',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '正在识别并去除背景，提取衣服主体，请稍候...',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary.withAlpha(200),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
