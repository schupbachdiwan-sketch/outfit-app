/// AI 服务配置
///
/// POC 阶段支持两种后端：
/// - 本地 Python 代理服务器（开发调试用）
/// - 阿里云百炼 DashScope 直连（生产路线）
///
/// Phase B 统一为 Supabase Edge Functions。
class ApiConfig {
  ApiConfig._();

  // ── 本地代理服务器 ──

  /// 代理服务器地址
  /// - 本地调试: http://localhost:8080
  /// - 局域网真机: http://<内网IP>:8080
  /// - 生产: Supabase Edge Function URL (Phase B)
  static const String baseUrl = String.fromEnvironment(
    'AI_PROXY_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// 请求超时
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// 本地代理 API 路径
  static const String healthPath = '/api/health';
  static const String removeBgPath = '/api/remove-bg';
  static const String enhanceClothingPath = '/api/enhance-clothing';
  static const String generateModelPath = '/api/generate-model';
  static const String tryOnPath = '/api/try-on';
  static const String tryOnAsyncPath = '/api/try-on-async';

  // ── 阿里云百炼 DashScope ──

  /// DashScope API Key
  ///
  /// 推荐通过 dart-define 注入（生产环境）：
  /// ```bash
  /// flutter run --dart-define=DASHSCOPE_API_KEY=sk-xxx
  /// ```
  ///
  /// POC 开发阶段可使用 [dashScopeApiKeyDev] 作为后备。
  static const String dashScopeApiKey = String.fromEnvironment(
    'DASHSCOPE_API_KEY',
  );

  /// POC 开发阶段的后备 API Key
  ///
  /// ⚠️ 仅用于本地开发调试，禁止提交到版本控制。
  /// 生产环境必须通过 dart-define 或 Supabase Edge Functions 注入。
  static const String dashScopeApiKeyDev = String.fromEnvironment(
    'DASHSCOPE_API_KEY_DEV',
    defaultValue: 'sk-15ca3af770ab496197b29b7d937c54c8',
  );

  /// 获取有效的 API Key（优先使用 dart-define，其次使用 dev key）
  static String get effectiveApiKey {
    if (dashScopeApiKey.isNotEmpty) return dashScopeApiKey;
    return dashScopeApiKeyDev;
  }

  /// 是否有可用的 DashScope API Key
  static bool get hasDashScopeKey => effectiveApiKey.isNotEmpty;

  /// DashScope 基础 URL
  static const String dashScopeBaseUrl =
      'https://dashscope.aliyuncs.com/api/v1';

  /// DashScope 虚拟试衣 API（同步，支持 base64）
  static const String dashScopeTryOnSyncPath =
      '/services/aigc/image-generation/virtual-try-on';

  /// DashScope 虚拟试衣 API（异步，需图片 URL）
  static const String dashScopeTryOnAsyncPath =
      '/services/aigc/image2image/image-synthesis/';

  /// DashScope 任务查询路径
  static const String dashScopeTasksPath = '/tasks/';
}
