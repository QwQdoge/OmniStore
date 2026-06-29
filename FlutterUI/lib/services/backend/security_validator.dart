class SecurityValidator {
  /// Murphy-proof: Strict string validation to prevent shell injection and malformed inputs.
  static void validateString(String? val, String name) {
    if (val == null || val.trim().isEmpty) {
      throw ArgumentError("$name cannot be null or empty");
    }
    final trimmed = val.trim();
    if (trimmed.length > 1024) {
      throw ArgumentError("$name is too long (max 1024 characters)");
    }
    // Allow alphanumeric, dots, underscores, dashes, slashes, and spaces.
    // Strictly forbid characters like ; & | ` $ ( ) < > \ ' "
    if (!RegExp(r'^[a-zA-Z0-9._/ -]+$').hasMatch(trimmed)) {
      throw ArgumentError(
          "Invalid characters in $name: Security policy forbids shell metacharacters.");
    }
  }

  /// Murphy-proof: Strict URL validation.
  static void validateUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      throw ArgumentError("URL cannot be null or empty");
    }
    final trimmed = url.trim();
    if (trimmed.length > 2048) {
      throw ArgumentError("URL is too long");
    }
    // Allow basic URL characters, but strictly forbid shell metacharacters.
    if (!RegExp(r'^[a-zA-Z0-9._/:\-?=&%+#]+$').hasMatch(trimmed)) {
      throw ArgumentError("Invalid characters in URL");
    }
    // Explicitly check for dangerous characters even if the regex missed them
    if (trimmed.contains(';') ||
        trimmed.contains('|') ||
        trimmed.contains('`') ||
        trimmed.contains('\$') ||
        trimmed.contains('(') ||
        trimmed.contains(')') ||
        trimmed.contains('<') ||
        trimmed.contains('>') ||
        trimmed.contains('\\')) {
      throw ArgumentError("Security: Shell metacharacters detected in URL");
    }
  }

  /// Murphy-proof: Strict path validation to prevent traversal attacks.
  static void validatePath(String? path) {
    if (path == null || path.trim().isEmpty) {
      throw ArgumentError("Path cannot be null or empty");
    }
    final trimmed = path.trim();
    if (trimmed.length > 1024) {
      throw ArgumentError("Path is too long");
    }
    if (trimmed.contains('..')) {
      throw ArgumentError(
          "Security: Relative path traversal ('..') is strictly forbidden.");
    }
    // Cross-platform support: Allow Windows-style paths (C:\...)
    if (!RegExp(r'^[a-zA-Z0-9._/\\: -]+$').hasMatch(trimmed)) {
      throw ArgumentError(
          "Invalid characters in path: Security policy forbids shell metacharacters.");
    }
  }
}
