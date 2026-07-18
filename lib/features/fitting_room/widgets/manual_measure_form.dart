import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/body_profile.dart';

/// 手动输入三围 + 身高体重
///
/// 表单验证后返回 [BodyProfile.manual]。
class ManualMeasureForm extends StatefulWidget {
  final VoidCallback onCancel;
  final ValueChanged<BodyProfile> onConfirm;

  const ManualMeasureForm({
    super.key,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  State<ManualMeasureForm> createState() => _ManualMeasureFormState();
}

class _ManualMeasureFormState extends State<ManualMeasureForm> {
  final _formKey = GlobalKey<FormState>();
  final _heightCtrl = TextEditingController(text: '165');
  final _weightCtrl = TextEditingController(text: '55');
  final _bustCtrl = TextEditingController(text: '86');
  final _waistCtrl = TextEditingController(text: '68');
  final _hipCtrl = TextEditingController(text: '90');
  Gender _selectedGender = Gender.female;

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _bustCtrl.dispose();
    _waistCtrl.dispose();
    _hipCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final profile = BodyProfile.manual(
      gender: _selectedGender,
      height: double.parse(_heightCtrl.text),
      weight: double.parse(_weightCtrl.text),
      bust: double.parse(_bustCtrl.text),
      waist: double.parse(_waistCtrl.text),
      hip: double.parse(_hipCtrl.text),
    );
    widget.onConfirm(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              const Icon(Icons.straighten, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '输入身体数据',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.onCancel,
                child: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // 性别
          _buildGenderSelector(),
          const SizedBox(height: AppSpacing.md),
          // 身高体重
          Row(
            children: [
              Expanded(child: _buildField('身高 (cm)', _heightCtrl, 140, 200, 'cm')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _buildField('体重 (kg)', _weightCtrl, 40, 150, 'kg')),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // 三围
          Text(
            '三围数据',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary.withAlpha(200),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(child: _buildField('胸围', _bustCtrl, 70, 130, 'cm')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _buildField('腰围', _waistCtrl, 50, 120, 'cm')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _buildField('臀围', _hipCtrl, 70, 135, 'cm')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // 按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('确认应用'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '性别',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Row(
          children: Gender.values.map((g) {
            final selected = _selectedGender == g;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: g == Gender.male ? AppSpacing.xs : 0,
                  left: g == Gender.female ? AppSpacing.xs : 0,
                ),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedGender = g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
      ],
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    double min,
    double max,
    String unit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
          ],
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
            fillColor: AppColors.background,
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
}
