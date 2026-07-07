import re
import os
import json
from typing import Optional, Any

class SecurityValidator:
    """
    Murphy-proof: Centralized security validation for the Python backend.
    Enforces strict boundary defenses against shell injection, path traversal,
    and malformed inputs using a Whitelist-only (Positive Security) model.
    """

    # Whitelist for general strings: Alphanumeric, dots, underscores, dashes, slashes, spaces, pluses, at-signs, and colons.
    # Allowing @ for npm/scoped packages, + for versioning, and : for namespaces/urls.
    SAFE_STRING_RE = re.compile(r'^[a-zA-Z0-9._/ +\-@:]+$')

    # Cross-platform path whitelist
    SAFE_PATH_RE = re.compile(r'^[a-zA-Z0-9._/\\: -]+$')

    # Strict URL whitelist (No shell metacharacters allowed)
    SAFE_URL_RE = re.compile(r'^https?://[a-zA-Z0-9._/:\-?=&%+#@]+$')

    # Extremely strict alphanumeric-only with minimal separators
    STRICT_ALNUM_RE = re.compile(r'^[a-zA-Z0-9._\-@:]+$')

    @classmethod
    def validate_string(cls, val: Optional[str], name: str = "Input", max_length: int = 1024) -> str:
        """Murphy-proof string validation (Whitelist-only)."""
        if val is None:
            raise ValueError(f"{name} cannot be null")

        trimmed = val.strip()
        if not trimmed:
            if name == "App Description": return ""
            raise ValueError(f"{name} cannot be empty")

        if len(trimmed) > max_length:
            raise ValueError(f"{name} exceeds max length of {max_length}")

        if not cls.SAFE_STRING_RE.match(trimmed):
            raise ValueError(f"Security Policy Violation: {name} contains forbidden characters. Only alphanumeric and safe symbols (. _ / + - @ :) are allowed.")

        return trimmed

    @classmethod
    def validate_path(cls, path: Optional[str], name: str = "Path", max_length: int = 4096) -> str:
        """Murphy-proof path validation with strict traversal prevention."""
        if path is None:
            raise ValueError(f"{name} cannot be null")

        trimmed = path.strip()
        if not trimmed:
            raise ValueError(f"{name} cannot be empty")

        if len(trimmed) > max_length:
            raise ValueError(f"{name} path too long")

        # Absolute prevention of relative traversal
        norm_path = os.path.normpath(trimmed)
        if ".." in norm_path.split(os.sep) or trimmed.startswith(".."):
            raise ValueError(f"Security: Path traversal ('..') detected in {name}.")

        if not cls.SAFE_PATH_RE.match(trimmed):
            raise ValueError(f"Security: {name} contains illegal characters.")

        return trimmed

    @classmethod
    def validate_url(cls, url: Optional[str], name: str = "URL") -> str:
        """Murphy-proof URL validation (HTTPS/HTTP Whitelist)."""
        if url is None:
            raise ValueError(f"{name} cannot be null")

        trimmed = url.strip()
        if not trimmed:
            raise ValueError(f"{name} cannot be empty")

        if not cls.SAFE_URL_RE.match(trimmed):
            raise ValueError(f"Security: {name} is not a valid or safe URL (must be http/https and contain only safe characters).")

        if len(trimmed) > 2048:
            raise ValueError(f"Security: {name} exceeds length limit.")

        return trimmed

    @classmethod
    def validate_strict_id(cls, val: Optional[str], name: str = "ID") -> str:
        """Extremely strict validation for IDs/Identifiers (No spaces allowed)."""
        if not val:
            raise ValueError(f"{name} is missing.")
        trimmed = val.strip()
        if not cls.STRICT_ALNUM_RE.match(trimmed):
             raise ValueError(f"Security: {name} must be alphanumeric (dots, underscores, dashes, @, : allowed).")
        return trimmed

    @classmethod
    def validate_action_flag(cls, flag: str) -> str:
        """Ensures action flags are limited to a strictly predefined set."""
        allowed = {"-I", "-R", "-U", "-S", "-L", "-C"}
        if flag not in allowed:
            raise ValueError(f"Security Violation: Invalid action flag '{flag}'.")
        return flag

    @classmethod
    def validate_payload_size(cls, data: str, limit_mb: int = 10) -> str:
        """Murphy-proof: Reject oversized payloads before processing to prevent OOM."""
        if len(data.encode('utf-8')) > limit_mb * 1024 * 1024:
            raise ValueError(f"Security: Payload size exceeds {limit_mb}MB limit.")
        return data

    @classmethod
    def safe_json_load(cls, data: str, limit_mb: int = 10) -> Any:
        """Murphy-proof JSON loader with size-limit enforcement."""
        cls.validate_payload_size(data, limit_mb)
        try:
            return json.loads(data)
        except json.JSONDecodeError as e:
            raise ValueError(f"Malformed JSON payload: {str(e)}")
