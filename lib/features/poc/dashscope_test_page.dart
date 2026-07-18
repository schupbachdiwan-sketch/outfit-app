import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/network/api_config.dart';
import '../../core/network/dashscope_client.dart';
import '../../core/theme/app_colors.dart';

/// DashScope 虚拟试衣 API POC 测试页面
///
/// 直接调用阿里云百炼 aitryon-plus 模型。
/// 运行时需要注入 API Key：
/// ```bash
/// flutter run --dart-define=DASHSCOPE_API_KEY=sk-xxx
/// ```
class DashScopeTestPage extends StatefulWidget {
  const DashScopeTestPage({super.key});

  @override
  State<DashScopeTestPage> createState() => _DashScopeTestPageState();
}

class _DashScopeTestPageState extends State<DashScopeTestPage> {
  DashScopeClient? _client;

  // ── 输入 ──
  final _personUrlCtrl = TextEditingController(
    text: 'https://help-static-aliyun-doc.aliyuncs.com/file-manage-files/zh-CN/20250626/ubznva/model_person.png',
  );
  final _topUrlCtrl = TextEditingController(
    text: 'https://help-static-aliyun-doc.aliyuncs.com/file-manage-files/zh-CN/20250626/epousa/short_sleeve.jpeg',
  );
  final _bottomUrlCtrl = TextEditingController(
    text: 'https://help-static-aliyun-doc.aliyuncs.com/file-manage-files/zh-CN/20250626/rchumi/pants.jpeg',
  );
  bool _restoreFace = true;

  // ── 任务状态 ──
  DashScopeTask? _task;
  bool _submitting = false;
  bool _polling = false;
  Timer? _pollTimer;
  int _pollCount = 0;
  int _elapsedSeconds = 0;
  Stopwatch? _stopwatch;

  // ── 结果 ──
  List<Uint8List>? _resultImages;
  bool _downloading = false;

