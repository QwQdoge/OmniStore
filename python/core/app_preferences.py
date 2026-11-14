"""App-maintenance preferences shared by OmniStore and Meo Settings.

Meo Settings reads and writes these through the stable `omnistore-apps
preferences` / `omnistore-apps set-preferences` ABI; it never edits
OmniStore's YAML itself. The background check (`meo-update background`)
applies them:

* ``autoUpdate`` - install updates for per-user Flatpak applications in the
  background. System packages (pacman/AUR) need an authorized transaction and
  are never upgraded unattended from a user session.
* ``notifyUpdates`` - send a desktop notification when updates are found.
* ``cacheLimitMb`` - when the caches of installed applications together grow
  beyond this size, remove the largest caches until they fit again
  (0 turns automatic cache cleanup off). Only directories that the reviewed
  application manifests declare as *cache* are touched; configuration and
  data are never removed by this policy.
"""

from __future__ import annotations

import asyncio
import shutil
from pathlib import Path
from typing import Any, Iterable, Mapping

from core.app_management import (
    ManifestRegistry,
    _remove_target,
    _tree_size,
    _unwrap_packages,
    storage_targets,
)

SCHEMA = "org.meo.omnistore.app-preferences"
SCHEMA_VERSION = 1

CACHE_LIMIT_CHOICES_MB = (0, 256, 512, 1024, 2048, 5120, 10240)

_DEFAULTS = {"autoUpdate": False, "notifyUpdates": True, "cacheLimitMb": 0}


def read_preferences(config: Any) -> dict[str, Any]:
    """Current preferences with defaults for missing or malformed values."""
    auto_update = config.get("updates.auto_update_apps", None)
    if not isinstance(auto_update, bool):
        # Older configurations only had the daemon switch.
        auto_update = bool(config.get("daemon.auto_update", _DEFAULTS["autoUpdate"]))
    notify = config.get("updates.remind_updates", _DEFAULTS["notifyUpdates"])
    limit = config.get("updates.app_cache_limit_mb", _DEFAULTS["cacheLimitMb"])
    if not isinstance(limit, int) or isinstance(limit, bool) or limit not in CACHE_LIMIT_CHOICES_MB:
        limit = _DEFAULTS["cacheLimitMb"]
    return {
        "schema": SCHEMA,
        "version": SCHEMA_VERSION,
        "status": "success",
        "autoUpdate": bool(auto_update),
        "notifyUpdates": bool(notify),
        "cacheLimitMb": limit,
        "cacheLimitChoicesMb": list(CACHE_LIMIT_CHOICES_MB),
    }


def validate_changes(changes: Any) -> dict[str, Any]:
    """Return a sanitized subset of ``changes`` or raise ValueError."""
    if not isinstance(changes, Mapping) or not changes:
        raise ValueError("invalid_preferences")
    clean: dict[str, Any] = {}
    for key, value in changes.items():
        if key in ("autoUpdate", "notifyUpdates"):
            if not isinstance(value, bool):
                raise ValueError("invalid_preferences")
            clean[key] = value
        elif key == "cacheLimitMb":
            if isinstance(value, bool) or not isinstance(value, int) or value not in CACHE_LIMIT_CHOICES_MB:
                raise ValueError("invalid_preferences")
            clean[key] = value
        else:
            raise ValueError("invalid_preferences")
    return clean


def apply_preferences(config: Any, changes: Any) -> dict[str, Any]:
    """Persist validated changes and return the resulting preferences."""
    clean = validate_changes(changes)
    data = config.data  # deep copy of the current configuration
    updates = data.setdefault("updates", {})
    daemon = data.setdefault("daemon", {})
    if "autoUpdate" in clean:
        updates["auto_update_apps"] = clean["autoUpdate"]
        daemon["auto_update"] = clean["autoUpdate"]
    if "notifyUpdates" in clean:
        updates["remind_updates"] = clean["notifyUpdates"]
        daemon["notifications"] = clean["notifyUpdates"]
    if "cacheLimitMb" in clean:
        updates["app_cache_limit_mb"] = clean["cacheLimitMb"]
    if not config.save(data):
        raise RuntimeError("preferences_not_saved")
    return read_preferences(config)


def _cache_entries(
    packages: Iterable[Mapping[str, Any]],
    *,
    registry: ManifestRegistry | None,
    home: Path | None,
) -> list[tuple[int, str, Path]]:
    entries: list[tuple[int, str, Path]] = []
    seen: set[Path] = set()
    for package in packages:
        if package.get("installed") is not True:
            continue
        targets, _manifest = storage_targets(package, registry=registry, home=home)
        for target in targets:
            if target.category != "cache" or target.path in seen or not target.path.exists():
                continue
            if target.path.is_symlink():
                continue
            seen.add(target.path)
            size, _complete = _tree_size(target.path)
            entries.append((size, str(package.get("name") or ""), target.path))
    return entries


def trim_caches(
    packages: Iterable[Mapping[str, Any]],
    limit_bytes: int,
    *,
    registry: ManifestRegistry | None = None,
    home: Path | None = None,
) -> dict[str, Any]:
    """Remove the largest application caches until the total fits the limit."""
    entries = _cache_entries(packages, registry=registry, home=home)
    total = sum(size for size, _name, _path in entries)
    result: dict[str, Any] = {
        "schema": SCHEMA,
        "version": SCHEMA_VERSION,
        "status": "success",
        "cacheBytesBefore": total,
        "limitBytes": limit_bytes,
        "bytesFreed": 0,
        "cleared": [],
    }
    if limit_bytes <= 0 or total <= limit_bytes:
        result["cacheBytesAfter"] = total
        return result
    freed = 0
    for size, name, path in sorted(entries, key=lambda item: item[0], reverse=True):
        if total - freed <= limit_bytes:
            break
        try:
            removed = _remove_target(path)
        except (OSError, RuntimeError):
            continue
        freed += removed
        result["cleared"].append({"name": name, "bytes": removed})
    result["bytesFreed"] = freed
    result["cacheBytesAfter"] = max(0, total - freed)
    return result


async def trim_caches_for_backend(
    backend: Any,
    limit_mb: int | None = None,
    *,
    registry: ManifestRegistry | None = None,
    home: Path | None = None,
) -> dict[str, Any]:
    if limit_mb is None:
        limit_mb = read_preferences(backend.config)["cacheLimitMb"]
    result = await backend.run_list_installed(json_mode=False)
    packages = _unwrap_packages(result)
    return await asyncio.to_thread(
        trim_caches, packages, int(limit_mb) * 1024 * 1024, registry=registry, home=home
    )


async def auto_update_user_apps(updates: Any) -> bool:
    """Update per-user Flatpak applications; never touches system packages."""
    if not isinstance(updates, list):
        return False
    if not any(isinstance(item, Mapping) and item.get("source") == "Flatpak" for item in updates):
        return False
    if not shutil.which("flatpak"):
        return False
    try:
        process = await asyncio.create_subprocess_exec(
            "flatpak", "update", "--user", "-y", "--noninteractive",
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL,
        )
        await asyncio.wait_for(process.wait(), timeout=1800)
        return process.returncode == 0
    except (OSError, asyncio.TimeoutError):
        return False
