import 'package:flutter/material.dart';

class ImportPackagesDialog extends StatelessWidget {
  final int packagesCount;
  final String titleText;
  final String contentText;
  final String cancelText;
  final String confirmText;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const ImportPackagesDialog({
    super.key,
    required this.packagesCount,
    required this.titleText,
    required this.contentText,
    required this.cancelText,
    required this.confirmText,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      icon: Icon(
        Icons.file_upload_rounded,
        color: theme.colorScheme.primary,
        size: 32,
      ),
      title: Text(
        titleText,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        textAlign: TextAlign.center,
      ),
      content: Text(
        contentText,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      actions: [
        TextButton(onPressed: onCancel, child: Text(cancelText)),
        FilledButton(onPressed: onConfirm, child: Text(confirmText)),
      ],
    );
  }
}