  // ── 错误 ──
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initClient();
    _disposers.add(() {
      _personUrlCtrl.dispose();
      _topUrlCtrl.dispose();
      _bottomUrlCtrl.dispose();
    });
  }

  final _disposers = <void Function()>[];

  void _initClient() {
    if (!ApiConfig.hasDashScopeKey) {
      setState(() => _errorMessage = '未配置 DASHSCOPE_API_KEY。\n请通过 --dart-define=DASHSCOPE_API_KEY=sk-xxx 启动应用。');
      return;
    }
    _client = DashScopeClient(apiKey: ApiConfig.dashScopeApiKey);
    setState(() => _errorMessage = null);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _stopwatch?.stop();
    for (final d in _disposers) {
      d();
    }
    super.dispose();
  }

  // ── 核心流程 ──

  Future<void> _submitTask() async {
    final client = _client;
    if (client == null) return;

    final personUrl = _personUrlCtrl.text.trim();
    final topUrl = _topUrlCtrl.text.trim();
    final bottomUrl = _bottomUrlCtrl.text.trim();

    if (personUrl.isEmpty) {
      setState(() => _errorMessage = '请填写人物照片 URL');
      return;
    }
    if (topUrl.isEmpty && bottomUrl.isEmpty) {
      setState(() => _errorMessage = '请至少填写上衣或下装 URL');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
      _task = null;
      _resultImages = null;
      _pollCount = 0;
      _elapsedSeconds = 0;
    });

    try {
      final task = await client.createTask(
        personImageUrl: personUrl,
        topGarmentUrl: topUrl.isNotEmpty ? topUrl : null,
        bottomGarmentUrl: bottomUrl.isNotEmpty ? bottomUrl : null,
        restoreFace: _restoreFace,
      );
      setState(() {
        _task = task;
        _submitting = false;
      });

      // 自动开始轮询
      if (task.isRunning) {
        _startPolling();
      }
    } on DashScopeException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _submitting = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '提交异常: $e';
        _submitting = false;
      });
    }
  }

  void _startPolling() {
    _stopwatch = Stopwatch()..start();
    _pollCount = 0;
    _elapsedSeconds = 0;
    _polling = true;

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_task == null) return;

      _pollCount++;
      _elapsedSeconds = _stopwatch!.elapsed.inSeconds;
      setState(() {});

      try {
        final updated = await _client!.getTaskStatus(_task!.taskId);
        setState(() => _task = updated);

        if (updated.isSucceeded) {
          _stopPolling();
          _downloadResults();
        } else if (updated.isFailed) {
          _stopPolling();
          setState(() {
            _errorMessage = 'AI 处理失败: ${updated.errorMessage ?? "未知错误"}';
          });
        }
      } on DashScopeException catch (e) {
        _stopPolling();
        setState(() => _errorMessage = e.message);
      } catch (e) {
        _stopPolling();
        setState(() => _errorMessage = '轮询异常: $e');
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _stopwatch?.stop();
    _polling = false;
    setState(() {});
  }

  Future<void> _downloadResults() async {
    final urls = _task?.resultImageUrls;
    if (urls == null || urls.isEmpty) return;

    setState(() => _downloading = true);

    try {
      final results = <Uint8List>[];
      for (final url in urls) {
        final bytes = await _client!.downloadImage(url);
        results.add(bytes);
      }
      setState(() => _resultImages = results);
    } on DashScopeException catch (e) {
      setState(() => _errorMessage = '下载结果失败: ${e.message}');
    } catch (e) {
      setState(() => _errorMessage = '下载异常: $e');
    } finally {
      setState(() => _downloading = false);
    }
  }

  void _reset() {
    _stopPolling();
    setState(() {
      _task = null;
      _resultImages = null;
      _errorMessage = null;
      _pollCount = 0;
      _elapsedSeconds = 0;
    });
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DashScope 试衣 POC'),
        actions: [
          _buildApiKeyBadge(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildErrorBanner(),
            _buildApiKeyHint(),
            const SizedBox(height: 16),
            _buildUrlInputs(),
            const SizedBox(height: 12),
            _buildOptions(),
            const SizedBox(height: 16),
            _buildActions(),
            const SizedBox(height: 16),
            if (_task != null) _buildTaskStatus(),
            if (_resultImages != null) ...[
              const SizedBox(height: 16),
              _buildResults(),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeyBadge() {
    final hasKey = ApiConfig.hasDashScopeKey;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: hasKey ? AppColors.success.withValues(alpha: 0.15) : AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          hasKey ? 'Key 已配置' : 'Key 未配置',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: hasKey ? AppColors.success : AppColors.warning,
          ),
        ),
      ),
    );
  }

  Widget _buildApiKeyHint() {
    if (ApiConfig.hasDashScopeKey) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primary, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '启动时注入 API Key：\nflutter run --dart-define=DASHSCOPE_API_KEY=sk-xxx',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: const Icon(Icons.close, color: AppColors.error, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlInputs() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📋 图片 URL', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              '当前为阿里云文档示例图，可替换为你自己的图片 URL',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            _UrlField(label: '人物照片', controller: _personUrlCtrl),
            const SizedBox(height: 8),
            _UrlField(label: '上衣照片', controller: _topUrlCtrl),
            const SizedBox(height: 8),
            _UrlField(label: '下装照片', controller: _bottomUrlCtrl),
          ],
        ),
      ),
    );
  }

  Widget _buildOptions() {
    return Row(
      children: [
        const Text('面部修复：', style: TextStyle(fontSize: 14)),
        Switch(
          value: _restoreFace,
          onChanged: (v) => setState(() => _restoreFace = v),
        ),
      ],
    );
  }

  Widget _buildActions() {
    final canSubmit = _client != null && !_submitting && !_polling;
    final isRunning = _submitting || _polling;

    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: _submitting ? '提交中...' : '提交任务',
            icon: Icons.send,
            loading: _submitting,
            enabled: canSubmit,
            onTap: _submitTask,
          ),
        ),
        if (_polling) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _ActionButton(
              label: '取消轮询',
              icon: Icons.stop,
              color: AppColors.error,
              enabled: true,
              onTap: _stopPolling,
            ),
          ),
        ],
        if (!isRunning && _task != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _ActionButton(
              label: '重置',
              icon: Icons.refresh,
              color: AppColors.textSecondary,
              enabled: true,
              onTap: _reset,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTaskStatus() {
    final task = _task!;
    final isActive = task.isRunning;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: task.isSucceeded
              ? AppColors.success
              : task.isFailed
                  ? AppColors.error
                  : AppColors.warning,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isActive)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (task.isSucceeded)
                  const Icon(Icons.check_circle, color: AppColors.success, size: 20)
                else
                  const Icon(Icons.error, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Text(
                  isActive ? '处理中...' : (task.isSucceeded ? '已完成' : '失败'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${_elapsedSeconds}s',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _infoRow('Task ID', task.taskId),
            _infoRow('状态', task.status),
            _infoRow('轮询次数', '$_pollCount'),
            if (task.errorMessage != null)
              _infoRow('错误', task.errorMessage!),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final images = _resultImages!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('✨ 试穿效果', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            if (_downloading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_downloading)
          const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('下载结果中...', style: TextStyle(color: AppColors.textSecondary)),
          ))
        else
          ...images.asMap().entries.map((entry) => Padding(
                padding: EdgeInsets.only(bottom: entry.key < images.length - 1 ? 8 : 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    entry.value,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
              )),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── 小部件 ──

class _UrlField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _UrlField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear, size: 16),
          onPressed: () => controller.clear(),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool? loading;
  final bool enabled;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.label,
    required this.icon,
    this.loading,
    required this.enabled,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = loading == true;
    return ElevatedButton.icon(
      onPressed: enabled && !isLoading ? onTap : null,
      icon: isLoading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: color != null ? Colors.white : null,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
