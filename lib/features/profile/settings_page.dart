import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
import '../../core/store/user_store.dart';
import 'edit_profile_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _store = UserStore();

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _onLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出后不会清除本地数据\n下次登录仍可恢复'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              _store.logout();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已退出登录'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // ── 账号设置组 ──
          _buildSection(
            title: '账号',
            items: [
              _buildItem(
                icon: Icons.person_outline,
                title: '个人资料',
                trailing: _store.isLoggedIn ? _store.nickname : '未登录',
                onTap: () {
                  if (!_store.isLoggedIn) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请先登录')),
                    );
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EditProfilePage()),
                  );
                },
              ),
              _buildItem(
                icon: Icons.lock_outline,
                title: '修改密码',
                trailing: _store.isLoggedIn ? '' : null,
                onTap: () {
                  if (!_store.isLoggedIn) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('修改密码功能将在后续版本上线')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── 通用设置组 ──
          _buildSection(
            title: '通用',
            items: [
              _buildItem(
                icon: Icons.notifications_outlined,
                title: '通知设置',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('通知设置将在后续版本上线')),
                  );
                },
              ),
              _buildItem(
                icon: Icons.delete_outline,
                title: '清除缓存',
                trailing: '0 MB',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('缓存已清除')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── 关于组 ──
          _buildSection(
            title: '关于',
            items: [
              _buildItem(
                icon: Icons.info_outline,
                title: '关于我们',
                onTap: () {
                  _showAboutDialog();
                },
              ),
              _buildItem(
                icon: Icons.description_outlined,
                title: '隐私政策',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('隐私政策页面')),
                  );
                },
              ),
              _buildItem(
                icon: Icons.article_outlined,
                title: '用户协议',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('用户协议页面')),
                  );
                },
              ),
            ],
          ),

          // ── 退出登录 ──
          if (_store.isLoggedIn) ...[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _onLogout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                ),
                child: const Text('退出登录', style: TextStyle(fontSize: 15)),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Column(
              children: [
                Text(
                  '穿搭辅助 v1.0.0',
                  style: TextStyle(fontSize: 13, color: AppColors.textPlaceholder),
                ),
                const SizedBox(height: 4),
                Text(
                  'Made with ♥ by OutfitApp Dev',
                  style: TextStyle(fontSize: 11, color: AppColors.textPlaceholder),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: '穿搭助手',
      applicationVersion: 'v1.0.0',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFFE8769B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: const Icon(Icons.checkroom, size: 28, color: Colors.white),
      ),
      children: [
        const Text('一款面向年轻用户的2D平面风格穿搭辅助App，支持虚拟试衣、AI智能搭配推荐和虚拟衣柜管理。'),
      ],
    );
  }

  // ── 复用组件 ──

  Widget _buildSection({required String title, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.large),
          ),
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildItem({
    required IconData icon,
    required String title,
    String? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md + 2,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textPrimary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right, color: AppColors.textPlaceholder, size: 20),
          ],
        ),
      ),
    );
  }
}
