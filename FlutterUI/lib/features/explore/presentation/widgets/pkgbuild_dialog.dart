import 'package:flutter/material.dart';
import 'package:frontend/services/backend_service.dart';

class PKGBUILDReviewDialog extends StatefulWidget {
  final String packageName;
  final VoidCallback onConfirm;

  const PKGBUILDReviewDialog({
    super.key,
    required this.packageName,
    required this.onConfirm,
  });

  static Future<bool?> show(BuildContext context, String packageName) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PKGBUILDReviewDialog(
        packageName: packageName,
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );
  }

  @override
  State<PKGBUILDReviewDialog> createState() => _PKGBUILDReviewDialogState();
}

class _PKGBUILDReviewDialogState extends State<PKGBUILDReviewDialog> {
  String? _pkgbuildContent;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPKGBUILD();
  }

  Future<void> _loadPKGBUILD() async {
    final content = await BackendService.instance.getPkgbuild(widget.packageName);
    if (mounted) {
      setState(() {
        _pkgbuildContent = content;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.code_rounded, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AUR PKGBUILD 审核: ${widget.packageName}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 640,
        height: 420,
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在从 AUR 抓取 PKGBUILD 源码...'),
                  ],
                ),
              )
            : Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _pkgbuildContent ?? '# 无内容',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消安装'),
        ),
        FilledButton.icon(
          onPressed: _isLoading ? null : widget.onConfirm,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('确认安装 (PKGBUILD 已审核)'),
        ),
      ],
    );
  }
}
