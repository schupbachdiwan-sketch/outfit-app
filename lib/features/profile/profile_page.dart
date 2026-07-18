import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
import '../../core/store/user_store.dart';
import '../auth/login_page.dart';
import 'edit_profile_page.dart';
import 'recharge_page.dart';
import 'redeem_page.dart';
import 'my_outfits_page.dart';
import 'my_body_page.dart';
import 'wishlist_page.dart';
import 'history_page.dart';
import 'messages_page.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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

  Future<void> _openLoginPage() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    // result == true 表示登录成功，已通过 UserStore 更新状态
    if (result == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserCard(context),
            const SizedBox(height: AppSpacing.md),
            _buildAICreditCard(context),
            const SizedBox(height: AppSpacing.lg),
            _buildRecordsSection(context),
            const SizedBox(height: AppSpacing.lg),
            _buildMenuSection(context),
            const SizedBox(height: AppSpacing.xl),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  AppBar — 标题居中 + 右侧3个快捷图标
  // ═══════════════════════════════════════
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text(
        '我的',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      centerTitle: true,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      actions: [
        _buildAppBarIcon(
          icon: Icons.notifications_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MessagesPage()),
          ),
        ),
        _buildAppBarIcon(
          icon: Icons.style_outlined,
          onTap: () {
            // TODO: 皮肤/装扮中心
          },
        ),
        _buildAppBarIcon(
          icon: Icons.settings_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }

  Widget _buildAppBarIcon({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
        child: Icon(icon, size: 22, color: AppColors.textPrimary),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  用户信息卡片
  //  - 未登录：立即登录入口
  //  - 已登录：渐变头像 + 昵称 + VIP徽章
  // ═══════════════════════════════════════
  Widget _buildUserCard(BuildContext context) {
    if (!_store.isLoggedIn) {
      return _buildLoginEntry();
    }
    return _buildLoggedInUser();
  }

  /// 未登录状态 — 立即登录入口
  Widget _buildLoginEntry() {
    return GestureDetector(
      onTap: _openLoginPage,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            // 渐变头像
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFE8769B), Color(0xFF6EA8D9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.person, size: 28, color: Colors.white),
            ),
            const SizedBox(width: AppSpacing.md),
            // 登录提示
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '立即登录',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '登录后可使用全部功能',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // 箭头
            const Icon(Icons.chevron_right, color: AppColors.textPlaceholder),
          ],
        ),
      ),
    );
  }

  /// 已登录状态 — 头像 + 昵称 + VIP
  Widget _buildLoggedInUser() {
    final gradient = _store.avatarGradient;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          // 渐变头像
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfilePage()),
              );
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.person, size: 28, color: Colors.white),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // 用户名 + VIP 徽章
          Expanded(
            child: Row(
              children: [
                Text(
                  _store.nickname,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // VIP 徽章
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF3E0),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'V',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFD4A853),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      SizedBox(width: 2),
                      Text(
                        '会员',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8B7355),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 箭头 → 进入编辑资料
          const Icon(Icons.chevron_right, color: AppColors.textPlaceholder),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  //  AI生图余额渐变卡片 — 蓝紫渐变 + 三列布局
  // ═══════════════════════════════════════
  Widget _buildAICreditCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7EC8E3), Color(0xFF6C5CE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部引导文案 + 按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '解锁AI搭配权益',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                ),
              ),
              // 右上角小圆角按钮
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RechargePage()),
                  );
                },
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // 三列均分布局
          Row(
            children: [
              _buildCreditColumn(
                context,
                title: 'AI生图',
                subtitle: '0 次',
                onTap: null,
              ),
              _buildCreditColumn(
                context,
                title: '获取次数',
                subtitle: '充值',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RechargePage()),
                  );
                },
              ),
              _buildCreditColumn(
                context,
                title: '兑换中心',
                subtitle: '兑换',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RedeemPage()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreditColumn(
    BuildContext context, {
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  我的记录 — 标题 + 2张数据卡片
  // ═══════════════════════════════════════
  Widget _buildRecordsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: AppSpacing.sm + 4),
          child: Text(
            '我的记录',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildRecordCard(
                context,
                title: '我的搭配',
                detail: '',
                value: '0 套',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyOutfitsPage()),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildRecordCard(
                context,
                title: '心愿单',
                detail: '',
                value: '0 件',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WishlistPage()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecordCard(
    BuildContext context, {
    required String title,
    required String detail,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行 + 箭头
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            // 底部大数字
            Text(
              value,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  功能菜单 — 独立圆角卡片
  // ═══════════════════════════════════════
  Widget _buildMenuSection(BuildContext context) {
    final menuItems = [
      _MenuItem(
        icon: Icons.checkroom_outlined,
        title: '我的搭配',
        subtitle: '查看已保存的搭配方案',
        page: const MyOutfitsPage(),
      ),
      _MenuItem(
        icon: Icons.accessibility_new_outlined,
        title: '我的身材',
        subtitle: '管理身材模板',
        page: const MyBodyPage(),
      ),
      _MenuItem(
        icon: Icons.favorite_outline,
        title: '心愿单',
        subtitle: '收藏想买的单品',
        page: const WishlistPage(),
      ),
      _MenuItem(
        icon: Icons.schedule_outlined,
        title: '历史记录',
        subtitle: 'AI生图与搭配历史',
        page: const HistoryPage(),
      ),
    ];

    return Column(
      children: menuItems.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
          child: _buildMenuItem(context, item),
        );
      }).toList(),
    );
  }

  Widget _buildMenuItem(BuildContext context, _MenuItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => item.page),
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              // 左侧线性图标
              Icon(item.icon, size: 22, color: AppColors.textPrimary),
              const SizedBox(width: AppSpacing.md),
              // 标题 + 副标题
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 右侧灰色箭头
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textPlaceholder,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  底部
  // ═══════════════════════════════════════
  Widget _buildFooter() {
    return Column(
      children: [
        const Text(
          '价格已包含平台服务费，平台不在AI费用上盈利',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          '穿搭辅助 v1.0.0',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textPlaceholder,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  //  通用组件
  // ═══════════════════════════════════════

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.large),
    );
  }
}

/// 菜单项数据模型
class _MenuItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget page;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.page,
  });
}
