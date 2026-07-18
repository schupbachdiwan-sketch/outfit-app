import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// 阿里云百炼 DashScope 直连客户端 — 虚拟试衣
///
/// 调用 aitryon-plus 模型，支持两种模式：
/// - **异步模式**（推荐）：提交 → 轮询 → 下载（需图片 URL）
/// - **同步模式**：直接提交 base64 图片，同步返回结果
///
/// 用法（异步）:
/// ```dart
/// final client = DashScopeClient();
/// final task = await client.createTask(
///   personImageUrl: 'https://...',
///   topGarmentUrl: 'https://...',
/// );
/// final result = await client.pollTask(task.taskId);
/// final bytes = await client.downloadImage(result.resultImageUrl!);
/// ```
///
/// 用法（同步）:
/// ```dart
/// final client = DashScopeClient();
/// final bytes = await client.tryOnSync(
///   personImageB64: '...',
///   garmentImageB64: '...',
///   category: 'upper_body',
/// );
/// ```
class DashScopeClient {
  DashScopeClient({String? apiKey})
      : _apiKey = apiKey ?? ApiConfig.effectiveApiKey;

  final String _apiKey;

  String get apiKey => _apiKey;

  static const String _baseUrl = ApiConfig.dashScopeBaseUrl;

  // ═══════════════════════════════════════
  //  异步模式（URL 提交 → 轮询 → 下载）
  // ═══════════════════════════════════════

