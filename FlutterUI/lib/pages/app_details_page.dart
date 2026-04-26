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
  double? _progress;
  late String _selectedSource;
  late bool _isAppInstalled;

  @override
  void initState() {
    super.initState();
    _selectedSource = widget.app.primarySource;
    _isAppInstalled = widget.app.installed;

    // 状态恢复：如果全局正在处理的是这个 App，恢复进行中状态
    final active = BackendService.activeApp.value;
    if (active != null && active.name == widget.app.name) {
      _isInstalling = true;
      _currentStatus = BackendService.globalStatus.value;
      _progress = BackendService.globalProgress.value;
    }
  }

  @override
  void dispose() {
    // 不在 dispose 时 kill 进程，因为全局任务应继续运行
    super.dispose();
  }

  void _cancelAction() {
    BackendService.cancelCurrentTask();
    if (mounted) {
      setState(() {
        _isInstalling = false;
        _currentStatus = "Ready";
        _progress = null;
      });
    }
  }

  void _showTerminalDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: SizedBox(
          width: 600,
          height: 400,
          child: Column(
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      "Terminal Output",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close, color: Colors.white54, size: 18),
                    ),
                  ],
                ),
              ),
              // 日志内容
              Expanded(
                child: StatefulBuilder(
                  builder: (context, setInnerState) {
                    // 监听全局状态更新日志
                    return _logs.isEmpty
                        ? const Center(
                            child: Text(
                              "Waiting for output...",
                              style: TextStyle(color: Colors.grey, fontFamily: 'monospace'),
                            ),
                          )
                        : ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.all(12),
                            itemCount: _logs.length,
                            itemBuilder: (context, i) {
                              final log = _logs[_logs.length - 1 - i];
                              Color textColor = const Color(0xFFD4D4D4);
                              if (log.startsWith("[ERROR]")) textColor = Colors.redAccent;
                              if (log.startsWith("[INFO]")) textColor = Colors.greenAccent.shade400;
                              return Text(
                                log,
                                style: TextStyle(
                                  color: textColor,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              );
                            },
                          );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(String flag) async {
    if (_isInstalling) return;

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

    setState(() {
      _isInstalling = true;
      _logs.clear();
      _progress = null;
      _currentStatus = isUninstall ? "正在准备卸载..." : "正在准备安装...";
    });

    BackendService.isDownloading.value = true;
    BackendService.globalProgress.value = null;
    BackendService.globalStatus.value = _currentStatus;
    BackendService.activeApp.value = widget.app;
    BackendService.activeFlag.value = flag;

    try {
      final process = await Process.start(
        '/home/shekong/Projects/Omnistore/python/.venv/bin/python',
        [
          '/home/shekong/Projects/Omnistore/python/main.py',
          flag,
          widget.app.name.trim(),
          '--source', _selectedSource,
          if (widget.app.url != null && flag == "-I") ...['--url', widget.app.url!],
          '--json',
        ],
        workingDirectory: '/home/shekong/Projects/Omnistore/python',
      );
      BackendService.activeProcess = process;

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
              setState(() {
                String log = data!['message'] ?? data['log'] ?? "";
                if (log.isNotEmpty) {
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
                    _logs.add(log);
                    if (log.startsWith("[INFO]") || log.startsWith("[ERROR]")) {
                      _currentStatus = log;
                      BackendService.globalStatus.value = log;
                    }
                  }
                }
              });
            }
          });

      process.stderr.transform(utf8.decoder).listen((err) {
        debugPrint("PYTHON STDERR: $err");
        if (mounted) setState(() => _logs.add("stderr: $err"));
      });

      final exitCode = await process.exitCode;

      BackendService.activeApp.value = null;
      BackendService.activeFlag.value = null;
      BackendService.activeProcess = null;

      if (mounted) {
        final wasCancelled = exitCode != 0 && !BackendService.isDownloading.value;

        setState(() {
          BackendService.isDownloading.value = false;
          if (exitCode == 0) {
            _progress = 1.0;
            _currentStatus = isUninstall ? "✓ 卸载成功" : "✓ 安装成功";
            _isAppInstalled = !isUninstall;
          } else if (wasCancelled) {
            _isInstalling = false;
            _currentStatus = "任务已取消";
          } else {
            _isInstalling = false;
            _currentStatus = "✗ 失败 (错误码: $exitCode)";
            _showFailureDialog(flag, exitCode);
          }
        });

        if (exitCode == 0) {
          // 全局通知 Banner（即使用户不在此页面也能看到）
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isUninstall ? "${widget.app.name} 卸载成功" : "${widget.app.name} 安装成功"),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) setState(() => _isInstalling = false);
        }
      }
    } catch (e) {
      BackendService.activeApp.value = null;
      BackendService.activeProcess = null;
      if (mounted) {
        setState(() {
          _isInstalling = false;
          _currentStatus = "✗ 启动失败: $e";
        });
      }
    }
  }

  Future<void> _showFailureDialog(String flag, int exitCode, {String? error}) async {
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
                      style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("关闭")),
          FilledButton.tonal(
            onPressed: () {
              Navigator.pop(context);
              setState(() { _logs.clear(); _currentStatus = "Ready"; _progress = null; });
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
        title: Text(widget.app.name),
        actions: [
          if (_isInstalling || _logs.isNotEmpty)
            IconButton(
              icon: Badge(
                isLabelVisible: _isInstalling,
                child: const Icon(Icons.terminal_outlined),
              ),
              tooltip: "查看终端输出",
              onPressed: _showTerminalDialog,
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
            const SizedBox(height: 32),
            const Divider(),
            _buildSectionTitle(theme, "关于此软件"),
            Text(widget.app.description, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 32),
            _buildSectionTitle(theme, "详细参数"),
            _buildInfoRow(Icons.source, "来源", widget.app.primarySource),
            _buildInfoRow(Icons.all_inclusive, "变体", widget.app.sources.join(", ")),
            _buildInfoRow(Icons.verified_outlined, "版本", widget.app.version),
          ],
        ),
      ),
    );
  }

  Future<void> _launchApp() async {
    String target = (widget.app.id != null && _selectedSource == "Flatpak")
        ? widget.app.id!
        : widget.app.name.trim();

    try {
      await Process.start(
        '/home/shekong/Projects/Omnistore/python/.venv/bin/python',
        ['/home/shekong/Projects/Omnistore/python/main.py', '--launch', target, '--source', _selectedSource],
        workingDirectory: '/home/shekong/Projects/Omnistore/python',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("启动失败: $e")));
      }
    }
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
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_progress != null)
                        Text(
                          "已完成 ${(_progress! * 100).toInt()}%",
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                  onPressed: _cancelAction,
                  tooltip: "取消任务",
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

    if (_isAppInstalled) {
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
                onPressed: _launchApp,
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

  Widget _buildHeader(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  if (_isAppInstalled)
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
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSource,
                  isDense: true,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  items: [
                    if (widget.app.sources.isNotEmpty)
                      ...widget.app.sources
                    else
                      widget.app.primarySource,
                    if (widget.app.sources.isEmpty || !widget.app.sources.contains(_selectedSource))
                      _selectedSource,
                  ].toSet().map((String source) {
                    return DropdownMenuItem<String>(value: source, child: Text(source));
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null && mounted) {
                      setState(() => _selectedSource = newValue);
                    }
                  },
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.app.version,
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
