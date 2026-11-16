"""Per-OS locations for configuration, cache, state and runtime files.

Linux keeps the XDG layout it always had. macOS and Windows use their native
locations. An explicit XDG_* variable always wins, on every OS, so tests and
power users can redirect everything.
"""

import os
import sys
from pathlib import Path


def _home() -> Path:
    return Path.home()


def _windows_dir(variable: str, fallback: Path) -> Path:
    value = os.environ.get(variable, "").strip()
    return Path(value) if value else fallback


def config_dir() -> Path:
    xdg = os.environ.get("XDG_CONFIG_HOME")
    if xdg:
        return Path(xdg) / "omnistore"
    if sys.platform == "win32":
        return _windows_dir("APPDATA", _home() / "AppData" / "Roaming") / "OmniStore"
    if sys.platform == "darwin":
        return _home() / "Library" / "Application Support" / "OmniStore"
    return _home() / ".config" / "omnistore"


def cache_dir() -> Path:
    xdg = os.environ.get("XDG_CACHE_HOME")
    if xdg:
        return Path(xdg) / "omnistore"
    if sys.platform == "win32":
        return _windows_dir("LOCALAPPDATA", _home() / "AppData" / "Local") / "OmniStore" / "Cache"
    if sys.platform == "darwin":
        return _home() / "Library" / "Caches" / "OmniStore"
    return _home() / ".cache" / "omnistore"


def state_root() -> Path:
    """Parent of per-tool state folders (``meo-update`` lives under it)."""
    xdg = os.environ.get("XDG_STATE_HOME")
    if xdg:
        return Path(xdg)
    if sys.platform == "win32":
        return _windows_dir("LOCALAPPDATA", _home() / "AppData" / "Local") / "OmniStore" / "State"
    if sys.platform == "darwin":
        return _home() / "Library" / "Application Support" / "OmniStore" / "State"
    return _home() / ".local" / "state"


def runtime_dir() -> Path:
    """Per-user directory for sockets and lock files."""
    xdg = os.environ.get("XDG_RUNTIME_DIR")
    if xdg:
        return Path(xdg)
    if sys.platform.startswith("linux") and hasattr(os, "getuid"):
        preferred = Path("/run/user") / str(os.getuid())
        if preferred.is_dir():
            return preferred
    return cache_dir()


def is_root() -> bool:
    return hasattr(os, "geteuid") and os.geteuid() == 0
