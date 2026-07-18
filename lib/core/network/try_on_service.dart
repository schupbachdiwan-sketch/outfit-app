import 'dart:typed_data';

import 'api_client.dart';

/// 虚拟试衣结果
class TryOnResult {
  TryOnResult({required this.imageBytes, required this.backend, this.elapsedMs});
  final Uint8List imageBytes;
  final String backend;
  final int? elapsedMs;
}

/// 虚拟试衣服服务
///
/// 编排 AI 试衣流程：
///   本地图片 → 代理服务器 → DashScope OSS 上传 → 异步试衣 API → 轮询 → 返回结果
///
/// 当前版本要求本地运行代理服务器（API Key 不暴露到客户端）。
/// DashScope 所有试衣 API 均需要公网 URL，本地图片必须通过代理中转上传。
class TryOnService {
  TryOnService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  bool? _cachedProxyOnline;
  DateTime? _lastHealthCheck;

  /// 代理服务器是否在线（带 30s 缓存）
  Future<bool> isProxyOnline() async {
    if (_cachedProxyOnline != null && _lastHealthCheck != null) {
      if (DateTime.now().difference(_lastHealthCheck!) < const Duration(seconds: 30)) {
        return _cachedProxyOnline!;
      }
    }
    try {
      _cachedProxyOnline = await _apiClient.healthCheck();
    } catch (_) {
      _cachedProxyOnline = false;
    }
    _lastHealthCheck = DateTime.now();
    return _cachedProxyOnline!;
  }

  /// 后端是否可用（目前仅代理服务器）
  Future<bool> isBackendAvailable() => isProxyOnline();

  void clearCache() {
    _cachedProxyOnline = null;
    _lastHealthCheck = null;
  }

  // ═══════════════════════════════════════
  //  身体照片 AI 模特化
  // ═══════════════════════════════════════

  /// 将用户身体照片转化为干净模特风格图（拍照模式）
  ///
  /// 流水线：rembg 去背景 → Wan2.7 姿态优化 → 返回干净模特照
  /// [imageBytes] 用户全身照片
  /// [gender] 性别 ("男"/"女")
  /// [heightCm] 身高 cm
  /// [weightKg] 体重 kg
  /// [onProgress] 进度回调 (0.0~1.0)
  Future<Uint8List> generateModel(
    Uint8List imageBytes, {
    String? gender,
    double? heightCm,
    double? weightKg,
    void Function(double progress, String status)? onProgress,
  }) async {
    if (!await isProxyOnline()) {
      throw TryOnException(_proxyOfflineMessage);
    }

    onProgress?.call(0.1, '连接代理服务器...');
    onProgress?.call(0.2, 'AI正在去除背景...');
    onProgress?.call(0.5, 'AI正在生成模特形象...');

    try {
      final result = await _apiClient.generateModel(
        imageBytes,
        gender: gender,
        heightCm: heightCm,
        weightKg: weightKg,
      );

      onProgress?.call(1.0, '模特形象生成完成');
      return result;
    } on ApiException catch (e) {
      throw TryOnException('${e.message} (HTTP ${e.statusCode})');
    }
  }

  /// 从身材数据 AI 生成模特图（手动输入模式，无照片）
  ///
  /// 使用 Wan2.7 文生图从测量数据生成人物形象。
  /// [gender] 性别 ("男"/"女")
  /// [heightCm] 身高 cm
  /// [weightKg] 体重 kg
  /// [bustCm] 胸围 cm
  /// [waistCm] 腰围 cm
  /// [hipCm] 臀围 cm
  /// [onProgress] 进度回调 (0.0~1.0)
  Future<Uint8List> generateModelFromMeasurements({
    required String gender,
    required double heightCm,
    required double weightKg,
    required double bustCm,
    required double waistCm,
    required double hipCm,
    void Function(double progress, String status)? onProgress,
  }) async {
    if (!await isProxyOnline()) {
      throw TryOnException(_proxyOfflineMessage);
    }

    onProgress?.call(0.1, '连接代理服务器...');
    onProgress?.call(0.3, 'AI正在根据身材数据生成人物...');

    try {
      final result = await _apiClient.generateModel(
        null, // 无图片，纯文生图
        gender: gender,
        heightCm: heightCm,
        weightKg: weightKg,
        bustCm: bustCm,
        waistCm: waistCm,
        hipCm: hipCm,
      );

      onProgress?.call(1.0, '模特形象生成完成');
      return result;
    } on ApiException catch (e) {
      throw TryOnException('${e.message} (HTTP ${e.statusCode})');
    }
  }

  // ═══════════════════════════════════════
  //  单件衣物试衣
  // ═══════════════════════════════════════

  /// 提交试衣请求
  ///
  /// 通过代理服务器完成：[可选:身体预处理]→上传→OSS→AI→返回。
  /// [bodyImageBytes] 用户身体照片
  /// [garmentImageBytes] 衣物照片（建议已抠图）
  /// [category] 衣物类别: upper_body | lower_body | dress
  /// [preprocessBody] 是否先对 body 做 AI 模特化预处理
  /// [onProgress] 进度回调 (0.0~1.0)
  Future<TryOnResult> tryOnSingle({
    required Uint8List bodyImageBytes,
    required Uint8List garmentImageBytes,
    String category = 'upper_body',
    bool preprocessBody = false,
    void Function(double progress, String status)? onProgress,
  }) async {
    if (!await isProxyOnline()) {
      throw TryOnException(_proxyOfflineMessage);
    }

    final stopwatch = Stopwatch()..start();
    double baseProgress = 0.0;
    var effectiveBodyBytes = bodyImageBytes;

    if (preprocessBody) {
      onProgress?.call(0.05, 'AI正在处理身体照片...');
      // 进度 0.0~0.30 分配给身体预处理
      effectiveBodyBytes = await generateModel(
        bodyImageBytes,
        onProgress: (p, s) => onProgress?.call(0.05 + p * 0.30, s),
      );
      baseProgress = 0.35;
    }

    onProgress?.call(baseProgress + 0.05, '连接代理服务器...');

    try {
      final result = await _apiClient.tryOnBytes(
        bodyImageBytes: effectiveBodyBytes,
        clothImageBytes: garmentImageBytes,
        category: category,
        preprocessBody: false, // 已在客户端预处理过
      );

      stopwatch.stop();
      onProgress?.call(1.0, '完成');

      return TryOnResult(
        imageBytes: result,
        backend: 'proxy',
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
    } on ApiException catch (e) {
      throw TryOnException('${e.message} (HTTP ${e.statusCode})');
    }
  }

  void dispose() => _apiClient.dispose();

  static String get _proxyOfflineMessage =>
      'AI 代理服务器未启动。请执行以下步骤：\n'
      '1. 创建 .env 文件：echo DASHSCOPE_API_KEY=sk-你的密钥 > .env\n'
      '2. 安装依赖：pip install -r tools/requirements.txt\n'
      '3. 启动代理：python tools/ai_proxy_server.py\n'
      '4. 刷新本页面重试';
}

/// 试衣服务异常
class TryOnException implements Exception {
  TryOnException(this.message);
  final String message;
  @override
  String toString() => message;
}
