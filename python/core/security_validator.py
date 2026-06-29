import re
import os
from typing import Optional, Any

class SecurityValidator:
    """
    Murphy-proof: Centralized security validation for the Python backend.
    Enforces strict boundary defenses against shell injection, path traversal,
    and malformed inputs.
    """

    # Strictly forbid characters like ; & | ` $ ( ) < > \ ' "
    # Allowing alphanumeric, dots, underscores, dashes, slashes, and spaces.
    SAFE_STRING_RE = re.compile(r'^[a-zA-Z0-9._/ -]+$')

    # Cross-platform path regex (allows Windows drive letters and backslashes if needed,
    # but we primarily target Linux as per main.py warning)
    SAFE_PATH_RE = re.compile(r'^[a-zA-Z0-9._/\\: -]+$')

    # URL validation: alphanumeric, dots, underscores, slashes, colons, dashes, question marks, equals, ampersands, percent, plus, hash
    SAFE_URL_RE = re.compile(r'^[a-zA-Z0-9._/:\-?=&%+#]+$')

    @classmethod
    def validate_string(cls, val: Optional[str], name: str = "Input", max_length: int = 1024) -> str:
        """Murphy-proof string validation."""
        if val is None:
            raise ValueError(f"{name} cannot be null")

        trimmed = val.strip()
        if not trimmed:
            raise ValueError(f"{name} cannot be empty")

        if len(trimmed) > max_length:
            raise ValueError(f"{name} is too long (max {max_length} characters)")

        if not cls.SAFE_STRING_RE.match(trimmed):
            raise ValueError(f"Security: {name} contains forbidden characters or shell metacharacters.")

        return trimmed

    @classmethod
    def validate_path(cls, path: Optional[str], name: str = "Path", max_length: int = 1024) -> str:
        """Murphy-proof path validation to prevent traversal attacks."""
        if path is None:
            raise ValueError(f"{name} cannot be null")

        trimmed = path.strip()
        if not trimmed:
            raise ValueError(f"{name} cannot be empty")

        if len(trimmed) > max_length:
            raise ValueError(f"{name} is too long")

        if ".." in trimmed:
            raise ValueError(f"Security: Relative path traversal ('..') is strictly forbidden in {name}.")

        if not cls.SAFE_PATH_RE.match(trimmed):
            raise ValueError(f"Security: {name} contains forbidden characters.")

        return trimmed

    @classmethod
    def validate_url(cls, url: Optional[str], name: str = "URL") -> str:
        """Murphy-proof URL validation."""
        if url is None:
            raise ValueError(f"{name} cannot be null")

        trimmed = url.strip()
        if not trimmed:
            raise ValueError(f"{name} cannot be empty")

        if any(c in trimmed for c in ";|`$()<>\\'\""):
             raise ValueError(f"Security: Shell metacharacters detected in {name}.")

        if not cls.SAFE_URL_RE.match(trimmed):
            raise ValueError(f"Security: {name} contains invalid characters.")

        return trimmed

    @classmethod
    def validate_action_flag(cls, flag: str) -> str:
        """Ensures action flags are limited to a safe set."""
        allowed = {"-I", "-R", "-U", "-S", "-L", "-C"}
        if flag not in allowed:
            raise ValueError(f"Security: Invalid action flag '{flag}'.")
        return flag
