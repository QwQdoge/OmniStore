import 'package:flutter/material.dart';

class Toast {
  static void show(BuildContext context, String message, {Duration duration = const Duration(seconds: 4), SnackBarAction? action}) {
    if (!context.mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    if (scaffoldMessenger != null) {
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
          action: action,
        ),
      );
    }
  }
}
