import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/body_profile.dart';
import 'manual_measure_form.dart';

/// 身体设定底部弹窗
///
/// 提供两种模式：
/// - 📷 拍照上传：选取全身照 → AI 生成标准站姿图
/// - 📐 手动输入：输入三围+身高体重
///
/// 用法：
/// ```dart
/// final profile = await BodySetupSheet.show(context);
/// if (profile != null) { ... }
/// ```
class BodySetupSheet {
  /// 弹出身体设定页面，返回用户选择的 [BodyProfile]，取消返回 null
  static Future<BodyProfile?> show(BuildContext context) {
    return showModalBottomSheet<BodyProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _BodySetupSheetContent(),
    );
  }
}

class _BodySetupSheetContent extends StatefulWidget {
  const _BodySetupSheetContent();

  @override
  State<_BodySetupSheetContent> createState() => _BodySetupSheetContentState();
}

class _BodySetupSheetContentState extends State<_BodySetupSheetContent> {
  int _mode = 0; // 0 = 拍照, 1 = 手动
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoName;
  Gender _photoGender = Gender.female;
  final _photoHeightCtrl = TextEditingController(text: '165');
  final _photoWeightCtrl = TextEditingController(text: '55');

  @override
  void dispose() {
    _photoHeightCtrl.dispose();
    _photoWeightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large + 4)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拖拽手柄
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 标题
          const Text(
            '设定我的身材',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '精准的身体数据能让试衣效果更真实',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withAlpha(200)),
          ),
          const SizedBox(height: AppSpacing.md),

          // 模式切换 Tabs
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                _modeTab(0, Icons.camera_alt_outlined, '拍照生成'),
                _modeTab(1, Icons.straighten, '手动输入'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 内容区域
          if (_mode == 0) _photoContent() else _manualContent(),
        ],
      ),
    );
  }

  Widget _modeTab(int index, IconData icon, String label) {
    final selected = _mode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.small),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 拍照内容区
  Widget _photoContent() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.border.withAlpha(120)),
        ),
        child: Column(
          children: [
            Icon(
              _selectedPhotoBytes != null ? Icons.check_circle : Icons.add_a_photo,
              size: 48,
              color: _selectedPhotoBytes != null ? AppColors.success : AppColors.textPlaceholder,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _selectedPhotoBytes != null ? '照片已选择' : '上传一张正面全身照',
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              '穿紧身衣拍摄效果更佳\nAI 将自动生成标准站姿模特图',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withAlpha(180)),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('相册'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _pickCamera,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('拍照'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                  ),
                ),
              ],
            ),
            if (_selectedPhotoBytes != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_selectedPhotoName ?? '照片',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.md),
              // 性别 + 身高 + 体重
              _buildPhotoMeasureForm(),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: _confirmPhotoMode,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('AI 生成模特图'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 拍照模式下的身体数据表单
  Widget _buildPhotoMeasureForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 性别
        Text(
          '补充身体数据（让 AI 生成更精准）',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary.withAlpha(200)),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: Gender.values.map((g) {
            final selected = _photoGender == g;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: g == Gender.male ? AppSpacing.xs : 0,
                  left: g == Gender.female ? AppSpacing.xs : 0,
                ),
                child: GestureDetector(
                  onTap: () => setState(() => _photoGender = g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        g.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.sm),
        // 身高 + 体重
        Row(
          children: [
            Expanded(child: _buildMeasureField('身高 (cm)', _photoHeightCtrl, 140, 200, 'cm')),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _buildMeasureField('体重 (kg)', _photoWeightCtrl, 40, 150, 'kg')),
          ],
        ),
      ],
    );
  }

  Widget _buildMeasureField(
    String label,
    TextEditingController controller,
    double min,
    double max,
    String unit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          decoration: InputDecoration(
            suffixText: unit,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
          ),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          validator: (v) {
            if (v == null || v.isEmpty) return '必填';
            final n = double.tryParse(v);
            if (n == null) return '无效';
            if (n < min || n > max) return '$min-$max';
            return null;
          },
        ),
      ],
    );
  }

  void _confirmPhotoMode() {
    final h = double.tryParse(_photoHeightCtrl.text);
    final w = double.tryParse(_photoWeightCtrl.text);
    if (h == null || w == null || h < 140 || h > 200 || w < 40 || w > 150) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入有效的身高（140-200cm）和体重（40-150kg）'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_selectedPhotoBytes == null) return;
    Navigator.pop(
      context,
      BodyProfile.photo(
        _selectedPhotoBytes!,
        gender: _photoGender,
        height: h,
        weight: w,
      ),
    );
  }

  /// 手动输入内容区
  Widget _manualContent() {
    return ManualMeasureForm(
      onCancel: () => Navigator.pop(context),
      onConfirm: (profile) => Navigator.pop(context, profile),
    );
  }

  Future<void> _pickGallery() async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      setState(() {
        _selectedPhotoBytes = bytes;
        _selectedPhotoName = xfile.name;
      });
    }
  }

  Future<void> _pickCamera() async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      setState(() {
        _selectedPhotoBytes = bytes;
        _selectedPhotoName = xfile.name;
      });
    }
  }
}
