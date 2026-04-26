import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/app_package.dart';
import '../services/backend_service.dart';

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
      _showTerminal = false; // 💡 优化：不再自动展开，保持界面清爽
    });

    // 同步到全局
    BackendService.isDownloading.value = true;
    BackendService.globalProgress.value = null;
    BackendService.globalStatus.value = _currentStatus;

    try {
      // 💡 关键修复：使用绝对路径和 workingDirectory
      final process = await Process.start(
        '/home/shekong/Projects/Omnistore/python/.venv/bin/python', // 必须用 venv 的 python
        [
          '/home/shekong/Projects/Omnistore/python/main.py',
          flag,
          widget.app.name.trim(),
          '--source', widget.app.primarySource,
          if (widget.app.url != null && flag == "-I") ...[
            '--url',
            widget.app.url!,
          ],
          '--json',
        ],
        workingDirectory: '/home/shekong/Projects/Omnistore/python',
      );

      // 监听输出
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            String cleanLine = line.trim();
            if (cleanLine.isEmpty) return;

            Map<String, dynamic>? data;
            if (cleanLine.startsWith("[CALLBACK]")) {
              try {
                data = jsonDecode(cleanLine.replaceFirst("[CALLBACK] ", ""));
              } catch (_) {}
            } else if (cleanLine.startsWith("{")) {
              try {
                data = jsonDecode(cleanLine);
              } catch (_) {}
            }

            if (data != null && mounted) {
              final finalData = data;
              setState(() {
                String log = finalData['message'] ?? finalData['log'] ?? "";
                if (log.isNotEmpty) {
                  _logs.add(log);
                  
                  // Extract progress if present
                  if (log.startsWith("[PROGRESS]")) {
                    final parts = log.split(" ");
                    if (parts.length > 1) {
                      final p = double.tryParse(parts[1]);
                      if (p != null) {
                        _progress = p / 100.0;
                        BackendService.globalProgress.value = _progress;
                      }
                    }
                  } else {
                    // Only update status if it's not a raw log or if it's an important status
                    if (log.startsWith("[INFO]") || log.startsWith("[ERROR]")) {
                       _currentStatus = log;
                       BackendService.globalStatus.value = log;
                    }
                  }
                }
              });
            }
          });

      // 💡 调试利器：捕获 stderr。如果退出码是 2，这里会打印出 Python 报错的具体原因
      process.stderr.transform(utf8.decoder).listen((err) {
        debugPrint("PYTHON STDERR: $err");
        if (mounted) setState(() => _logs.add("System Info: $err"));
      });

      final exitCode = await process.exitCode;

      if (mounted) {
        setState(() {
          _isInstalling = false;
          BackendService.isDownloading.value = false; // 结束全局状态
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
            _buildHeader(theme),
            const SizedBox(height: 24),

            _buildActionArea(colorScheme),

            // 终端显示区域 (放在按钮下方)
            if (_showTerminal && (_isInstalling || _logs.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: RepaintBoundary(
                  child: _buildTerminalPanel(colorScheme),
                ),
              ),

            const SizedBox(height: 32),


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

  Widget _buildActionArea(ColorScheme colorScheme) {
    if (_isInstalling) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentStatus,
                        style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary),
                      ),
                      if (_progress != null)
                        Text(
                          "已完成 ${(_progress! * 100).toInt()}%",
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.app.installed) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 54,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.redAccent, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _handleAction("-R"),
                child: const Text("卸载", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 54,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("正在启动 ${widget.app.name}...")),
                  );
                },
                icon: const Icon(Icons.rocket_launch_rounded),
                label: const Text("启动程序", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _handleAction("-I"),
        icon: const Icon(Icons.download_rounded),
        label: const Text("立即安装", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTerminalPanel(ColorScheme colorScheme) {
    final isError = _currentStatus.contains("✗") || _currentStatus.contains("Failed");

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isError ? Colors.red.withValues(alpha: 0.5) : colorScheme.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 仿真终端标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.black45,
            child: Row(
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                  ],
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      "TERMINAL OUTPUT",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                const Icon(Icons.code_rounded, size: 14, color: Colors.grey),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 当前状态
                Text(
                  _currentStatus,
                  style: TextStyle(
                    color: isError ? Colors.red : Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
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
                              "Waiting for output...",
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
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 移除 Hero，直接显示图标
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.app.name[0].toUpperCase(),
            style: theme.textTheme.headlineLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.app.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (widget.app.installed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            "已安装",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.app.primarySource,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Contains ads • In-app purchases",
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 核心：监控面板 UI


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
