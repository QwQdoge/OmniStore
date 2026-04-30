import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/app_package.dart';
import '../services/backend_service.dart';
import '../services/l10n_service.dart';

class AppDetailsPage extends StatefulWidget {
  final AppPackage app;

  const AppDetailsPage({super.key, required this.app});

  @override
  State<AppDetailsPage> createState() => _AppDetailsPageState();
}

class _AppDetailsPageState extends State<AppDetailsPage> {
  bool _isInstalling = false;
  final List<String> _logs = [];
  String _statusKey = 'ready';
  List<String>? _statusArgs;
  double? _progress;
  late String _selectedSource;
  late bool _isAppInstalled;
  Map<String, dynamic>? _extraDetails;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    _selectedSource = widget.app.primarySource;
    _isAppInstalled = widget.app.installed;
    _statusKey = 'ready';

    // 即使不是 Flatpak，也尝试获取额外元数据（图标、截图等）
    _fetchExtraDetails();

    // 状态恢复：如果全局正在处理的是这个 App，恢复进行中状态
    final active = BackendService.activeApp.value;
    if (active != null && active.name == widget.app.name) {
      _isInstalling = true;
      _statusKey = BackendService.globalStatus.value;
      _progress = BackendService.globalProgress.value;
    }
  }

  @override
  void dispose() {
    // 不在 dispose 时 kill 进程，因为全局任务应继续运行
    super.dispose();
  }

  Future<void> _fetchExtraDetails() async {
    setState(() => _isLoadingDetails = true);
    final target = widget.app.id ?? widget.app.name;
    final details = await BackendService().getAppDetails(target);
    if (mounted) {
      setState(() {
        _extraDetails = details;
        _isLoadingDetails = false;
      });
    }
  }

  void _cancelAction() {
    BackendService.cancelCurrentTask();
    if (mounted) {
      setState(() {
        _isInstalling = false;
        _statusKey = 'ready';
        _statusArgs = null;
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
                    Text(
                      AppLocalizations.of(context)!.terminalOutput,
                      style: const TextStyle(
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
                        ? Center(
                            child: Text(
                              AppLocalizations.of(context)!.waitingForOutput,
                              style: const TextStyle(color: Colors.grey, fontFamily: 'monospace'),
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
        title: Text(isUninstall ? AppLocalizations.of(context)!.confirmUninstall : AppLocalizations.of(context)!.confirmInstall),
        content: Text(AppLocalizations.of(context)!.confirmActionMsg(widget.app.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            style: isUninstall
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isInstalling = true;
      _logs.clear();
      _progress = null;
      _statusKey = isUninstall ? 'preparing_uninstall' : 'preparing_install';
      _statusArgs = null;
    });

    BackendService.isDownloading.value = true;
    BackendService.globalProgress.value = null;
    BackendService.globalStatus.value = _statusKey;
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
                        _statusKey = log;
                        _statusArgs = null;
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
            _statusKey = isUninstall ? 'uninstall_success' : 'install_success';
            _statusArgs = null;
            _isAppInstalled = !isUninstall;
          } else if (wasCancelled) {
            _isInstalling = false;
            _statusKey = 'task_cancelled';
            _statusArgs = null;
          } else {
            _isInstalling = false;
            _statusKey = 'task_failed_code';
            _statusArgs = [exitCode.toString()];
            _showFailureDialog(flag, exitCode);
          }
        });

        if (exitCode == 0) {
          // 全局通知 Banner（即使用户不在此页面也能看到）
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isUninstall
                    ? L10nService.s('uninstall_success_msg', args: [widget.app.name])
                    : L10nService.s('install_success_msg', args: [widget.app.name])),
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
          _statusKey = 'launch_failed';
          _statusArgs = [e.toString()];
        });
      }
    }
  }

  Future<void> _showFailureDialog(String flag, int exitCode, {String? error}) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 32),
        title: Text(flag == "-I" ? L10nService.s('install_failed') : L10nService.s('uninstall_failed')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                error != null
                    ? L10nService.s('error_with_msg', args: [error])
                    : L10nService.s('exit_code_with_msg', args: [exitCode.toString()]),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              if (_logs.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(L10nService.s('last_logs')),
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
          TextButton(onPressed: () => Navigator.pop(context), child: Text(L10nService.s('close'))),
          FilledButton.tonal(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _logs.clear();
            _statusKey = 'ready';
            _statusArgs = null;
                _progress = null;
              });
            },
            child: Text(L10nService.s('retry')),
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
              tooltip: AppLocalizations.of(context)!.terminalOutput,
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
            _buildSectionTitle(theme, AppLocalizations.of(context)!.about),
            if (_isLoadingDetails)
              const Center(child: CircularProgressIndicator())
            else
              Text(
                _extraDetails?['description'] ??
                    (widget.app.description.isEmpty
                        ? AppLocalizations.of(context)!.noResults
                        : widget.app.description),
                style: theme.textTheme.bodyLarge,
              ),
            const SizedBox(height: 24),
            if (_extraDetails != null &&
                _extraDetails!['screenshots'] != null &&
                (_extraDetails!['screenshots'] as List).isNotEmpty) ...[
              _buildSectionTitle(theme, AppLocalizations.of(context)!.screenshots),
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: (_extraDetails!['screenshots'] as List).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _extraDetails!['screenshots'][index],
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
            _buildSectionTitle(theme, AppLocalizations.of(context)!.details),
            _buildInfoRow(Icons.source, AppLocalizations.of(context)!.source, widget.app.primarySource),
            _buildInfoRow(
                Icons.all_inclusive, AppLocalizations.of(context)!.variant, widget.app.sources.join(", ")),
            _buildInfoRow(Icons.verified_outlined, AppLocalizations.of(context)!.version, widget.app.version),
            if (_extraDetails?['developer'] != null)
              _buildInfoRow(Icons.person_outline, AppLocalizations.of(context)!.developer, _extraDetails!['developer']),
            if (_extraDetails?['license'] != null)
              _buildInfoRow(Icons.description_outlined, AppLocalizations.of(context)!.license, _extraDetails!['license']),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10nService.s('launch_failed', args: [e.toString()]))),
        );
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
                        L10nService.s(_statusKey, args: _statusArgs),
                        style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_progress != null)
                        Text(
                          L10nService.s('completed_percent', args: [(_progress! * 100).toInt().toString()]),
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                  onPressed: _cancelAction,
                  tooltip: L10nService.s('cancel_task'),
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
                child: Text(AppLocalizations.of(context)!.uninstall, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                label: Text(AppLocalizations.of(context)!.launch, style: const TextStyle(fontWeight: FontWeight.bold)),
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
        label: Text(AppLocalizations.of(context)!.install, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final iconUrl = widget.app.icon ?? _extraDetails?['icon'];
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
          child: iconUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(iconUrl, fit: BoxFit.cover),
                )
              : Text(
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
                            AppLocalizations.of(context)!.ready,
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
                  items: {
                    if (widget.app.sources.isNotEmpty)
                      ...widget.app.sources
                    else
                      widget.app.primarySource,
                    if (widget.app.sources.isEmpty || !widget.app.sources.contains(_selectedSource))
                      _selectedSource,
                  }.map((String source) {
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
