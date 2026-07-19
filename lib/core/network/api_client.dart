import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// AI 代理服务器 HTTP 客户端
///
/// POC 阶段直接调用本地 Python 服务器
/// Phase B 替换为 supabase_flutter
class ApiClient {
  ApiClient({this.baseUrl = ''});

  final String baseUrl;

  String get _baseUrl => baseUrl.isEmpty ? ApiConfig.baseUrl : baseUrl;

  final http.Client _client = http.Client();

  /// 健康检查
  Future<bool> healthCheck() async {
    try {
      final uri = Uri.parse('$_baseUrl${ApiConfig.healthPath}');
      final response = await _client.get(uri).timeout(ApiConfig.connectTimeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// AI 抠图：上传图片，返回透明 PNG 字节数据
  ///
  /// [imageBytes] 待抠图的衣物照片字节数据
  /// 返回透明背景的 PNG 字节数据
  /// 抛出 [ApiException] 当请求失败时
  Future<Uint8List> removeBackground(Uint8List imageBytes) async {
    final uri = Uri.parse('$_baseUrl${ApiConfig.removeBgPath}');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      http.MultipartFile.fromBytes('image', imageBytes, filename: 'image.png'),
    );

    final streamedResponse = await request.send().timeout(
      ApiConfig.receiveTimeout,
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        '抠图失败: ${_extractError(response.body)}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ApiException(response.statusCode, '抠图返回异常: $data');
    }

    return base64Decode(data['image_base64'] as String);
  }

  /// AI 抠图：直接使用字节数据（跨平台兼容，Web 优先 JSON）
  ///
  /// Flutter Web 的 MultipartRequest 不会正确设置文件分片的 Content-Type
  /// 所以统一使用 JSON base64 方式发送，与 generateModel 保持一致
  Future<Uint8List> removeBackgroundBytes(Uint8List imageBytes) async {
    final uri = Uri.parse('$_baseUrl${ApiConfig.removeBgPath}');

    final body = <String, dynamic>{
      'image_base64': base64Encode(imageBytes),
    };

    final request = http.Request('POST', uri);
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode(body);

    final streamedResponse = await request.send().timeout(ApiConfig.receiveTimeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, '抠图失败: ${_extractError(response.body)}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ApiException(response.statusCode, '抠图返回异常: $data');
    }

    return base64Decode(data['image_base64'] as String);
  }

  /// AI 衣服增强：rembg 抠图 + 白底合成 + Wan2.7 电商产品图生成
  ///
  /// 用于衣柜录入时把用户拍的衣服照片转化为专业电商白底产品图
  /// [imageBytes] 原始衣服照片字节数据
  /// 返回增强后的 JPEG 字节数据
  Future<Uint8List> enhanceClothing(Uint8List imageBytes) async {
    final uri = Uri.parse('$_baseUrl${ApiConfig.enhanceClothingPath}');

    final body = <String, dynamic>{
      'image_base64': base64Encode(imageBytes),
    };

    final request = http.Request('POST', uri);
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode(body);

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 120),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        '衣服增强失败: ${_extractError(response.body)}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ApiException(response.statusCode, '衣服增强返回异常: $data');
    }

    return base64Decode(data['image_base64'] as String);
  }

  /// 虚拟试衣：提交身体照片 + 衣服照片，返回效果图
  ///
  /// [bodyImageBytes] 用户全身/半身照片字节数据
  /// [clothImageBytes] 衣服照片字节数据（建议已抠图）
  /// [category] 衣物类别: upper_body | lower_body | dress
  /// 返回试穿效果图 PNG 字节数据
  Future<Uint8List> tryOn({
    required Uint8List bodyImageBytes,
    required Uint8List clothImageBytes,
    String category = 'upper_body',
  }) async {
    return tryOnBytes(
      bodyImageBytes: bodyImageBytes,
      clothImageBytes: clothImageBytes,
      category: category,
    );
  }

  /// AI 模特化：将用户身体照片转化为干净模特风格图，或从身材数据生成人物
  ///
  /// [imageBytes] 用户全身照片字节数据（可选，手动模式无照片）
  /// [gender] 性别: "male" / "female"
  /// [heightCm] 身高 cm
  /// [weightKg] 体重 kg
  /// [bustCm] 胸围 cm（手动模式必填）
  /// [waistCm] 腰围 cm（手动模式必填）
  /// [hipCm] 臀围 cm（手动模式必填）
  /// 返回处理后的模特图 JPEG 字节数据
  Future<Uint8List> generateModel(
    Uint8List? imageBytes, {
    String? gender,
    double? heightCm,
    double? weightKg,
    double? bustCm,
    double? waistCm,
    double? hipCm,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConfig.generateModelPath}');

    // JSON 请求体（Flutter Web 不支持 MultipartRequest）
    final body = <String, dynamic>{
      if (gender != null) 'gender': gender,
      if (heightCm != null) 'height_cm': heightCm,
      if (weightKg != null) 'weight_kg': weightKg,
      if (bustCm != null) 'bust_cm': bustCm,
      if (waistCm != null) 'waist_cm': waistCm,
      if (hipCm != null) 'hip_cm': hipCm,
    };
    if (imageBytes != null) {
      body['image_base64'] = base64Encode(imageBytes);
    }

    final request = http.Request('POST', uri);
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode(body);

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 120),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        '模特生成失败: ${_extractError(response.body)}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ApiException(response.statusCode, '模特生成返回异常: $data');
    }

    return base64Decode(data['image_base64'] as String);
  }

  /// 虚拟试衣：使用字节数据直接提交（无需写入临时文件）
  ///
  /// [bodyImageBytes] 用户全身/半身照片字节数据
  /// [clothImageBytes] 衣服照片字节数据（建议已抠图）
  /// [category] 衣物类别: upper_body | lower_body | dress
  /// [preprocessBody] 是否先对 body 照片做 AI 模特化预处理
  /// 返回试穿效果图 PNG 字节数据
  Future<Uint8List> tryOnBytes({
    required Uint8List bodyImageBytes,
    required Uint8List clothImageBytes,
    String category = 'upper_body',
    bool preprocessBody = false,
  }) async {
    if (!['upper_body', 'lower_body', 'dress'].contains(category)) {
      throw ArgumentError('category 必须是 upper_body / lower_body / dress');
    }

    final uri = Uri.parse('$_baseUrl${ApiConfig.tryOnPath}');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      http.MultipartFile.fromBytes(
        'body_image', bodyImageBytes, filename: 'body.png',
      ),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        'cloth_image', clothImageBytes, filename: 'cloth.png',
      ),
    );
    request.fields['category'] = category;
    if (preprocessBody) {
      request.fields['preprocess_body'] = 'true';
    }

    // AI 试衣实际耗时约 90-120s，超时设 200s
    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 200),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        '虚拟试衣失败: ${_extractError(response.body)}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ApiException(response.statusCode, '试衣返回异常: $data');
    }

    return base64Decode(data['image_base64'] as String);
  }

  /// 释放 HTTP 客户端资源
  void dispose() {
    _client.close();
  }

  String _extractError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['detail']?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }
}

/// API 调用异常
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
