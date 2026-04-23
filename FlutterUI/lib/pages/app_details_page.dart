import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/app_package.dart';

class AppDetailsPage extends StatefulWidget {
  final AppPackage app;

  const AppDetailsPage({super.key, required this.app});

  @override
  State<AppDetailsPage> createState() => _AppDetailsPageState();
}

class _AppDetailsPageState extends State<AppDetailsPage> {
  bool _isInstalling = false;
  final List<String> _logs = [];
  String _currentStatus = "Ready";
  double? _progress; // null 表示不确定进度
  bool _showTerminal = false; // 控制终端显示

  Future<void> _handleAction(String flag) async {
    if (_isInstalling) return;

    // 1. 弹出确认对话框
    final isUninstall = flag == "-R";
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUninstall ? "确认卸载" : "确认安装"),
        content: Text("确定要对 ${widget.app.name} 执行此操作吗？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("取消"),
          ),
          FilledButton(
            style: isUninstall
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: const Text("确定"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 2. 开始执行逻辑
    setState(() {
      _isInstalling = true;
      _logs.clear();
      _progress = null;
      _currentStatus = isUninstall ? "正在准备卸载..." : "正在准备安装...";
      _showTerminal = true; // 开始时自动展开终端，方便看进度
    });

    try {
      // 💡 关键修复：使用绝对路径和 workingDirectory
      final process = await Process.start(
        '/home/shekong/Projects/Omnistore/python/.venv/bin/python', // 必须用 venv 的 python
        [
          '/home/shekong/Projects/Omnistore/python/main.py',
          flag,
          widget.app.name.trim(), // 确保包名没有前后空格
          '--source', widget.app.primarySource,
          '--json',
        ],
        workingDirectory: '/home/shekong/Projects/Omnistore/python',
      );

      // 监听输出
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (line.startsWith("[CALLBACK]")) {
              final data = jsonDecode(line.replaceFirst("[CALLBACK] ", ""));
              if (mounted) {
                setState(() {
                  String log = data['log'] ?? "";
                  _logs.add(log);
                  _currentStatus = log;
                  if (log.contains("%")) {
                    final match = RegExp(r"(\d+)%").firstMatch(log);
                    if (match != null) {
                      _progress = int.parse(match.group(1)!) / 100.0;
                    }
                  }
                });
              }
            }
          });

      // 💡 调试利器：捕获 stderr。如果退出码是 2，这里会打印出 Python 报错的具体原因
      process.stderr.transform(utf8.decoder).listen((err) {
        debugPrint("PYTHON STDERR: $err");
        if (mounted) setState(() => _logs.add("系统提示: $err"));
      });

      final exitCode = await process.exitCode;

      if (mounted) {
        setState(() {
          _isInstalling = false;
          if (exitCode == 0) {
            _progress = 1.0;
            _currentStatus = isUninstall ? "✓ 卸载成功" : "✓ 安装成功";
          } else {
            _currentStatus = "✗ 失败 (错误码: $exitCode)";
            _showFailureDialog(flag, exitCode);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInstalling = false;
          _currentStatus = "✗ 启动失败: $e";
        });
      }
    }
  }

