import 'package:flutter/material.dart';

/// 简单用户状态管理（单例 ChangeNotifier）
/// Phase 1 使用本地模拟状态，Phase 2 对接 Supabase Auth
class UserStore extends ChangeNotifier {
  static final UserStore _instance = UserStore._();
  factory UserStore() => _instance;
  UserStore._();

  bool _isLoggedIn = false;
  String _nickname = '';
  int _avatarIndex = 0; // 0=粉蓝渐变 1=紫橙渐变 2=绿蓝渐变 3=自定义
  String _loginMethod = ''; // 'wechat' | 'qq' | 'phone'
  String _phone = '';
  int _aiCredits = 0;
  int _totalOutfits = 0;
  int _wishlistCount = 0;

  // ── Getters ──

  bool get isLoggedIn => _isLoggedIn;
  String get nickname => _nickname;
  int get avatarIndex => _avatarIndex;
  String get loginMethod => _loginMethod;
  String get phone => _phone;
  int get aiCredits => _aiCredits;
  int get totalOutfits => _totalOutfits;
  int get wishlistCount => _wishlistCount;

  String get displayPhone {
    if (_phone.isEmpty) return '';
    if (_phone.length == 11) {
      return '${_phone.substring(0, 3)}****${_phone.substring(7)}';
    }
    return _phone;
  }

  // ── 预设头像渐变 ──

  static const List<List<Color>> avatarGradients = [
    [Color(0xFFE8769B), Color(0xFF6EA8D9)], // 粉玫红 → 浅天蓝
    [Color(0xFFA18CD1), Color(0xFFFBC2EB)], // 紫罗兰 → 粉
    [Color(0xFF43E97B), Color(0xFF38F9D7)], // 绿 → 青
  ];

  List<Color> get avatarGradient => avatarGradients[_avatarIndex.clamp(0, avatarGradients.length - 1)];

  // ── Actions ──

  /// 微信登录
  void loginWithWechat() {
    _isLoggedIn = true;
    _loginMethod = 'wechat';
    _nickname = '微信用户';
    _avatarIndex = 0;
    _aiCredits = 0;
    notifyListeners();
  }

  /// QQ登录
  void loginWithQQ() {
    _isLoggedIn = true;
    _loginMethod = 'qq';
    _nickname = 'QQ用户';
    _avatarIndex = 1;
    _aiCredits = 0;
    notifyListeners();
  }

  /// 手机号登录
  void loginWithPhone(String phone) {
    _isLoggedIn = true;
    _loginMethod = 'phone';
    _phone = phone;
    _nickname = '用户$displayPhone';
    _avatarIndex = 2;
    _aiCredits = 0;
    notifyListeners();
  }

  /// 退出登录
  void logout() {
    _isLoggedIn = false;
    _nickname = '';
    _loginMethod = '';
    _phone = '';
    _avatarIndex = 0;
    _aiCredits = 0;
    _totalOutfits = 0;
    _wishlistCount = 0;
    notifyListeners();
  }

  /// 更新昵称
  void updateNickname(String name) {
    _nickname = name;
    notifyListeners();
  }

  /// 更新头像索引
  void updateAvatarIndex(int index) {
    _avatarIndex = index.clamp(0, avatarGradients.length - 1);
    notifyListeners();
  }
}