  /// 提交虚拟试衣任务（异步模式）
  ///
  /// [personImageUrl] 人物照片 URL（必填）
  /// [topGarmentUrl] 上衣照片 URL
  /// [bottomGarmentUrl] 下装照片 URL
  /// [restoreFace] 是否修复面部，默认 true
  /// [resolution] 输出分辨率，-1 表示与原图一致
  Future<DashScopeTask> createTask({
    required String personImageUrl,
    String? topGarmentUrl,
    String? bottomGarmentUrl,
    bool restoreFace = true,
    int resolution = -1,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConfig.dashScopeTryOnAsyncPath}');

    final body = <String, dynamic>{
      'model': 'aitryon-plus',
      'input': <String, dynamic>{
        'person_image_url': personImageUrl,
        if (topGarmentUrl != null) 'top_garment_url': topGarmentUrl,
        if (bottomGarmentUrl != null)
          'bottom_garment_url': bottomGarmentUrl,
      },
      'parameters': <String, dynamic>{
        'resolution': resolution,
        'restore_face': restoreFace,
      },
    };

    final response = await http
        .post(
          uri,
          headers: _asyncHeaders,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw DashScopeException(
        response.statusCode,
        '创建任务失败: ${_extractMessage(response.body)}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final output = data['output'] as Map<String, dynamic>?;
    final taskId = output?['task_id'] as String?;

    if (taskId == null) {
      throw DashScopeException(
        response.statusCode,
        '响应中未包含 task_id，请检查请求参数。响应: ${response.body}',
      );
    }

    return DashScopeTask(
      taskId: taskId,
      status: output?['task_status'] as String? ?? 'PENDING',
    );
  }

  /// 查询单个任务的状态
  Future<DashScopeTask> getTaskStatus(String taskId) async {
    final uri = Uri.parse('$_baseUrl${ApiConfig.dashScopeTasksPath}$taskId');

    final response = await http
        .get(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw DashScopeException(
        response.statusCode,
        '查询任务失败: ${_extractMessage(response.body)}',
      );
    }

    return _parseTaskResponse(taskId, response.body);
  }

  /// 轮询任务直到完成或超时
  ///
  /// [onProgress] 每次轮询后回调，用于更新 UI 进度
  Future<DashScopeTask> pollTask(
    String taskId, {
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(seconds: 120),
    void Function(DashScopeTask task)? onProgress,
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final task = await getTaskStatus(taskId);
      onProgress?.call(task);

      if (task.isSucceeded) return task;
      if (task.isFailed) {
        throw DashScopeException(
          0,
          'AI 处理失败: ${task.errorMessage ?? "未知错误"}',
        );
      }

      await Future.delayed(interval);
    }

    throw DashScopeException(0, '任务超时（${timeout.inSeconds}s），请稍后重试');
  }

  /// 下载结果图片
  Future<Uint8List> downloadImage(String url) async {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw DashScopeException(
        response.statusCode,
        '下载结果图失败: HTTP ${response.statusCode}',
      );
    }

    return response.bodyBytes;
  }

  // ═══════════════════════════════════════
  //  同步模式（base64 提交 → 直接返回）
  // ═══════════════════════════════════════

  /// 虚拟试衣同步模式
  ///
  /// 直接提交 base64 编码的图片，同步等待返回结果。
  /// 适合代理服务器转发或客户端直连场景。
  ///
  /// [personImageB64] 人物照片 base64（不含 data: 前缀）
  /// [garmentImageB64] 衣物照片 base64（不含 data: 前缀）
  /// [category] 衣物类别: upper_body | lower_body | dress
  /// [n] 生成图片数量，默认 1
  /// [size] 输出尺寸，默认 "1024*1024"
  Future<Uint8List> tryOnSync({
    required String personImageB64,
    required String garmentImageB64,
    String category = 'upper_body',
    int n = 1,
    String size = '1024*1024',
  }) async {
    if (!['upper_body', 'lower_body', 'dress'].contains(category)) {
      throw ArgumentError('category 必须为 upper_body / lower_body / dress');
    }

    final uri = Uri.parse('$_baseUrl${ApiConfig.dashScopeTryOnSyncPath}');

    final body = <String, dynamic>{
      'model': 'aitryon-plus',
      'input': <String, dynamic>{
        'person_image': personImageB64,
        'garment_image': garmentImageB64,
        'category': category,
      },
      'parameters': <String, dynamic>{
        'n': n,
        'watermark': false,
        'size': size,
      },
    };

    final response = await http
        .post(
          uri,
          headers: _authHeaders,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw DashScopeException(
        response.statusCode,
        '同步试衣失败: ${_extractMessage(response.body)}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final output = data['output'] as Map<String, dynamic>?;
    final results = output?['results'] as List<dynamic>?;

    if (results == null || results.isEmpty) {
      throw DashScopeException(
        response.statusCode,
        '阿里云返回无结果: ${response.body}',
      );
    }

    final resultUrl = (results[0] as Map<String, dynamic>)['url'] as String?;
    if (resultUrl == null) {
      throw DashScopeException(
        response.statusCode,
        '结果 URL 为空: ${response.body}',
      );
    }

    return downloadImage(resultUrl);
  }

  // ═══════════════════════════════════════
  //  内部
  // ═══════════════════════════════════════

  Map<String, String> get _authHeaders => {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      };

  Map<String, String> get _asyncHeaders => {
        ..._authHeaders,
        'X-DashScope-Async': 'enable',
      };

  DashScopeTask _parseTaskResponse(String taskId, String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final output = data['output'] as Map<String, dynamic>?;

    // 实际 API 返回两种格式：
    // 1. output.image_url（直接 URL 字符串）
    // 2. output.results[].url（结果数组中的 URL）
    List<String>? resultUrls;
    final directUrl = output?['image_url'] as String?;
    if (directUrl != null && directUrl.isNotEmpty) {
      resultUrls = [directUrl];
    } else {
      resultUrls =
          (output?['results'] as List<dynamic>?)
              ?.map((r) => (r as Map<String, dynamic>)['url'] as String)
              .toList();
    }

    return DashScopeTask(
      taskId: taskId,
      status: output?['task_status'] as String? ?? 'UNKNOWN',
      resultImageUrls: resultUrls,
      errorMessage:
          output?['message'] as String? ??
          data['message'] as String?,
    );
  }

  String _extractMessage(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['message']?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }
}

// ── 数据模型 ──

/// DashScope 异步任务
class DashScopeTask {
  DashScopeTask({
    required this.taskId,
    required this.status,
    this.resultImageUrls,
    this.errorMessage,
  });

  final String taskId;
  final String status;

  /// 结果图片 URL 列表（SUCCEEDED 时有值）
  final List<String>? resultImageUrls;

  /// 便捷获取第一张结果图 URL
  String? get resultImageUrl =>
      (resultImageUrls != null && resultImageUrls!.isNotEmpty)
          ? resultImageUrls!.first
          : null;

  /// 错误信息（FAILED 时有值）
  final String? errorMessage;

  bool get isSucceeded => status == 'SUCCEEDED';
  bool get isFailed => status == 'FAILED';
  bool get isRunning => status == 'RUNNING' || status == 'PENDING';
}

// ── 异常 ──

/// DashScope API 异常
class DashScopeException implements Exception {
  DashScopeException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'DashScopeException($statusCode): $message';
}
