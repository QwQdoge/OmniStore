import 'package:flutter/material.dart';

class SettingsTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onChanged;
  final bool isPassword;
  final String? errorText;
  final String? helperText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final Widget? suffixIcon;
  final bool showApiKey;

  const SettingsTextField(
    this.label,
    this.controller,
    this.focusNode,
    this.onChanged, {
    super.key,
    this.isPassword = false,
    this.errorText,
    this.helperText,
    this.keyboardType,
    this.autofillHints,
    this.suffixIcon,
    this.showApiKey = false,
  });

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
          errorText: errorText,
          helperText: helperText,
          suffixIcon: suffixIcon,
        ),
        obscureText: isPassword && !showApiKey,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        enableSuggestions: !isPassword,
        autocorrect: !isPassword,
        onChanged: onChanged,
      ),
    );
  }}