  Future<void> _showFailureDialog(
    String flag,
    int exitCode, {
    String? error,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 32),
        title: Text(flag == "-I" ? "安装失败" : "卸载失败"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                error != null ? "错误: $error" : "操作退出码: $exitCode",
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              if (_logs.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text("最后日志:"),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.builder(
                    reverse: true,
                    itemCount: _logs.length,
                    itemBuilder: (context, i) => Text(
                      _logs[_logs.length - 1 - i],
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("关闭"),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _logs.clear();
                _currentStatus = "Ready";
                _progress = null;
              });
            },
            child: const Text("重试"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("App Details"),
        actions: [
          // 右上角终端按钮
          IconButton(
            icon: Icon(
              _showTerminal ? Icons.terminal : Icons.terminal_outlined,
              color: _isInstalling ? Colors.orange : null,
            ),
            tooltip: "显示终端",
            onPressed: () => setState(() => _showTerminal = !_showTerminal),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 如果显示终端，在顶部显示
            if (_showTerminal && (_isInstalling || _logs.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildTerminalPanel(colorScheme),
              ),

            _buildHeader(theme),
            const SizedBox(height: 32),

            // 按钮组
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                    ),
                    onPressed: _isInstalling ? null : () => _handleAction("-I"),
                    icon: Icon(
                      widget.app.installed ? Icons.refresh : Icons.download,
                    ),
                    label: Text(
                      widget.app.installed
                          ? "Reinstall (-I)"
                          : "Install Now (-I)",
                    ),
                  ),
                ),
                if (widget.app.installed) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error, // 警告色
                      side: BorderSide(color: theme.colorScheme.error),
                      minimumSize: const Size(56, 56),
                    ),
                    onPressed: _isInstalling ? null : () => _handleAction("-R"),
                    child: const Icon(Icons.delete_forever_outlined),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // 动态日志监控器（非全屏终端模式时显示）
            if (!_showTerminal && (_isInstalling || _logs.isNotEmpty))
              Column(
                children: [
                  _buildMonitor(colorScheme),
                  const SizedBox(height: 24),
                ],
              ),

            const Divider(),

            // 详情描述
            _buildSectionTitle(theme, "关于此软件"),
            Text(widget.app.description, style: theme.textTheme.bodyLarge),

            const SizedBox(height: 32),
            _buildSectionTitle(theme, "详细参数"),
            _buildInfoRow(Icons.source, "来源", widget.app.primarySource),
            _buildInfoRow(
              Icons.all_inclusive,
              "变体",
              widget.app.sources.join(", "),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminalPanel(ColorScheme colorScheme) {
    final isError =
        _currentStatus.contains("✗") || _currentStatus.contains("Failed");

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError
              ? Colors.red.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和状态
          Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.terminal,
                color: isError ? Colors.red : Colors.greenAccent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _currentStatus,
                  style: TextStyle(
                    color: isError ? Colors.red : Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 进度条
          if (_isInstalling || _progress != null)
            Column(
              children: [
                LinearProgressIndicator(
                  value: _progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isError ? Colors.red : Colors.greenAccent,
                  ),
                ),
                const SizedBox(height: 8),
                if (_progress != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "${(_progress! * 100).toInt()}%",
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),

          // 日志窗口
          SizedBox(
            height: 200,
            width: double.infinity,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        "等待输出...",
                        style: TextStyle(
                          color: Colors.grey,
                          fontFamily: 'monospace',
                        ),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      itemCount: _logs.length,
                      itemBuilder: (context, i) => Text(
                        _logs[_logs.length - 1 - i],
                        style: const TextStyle(
                          color: Color(0xFFD4D4D4),
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建头部的辅助方法
  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Hero(
          tag: widget.app.name,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                widget.app.name[0].toUpperCase(),
                style: theme.textTheme.headlineLarge,
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.app.name,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "Version: ${widget.app.version}",
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  // 核心：监控面板 UI
  Widget _buildMonitor(ColorScheme colorScheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _isInstalling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.terminal, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_currentStatus, overflow: TextOverflow.ellipsis),
              ),
              if (_progress != null) Text("${(_progress! * 100).toInt()}%"),
            ],
          ),
          const SizedBox(height: 12),
          if (_progress != null || _isInstalling)
            LinearProgressIndicator(
              value: _progress,
              borderRadius: BorderRadius.circular(2),
            ),

          // 终端模拟器
          Container(
            height: 160,
            width: double.infinity,
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.builder(
              reverse: true, // 保持最新日志在底部
              itemCount: _logs.length,
              itemBuilder: (context, i) => Text(
                _logs[_logs.length - 1 - i],
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
