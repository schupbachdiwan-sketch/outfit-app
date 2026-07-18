import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../../core/network/try_on_service.dart';
import '../../core/theme/app_colors.dart';
import 'dashscope_test_page.dart';

/// POC AI 功能测试页面
///
/// 跨平台（Web + 桌面 + 移动端）兼容。
/// 后端优先级：本地代理 > DashScope 直连。
/// Web 版：试衣直连 DashScope，抠图不可用（需本地 rembg 服务）。
class PocTestPage extends StatefulWidget {
  const PocTestPage({super.key});

  @override
  State<PocTestPage> createState() => _PocTestPageState();
}

class _PocTestPageState extends State<PocTestPage> {
  final ApiClient _apiClient = ApiClient();
  final TryOnService _tryOnService = TryOnService();
  final ImagePicker _picker = ImagePicker();

  // ── 后端状态 ──
  bool _proxyOnline = false;
  bool _dashScopeAvailable = false;
  bool _checkingServer = false;

  // ── 图片（Uint8List 跨平台通用）──
  Uint8List? _bodyBytes;
  Uint8List? _clothBytes;
  String _category = 'upper_body';

  Uint8List? _bgRemovedResult;
  Uint8List? _tryOnResult;

  bool _removingBg = false;
  bool _tryingOn = false;
  String? _errorMessage;
  String? _backendUsed;
  int? _lastElapsedMs;

  // ── 抠图是否可用（需桌面端 + 本地代理）──
  bool get _canRemoveBg => !kIsWeb && _proxyOnline;

  @override
  void initState() {
    super.initState();
    _checkServer();
  }

  @override
  void dispose() {
    _apiClient.dispose();
    _tryOnService.dispose();
    super.dispose();
  }

  Future<void> _checkServer() async {
    setState(() { _checkingServer = true; _errorMessage = null; });

    final results = await Future.wait([
      _apiClient.healthCheck(),
      Future.value(ApiConfig.hasDashScopeKey),
    ]);

    setState(() {
      _proxyOnline = results[0] == true;
      _dashScopeAvailable = results[1] == true;
      _checkingServer = false;

      if (!_anyBackendAvailable) {
        _errorMessage = 'AI 服务不可用\n'
            '• 本地代理未启动：python tools/ai_proxy_server.py\n'
            '• DashScope Key 未配置';
      }
    });
  }

  bool get _anyBackendAvailable => _proxyOnline || _dashScopeAvailable;

  Future<void> _pickBodyImage(ImageSource source) async {
    final xfile = await _picker.pickImage(source: source, maxWidth: 1024);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    setState(() { _bodyBytes = bytes; _errorMessage = null; });
  }

  Future<void> _pickClothImage(ImageSource source) async {
    final xfile = await _picker.pickImage(source: source, maxWidth: 1024);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    setState(() { _clothBytes = bytes; _errorMessage = null; });
  }

