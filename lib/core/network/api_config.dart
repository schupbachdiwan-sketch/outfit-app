/// AI 服务配置
///
/// 支持两种模式：
/// - 本地开发：使用独立的 Python 代理服务器
/// - 生产部署：前端和后端在同一域名下（相对路径）
class ApiConfig {
  ApiConfig._();

  // ── 基础 URL 配置 ──

  /// 代理服务器地址
  ///
  /// 通过 dart-define 注入（优先级最高）：
  /// ```bash
  /// flutter run --dart-define=AI_PROXY_URL=http://localhost:8080
  /// ```
  ///
  /// 如果未注入，则自动使用当前域名（适用于生产环境前后端同域部署）
  static const String _envUrl = String.fromEnvironment(
    'AI_PROXY_URL',
    defaultValue: '',  // 空字符串表示自动检测
  );

  /// 获取实际的 API 基础 URL
  ///
  /// - 开发环境：返回 dart-define 注入的 URL
  /// - 生产环境：返回空字符串（使用相对路径，浏览器自动发送到当前域名）
  static String get baseUrl {
    if (_envUrl.isNotEmpty) {
      return _envUrl;
    }
    // 生产环境：前后端同域，使用相对路径
    return '';
  }

  /// 是否是生产环境（前后端同域）
  static bool get isProduction => _envUrl.isEmpty;

  /// 请求超时
  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 120);

  // ── API 路径（相对路径）──

  static const String healthPath = '/api/health';
  static const String removeBgPath = '/api/remove-bg';
  static const String enhanceClothingPath = '/api/enhance-clothing';
  static const String generateModelPath = '/api/generate-model';
  static const String tryOnPath = '/api/try-on';
  static const String tryOnAsyncPath = '/api/try-on-async';

  // ── 阿里云百炼 DashScope（备用）──

  static const String dashScopeApiKey = String.fromEnvironment(
    'DASHSCOPE_API_KEY',
  );

  static const String dashScopeApiKeyDev = String.fromEnvironment(
    'DASHSCOPE_API_KEY_DEV',
    defaultValue: 'sk-15ca3af770ab496197b29b7d937c54c8',
  );

  static String get effectiveApiKey {
    if (dashScopeApiKey.isNotEmpty) return dashScopeApiKey;
    return dashScopeApiKeyDev;
  }

  static bool get hasDashScopeKey => effectiveApiKey.isNotEmpty;

  static const String dashScopeBaseUrl =
      'https://dashscope.aliyuncs.com/api/v1';

  static const String dashScopeTryOnSyncPath =
      '/services/aigc/image-generation/virtual-try-on';

  static const String dashScopeTryOnAsyncPath =
      '/services/aigc/image2image/image-synthesis/';

  static const String dashScopeTasksPath = '/tasks/';
}
