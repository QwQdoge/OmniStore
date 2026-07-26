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
    if (trimmed.contains('\x00')) {
      throw ArgumentError("Null bytes forbidden in $name");
    }
    if (RegExp(r'''[;&|`$()\\'"]''').hasMatch(trimmed)) {
      throw ArgumentError(
        "Invalid characters in $name: Security policy forbids shell metacharacters.",
      );
    }
  }

  /// Search queries support source filters and repository qualifiers such as
  /// source:github stars:>5000 sort:stars, while still blocking shell syntax.
  static void validateSearchQuery(String? val, String name) {
    if (val == null || val.trim().isEmpty) {
      throw ArgumentError("$name cannot be null or empty");
    }
    final trimmed = val.trim();
    if (trimmed.length > 500) {
      throw ArgumentError("$name is too long (max 500 characters)");
    }
    if (trimmed.contains('\x00')) {
      throw ArgumentError("Null bytes forbidden in $name");
    }
    if (RegExp(r'''[;&|`$()\\'"]''').hasMatch(trimmed)) {
      throw ArgumentError(
        "Security: $name contains forbidden shell metacharacters.",
      );
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
    if (RegExp(r'''[;&|`$()\\'"]''').hasMatch(trimmed)) {
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
    if (trimmed.contains('\x00')) {
      throw ArgumentError("Null bytes forbidden in path");
    }
    if (trimmed.contains('..')) {
      throw ArgumentError(
        "Security: Relative path traversal ('..') is strictly forbidden.",
      );
    }
    if (RegExp(r'''[;&|`$()\\'"]''').hasMatch(trimmed)) {
      throw ArgumentError(
        "Invalid characters in path: Security policy forbids shell metacharacters.",
      );
    }
  }
}
