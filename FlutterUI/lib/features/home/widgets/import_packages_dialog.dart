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
    return AlertDialog(
      title: Text(titleText),
      content: Text(contentText),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(cancelText),
        ),
        FilledButton(
          onPressed: onConfirm,
          child: Text(confirmText),
        ),
      ],
    );
  }
}