  /// 抠图（仅桌面端 + 代理在线时可用）
  Future<void> _removeBackground() async {
    if (!_canRemoveBg || _clothBytes == null) return;

    setState(() { _removingBg = true; _errorMessage = null; _bgRemovedResult = null; });

    try {
      final result = await _apiClient.removeBackgroundBytes(_clothBytes!);
      setState(() { _bgRemovedResult = result; });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = '抠图异常: $e');
    } finally {
      setState(() => _removingBg = false);
    }
  }

  /// 虚拟试衣（跨平台，直连 DashScope 或用代理）
  Future<void> _tryOn() async {
    if (_bodyBytes == null || _clothBytes == null) return;
    if (!_anyBackendAvailable) {
      setState(() => _errorMessage = '没有可用的 AI 后端');
      return;
    }

    setState(() {
      _tryingOn = true;
      _errorMessage = null;
      _tryOnResult = null;
      _backendUsed = null;
    });

    final sw = Stopwatch()..start();
    try {
      final clothBytes = _bgRemovedResult ?? _clothBytes!;

      final result = await _tryOnService.tryOnSingle(
        bodyImageBytes: _bodyBytes!,
        garmentImageBytes: clothBytes,
        category: _category,
        onProgress: (p, s) { if (mounted) setState(() {}); },
      );

      setState(() {
        _tryOnResult = result.imageBytes;
        _backendUsed = result.backend == 'proxy' ? '本地代理' : 'DashScope直连';
        _lastElapsedMs = sw.elapsedMilliseconds;
      });
    } on TryOnException catch (e) {
      setState(() => _errorMessage = e.message);
    } on ApiException catch (e) {
      setState(() => _errorMessage = '${e.message} (HTTP ${e.statusCode})');
    } catch (e) {
      setState(() => _errorMessage = '试衣异常: $e');
    } finally {
      setState(() => _tryingOn = false);
    }
  }

  // ═══════════════════════════════════════
  //  UI
  // ═══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI POC 测试'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud, size: 20),
            tooltip: 'DashScope 直连测试(用URL)',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DashScopeTestPage())),
          ),
          _statusDot,
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _checkServer,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_errorMessage != null) _errorBanner,
          _backendCard,
          const SizedBox(height: 16),
          _imgSection('📸 身体照片（全身/半身照）', _bodyBytes, _pickBodyImage),
          const SizedBox(height: 12),
          _categoryRow,
          const SizedBox(height: 12),
          _imgSection('👕 衣服照片', _clothBytes, _pickClothImage),
          const SizedBox(height: 16),
          _actionRow,
          const SizedBox(height: 16),
          if (_bgRemovedResult != null && _clothBytes != null)
            _resultCard('✂️ AI抠图结果', _clothBytes!, _bgRemovedResult!),
          if (_tryOnResult != null && _bodyBytes != null) ...[
            const SizedBox(height: 12),
            _resultCard('✨ AI试穿效果 ($_backendUsed)', _bodyBytes!, _tryOnResult!),
          ],
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  // ── 状态指示 ──

  Widget get _statusDot {
    final any = _proxyOnline || _dashScopeAvailable;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: _checkingServer ? '检查中...' : '代理:${_proxyOnline ? "✓" : "✗"} DashScope:${_dashScopeAvailable ? "✓" : "✗"}',
        child: Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _checkingServer ? AppColors.warning : (any ? AppColors.success : AppColors.error),
          ),
        ),
      ),
    );
  }

  Widget get _errorBanner => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
      const SizedBox(width: 8),
      Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
      GestureDetector(
        onTap: () => setState(() => _errorMessage = null),
        child: const Icon(Icons.close, color: AppColors.error, size: 18),
      ),
    ]),
  );

  Widget get _backendCard => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _anyBackendAvailable ? AppColors.success.withValues(alpha: 0.08) : AppColors.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: (_anyBackendAvailable ? AppColors.success : AppColors.warning).withValues(alpha: 0.3)),
    ),
    child: Column(children: [
      Row(children: [
        Icon(_checkingServer ? Icons.sync : (_anyBackendAvailable ? Icons.check_circle : Icons.cloud_off),
          size: 20, color: _anyBackendAvailable ? AppColors.success : AppColors.warning),
        const SizedBox(width: 8),
        Text(_checkingServer ? '检测中...' : (_anyBackendAvailable ? '✅ AI 服务可用' : '❌ AI 服务不可用'),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
            color: _anyBackendAvailable ? AppColors.success : AppColors.textPrimary)),
        if (_checkingServer) ...[
          const SizedBox(width: 8),
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ]),
      const SizedBox(height: 8),
      Row(children: [
        _chip('本地代理', _proxyOnline, _proxyOnline ? 'localhost:8080' : '未启动'),
        const SizedBox(width: 8),
        _chip('DashScope', _dashScopeAvailable,
          _dashScopeAvailable ? 'Key ${ApiConfig.effectiveApiKey.substring(0, 8)}***' : '未配置'),
      ]),
      if (!_proxyOnline && _dashScopeAvailable) ...[
        const SizedBox(height: 8),
        Text('💡 抠图需代理服务器，试衣可直接点下方按钮', style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withAlpha(180))),
      ],
      if (kIsWeb) ...[
        const SizedBox(height: 4),
        Text('🌐 Web版：试衣可用 / 抠图不可用', style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withAlpha(160))),
      ],
    ]),
  );

  Widget _chip(String label, bool online, String detail) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: online ? AppColors.success.withValues(alpha: 0.1) : AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: online ? AppColors.success.withValues(alpha: 0.3) : AppColors.border.withAlpha(80)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 6, height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: online ? AppColors.success : AppColors.textPlaceholder)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: online ? AppColors.textPrimary : AppColors.textPlaceholder)),
        ]),
        const SizedBox(height: 2),
        Text(detail, style: TextStyle(fontSize: 10, color: AppColors.textSecondary.withAlpha(180))),
      ]),
    ),
  );

  // ── 图片区域 ──

  Widget _imgSection(String label, Uint8List? bytes, Future<void> Function(ImageSource) onPick) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      if (bytes == null)
        _pickerBox(onPick)
      else
        _previewBox(bytes, onPick),
    ]);
  }

  Widget _pickerBox(Future<void> Function(ImageSource) onPick) {
    return Container(
      height: 120,
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12), color: AppColors.background),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _pickBtn(Icons.camera_alt, '拍照', () => onPick(ImageSource.camera)),
        const SizedBox(width: 32),
        _pickBtn(Icons.photo_library, '相册', () => onPick(ImageSource.gallery)),
      ]),
    );
  }

  Widget _previewBox(Uint8List bytes, Future<void> Function(ImageSource) onPick) {
    return Stack(children: [
      ClipRRect(borderRadius: BorderRadius.circular(12),
        child: Image.memory(bytes, height: 180, width: double.infinity, fit: BoxFit.contain)),
      Positioned(top: 8, right: 8, child: Row(children: [
        _miniBtn(Icons.refresh, '重选', () => onPick(ImageSource.gallery)),
        const SizedBox(width: 6),
        _miniBtn(Icons.close, '清除', () => setState(() => _bodyBytes = _clothBytes = null), AppColors.error),
      ])),
    ]);
  }

  Widget _pickBtn(IconData icon, String label, VoidCallback tap) {
    return InkWell(
      onTap: tap, borderRadius: BorderRadius.circular(8),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 28, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ])),
    );
  }

  Widget _miniBtn(IconData icon, String tooltip, VoidCallback tap, [Color? color]) {
    return Material(
      color: Colors.white, shape: const CircleBorder(), elevation: 1,
      child: InkWell(onTap: tap, customBorder: const CircleBorder(),
        child: Padding(padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: color ?? AppColors.textSecondary))),
    );
  }

  Widget get _categoryRow {
    const cats = [('upper_body', '上衣'), ('lower_body', '下装'), ('dress', '连衣裙')];
    return Row(children: [
      const Text('衣物类别：', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(width: 8),
      ...cats.map((c) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
        label: Text(c.$2),
        selected: _category == c.$1,
        selectedColor: AppColors.primaryLight,
        labelStyle: TextStyle(color: _category == c.$1 ? AppColors.primary : AppColors.textSecondary,
          fontWeight: _category == c.$1 ? FontWeight.w600 : FontWeight.normal),
        onSelected: (v) { if (v) setState(() => _category = c.$1); },
      ))),
    ]);
  }

  Widget get _actionRow => Row(children: [
    Expanded(child: _ActionBtn(label: _canRemoveBg ? '抠图' : '抠图(不可用)', icon: Icons.content_cut,
      loading: _removingBg, enabled: _canRemoveBg && _clothBytes != null && !_tryingOn, onTap: _removeBackground)),
    const SizedBox(width: 12),
    Expanded(child: _ActionBtn(label: '试衣', icon: Icons.auto_awesome, loading: _tryingOn,
      enabled: _anyBackendAvailable && _bodyBytes != null && _clothBytes != null && !_removingBg,
      onTap: _tryOn, highlighted: true)),
  ]);

  Widget _resultCard(String title, Uint8List orig, Uint8List result) {
    return Card(
      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (_lastElapsedMs != null)
            Text('${(_lastElapsedMs! / 1000).toStringAsFixed(1)}s',
              style: TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Column(children: [
            const Text('原图', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(orig, height: 160, fit: BoxFit.contain)),
          ])),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_forward, color: AppColors.primary, size: 24)),
          Expanded(child: Column(children: [
            const Text('结果', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(result, height: 160, fit: BoxFit.contain)),
          ])),
        ]),
      ])),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label; final IconData icon; final bool loading; final bool enabled; final VoidCallback onTap; final bool highlighted;
  const _ActionBtn({required this.label, required this.icon, required this.loading, required this.enabled, required this.onTap, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: enabled && !loading ? onTap : null,
      icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon, size: 18),
      label: Text(loading ? '处理中...' : label),
      style: ElevatedButton.styleFrom(
        backgroundColor: highlighted ? AppColors.primary : null,
        foregroundColor: highlighted ? Colors.white : null,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
