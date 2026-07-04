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

    # Cross-platform path regex
    SAFE_PATH_RE = re.compile(r'^[a-zA-Z0-9._/\\: -]+$')

    # URL validation
    SAFE_URL_RE = re.compile(r'^[a-zA-Z0-9._/:\-?=&%+#]+$')

    # Alphanumeric with basic separators only
    STRICT_ALNUM_RE = re.compile(r'^[a-zA-Z0-9._-]+$')

    @classmethod
    def validate_string(cls, val: Optional[str], name: str = "Input", max_length: int = 1024) -> str:
        """Murphy-proof string validation."""
        if val is None:
            raise ValueError(f"{name} cannot be null")

        trimmed = val.strip()
        if not trimmed:
            # For descriptions, we might allow empty but valid strings
            if name == "App Description":
                return ""
            raise ValueError(f"{name} cannot be empty")

        if len(trimmed) > max_length:
            raise ValueError(f"{name} is too long (max {max_length} characters)")

        if not cls.SAFE_STRING_RE.match(trimmed):
            raise ValueError(f"Security: {name} contains forbidden characters or shell metacharacters.")

        return trimmed

    @classmethod
    def validate_path(cls, path: Optional[str], name: str = "Path", max_length: int = 4096) -> str:
        """Murphy-proof path validation to prevent traversal attacks."""
        if path is None:
            raise ValueError(f"{name} cannot be null")

        trimmed = path.strip()
        if not trimmed:
            raise ValueError(f"{name} cannot be empty")

        if len(trimmed) > max_length:
            raise ValueError(f"{name} is too long")

        # Normalize path to check for traversal
        norm_path = os.path.normpath(trimmed)
        if ".." in norm_path.split(os.sep):
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

        if len(trimmed) > 2048:
            raise ValueError(f"Security: {name} is too long.")

        return trimmed

    @classmethod
    def validate_strict_id(cls, val: Optional[str], name: str = "ID") -> str:
        """Extremely strict validation for IDs/Identifiers."""
        if not val:
            raise ValueError(f"{name} is missing.")
        trimmed = val.strip()
        if not cls.STRICT_ALNUM_RE.match(trimmed):
             raise ValueError(f"Security: {name} contains illegal characters. Only alphanumeric, dot, underscore, and dash allowed.")
        return trimmed

    @classmethod
    def validate_action_flag(cls, flag: str) -> str:
        """Ensures action flags are limited to a safe set."""
        allowed = {"-I", "-R", "-U", "-S", "-L", "-C"}
        if flag not in allowed:
            raise ValueError(f"Security: Invalid action flag '{flag}'.")
        return flag
