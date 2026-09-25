"""Stable OmniStore application-management ABI for Meo Settings.

The contract keeps package-manager ownership in OmniStore while exposing a
bounded app inventory, app-scoped storage, optional settings-provider metadata,
and a small set of explicit maintenance actions.

Destructive filesystem actions are limited to either:
* a verified Flatpak sandbox root (~/.var/app/<app-id>), or
* trusted system manifests installed by OmniStore/MeoArch.

No caller-provided filesystem path is ever accepted.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
from typing import Any, Iterable, Mapping, Sequence

from core.apps_usage_export import (
    _normalized_size,
    _safe_text,
    _source_id,
    _unwrap_packages,
)

SCHEMA = "org.meo.omnistore.app-management"
SCHEMA_VERSION = 1
MANIFEST_SCHEMA = "org.meo.omnistore.app-manifest"
MANIFEST_VERSION = 1

_MAX_APPS = 10_000
_MAX_TARGETS_PER_CATEGORY = 16
_MAX_SCAN_ENTRIES = 50_000
_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._+@-]{0,255}$")
_RELATIVE_RE = re.compile(r"^[^\x00]+$")


@dataclass(frozen=True)
class StorageTarget:
    category: str
    path: Path
    display_path: str
    provenance: str


def _xdg_root(kind: str, home: Path) -> Path:
    env_names = {
        "config": "XDG_CONFIG_HOME",
        "cache": "XDG_CACHE_HOME",
        "data": "XDG_DATA_HOME",
        "state": "XDG_STATE_HOME",
    }
    defaults = {
        "config": home / ".config",
        "cache": home / ".cache",
        "data": home / ".local/share",
        "state": home / ".local/state",
        "home": home,
    }
    if kind == "home":
        return home
    raw = os.environ.get(env_names[kind], "").strip()
    return Path(raw).expanduser() if raw else defaults[kind]


def _safe_relative(value: Any) -> Path | None:
    if not isinstance(value, str) or not value or not _RELATIVE_RE.match(value):
        return None
    candidate = Path(value)
    if candidate.is_absolute() or any(part in ("", ".", "..") for part in candidate.parts):
        return None
    return candidate


def _contained(candidate: Path, base: Path) -> bool:
    try:
        resolved_candidate = candidate.resolve(strict=False)
        resolved_base = base.resolve(strict=False)
        return resolved_candidate != resolved_base and resolved_candidate.is_relative_to(resolved_base)
    except (OSError, RuntimeError, ValueError):
        return False


def _display_path(path: Path, home: Path) -> str:
    try:
        relative = path.resolve(strict=False).relative_to(home.resolve(strict=False))
        return "~/" + relative.as_posix()
    except (OSError, RuntimeError, ValueError):
        return path.as_posix()


def _tree_size(path: Path, *, limit: int = _MAX_SCAN_ENTRIES) -> tuple[int, bool]:
    """Return (bytes, complete) without following symlinks."""
    if not path.exists() or path.is_symlink():
        return 0, True
    if path.is_file():
        try:
            return path.stat(follow_symlinks=False).st_size, True
        except OSError:
            return 0, False

    total = 0
    seen = 0
    stack = [path]
    while stack:
        directory = stack.pop()
        try:
            with os.scandir(directory) as entries:
                for entry in entries:
                    seen += 1
                    if seen > limit:
                        return total, False
                    try:
                        if entry.is_symlink():
                            continue
                        if entry.is_dir(follow_symlinks=False):
                            stack.append(Path(entry.path))
                        elif entry.is_file(follow_symlinks=False):
                            total += entry.stat(follow_symlinks=False).st_size
                    except OSError:
                        return total, False
        except OSError:
            return total, False
    return total, True


class ManifestRegistry:
    """Loads only manifests from administrator-controlled installation roots."""

    def __init__(self, roots: Sequence[Path] | None = None):
        self._roots = tuple(
            roots
            or (
                Path("/usr/share/omnistore/app-manifests"),
                Path("/opt/omnistore/app-manifests"),
                Path("/opt/omnistore/data/app-manifests"),
            )
        )
        self._manifests = self._load()

    def _load(self) -> list[dict[str, Any]]:
        manifests: list[dict[str, Any]] = []
        for root in self._roots:
            try:
                files = sorted(root.glob("*.json"))
            except OSError:
                continue
            for path in files:
                try:
                    raw = json.loads(path.read_text(encoding="utf-8"))
                except (OSError, UnicodeError, json.JSONDecodeError):
                    continue
                if not isinstance(raw, dict):
                    continue
                if raw.get("schema") != MANIFEST_SCHEMA or raw.get("version") != MANIFEST_VERSION:
                    continue
                match = raw.get("match")
                storage = raw.get("storage", {})
                if not isinstance(match, dict) or not isinstance(storage, dict):
                    continue
                manifests.append(raw)
        return manifests

    def for_package(self, package: Mapping[str, Any]) -> dict[str, Any] | None:
        name = str(package.get("name") or "").casefold()
        package_id = str(
            package.get("id")
            or package.get("app_id")
            or package.get("package")
            or package.get("package_id")
            or ""
        ).casefold()
        source = str(package.get("primary_source") or package.get("source") or "").casefold()
        for manifest in self._manifests:
            match = manifest.get("match", {})
            names = {str(item).casefold() for item in match.get("names", []) if isinstance(item, str)}
            ids = {str(item).casefold() for item in match.get("ids", []) if isinstance(item, str)}
            sources = {str(item).casefold() for item in match.get("sources", []) if isinstance(item, str)}
            if sources and source not in sources and _source_id(source) not in sources:
                continue
            if (names and name in names) or (ids and package_id in ids):
                return manifest
        return None


def _package_id(package: Mapping[str, Any]) -> str:
    for key in ("id", "app_id", "package_id", "package", "name"):
        raw = package.get(key)
        if isinstance(raw, str):
            value = " ".join(raw.split())[:256]
            if value and _ID_RE.fullmatch(value):
                return value
    # Display names can contain spaces. Keep the public id deterministic without
    # treating it as a path or shell token.
    return _source_id(_safe_text(package.get("name"), fallback="unknown-app"))


def _flatpak_id(package: Mapping[str, Any]) -> str | None:
    source = _source_id(str(package.get("primary_source") or package.get("source") or ""))
    if source != "flatpak":
        return None
    for key in ("id", "app_id", "package_id", "package", "name"):
        raw = package.get(key)
        if isinstance(raw, str) and "." in raw and _ID_RE.fullmatch(raw):
            return raw
    return None


def _manifest_targets(
    manifest: Mapping[str, Any] | None, *, home: Path
) -> list[StorageTarget]:
    if not manifest:
        return []
    storage = manifest.get("storage")
    if not isinstance(storage, Mapping):
        return []

    targets: list[StorageTarget] = []
    for category in ("config", "cache", "data", "state"):
        raw_entries = storage.get(category, [])
        if not isinstance(raw_entries, list):
            continue
        for entry in raw_entries[:_MAX_TARGETS_PER_CATEGORY]:
            if isinstance(entry, str):
                root_name, relative_value = category, entry
            elif isinstance(entry, Mapping):
                root_name = str(entry.get("root") or category)
                relative_value = entry.get("path")
            else:
                continue
            if root_name not in {"config", "cache", "data", "state", "home"}:
                continue
            relative = _safe_relative(relative_value)
            if relative is None:
                continue
            base = _xdg_root(root_name, home)
            candidate = base / relative
            if not _contained(candidate, base) or candidate.is_symlink():
                continue
            targets.append(
                StorageTarget(
                    category=category,
                    path=candidate,
                    display_path=_display_path(candidate, home),
                    provenance="manifest",
                )
            )
    return targets


def _flatpak_targets(package: Mapping[str, Any], *, home: Path) -> list[StorageTarget]:
    app_id = _flatpak_id(package)
    if not app_id:
        return []
    sandbox = home / ".var/app" / app_id
    flatpak_base = home / ".var/app"
    if not _contained(sandbox, flatpak_base) or sandbox.is_symlink():
        return []

    targets: list[StorageTarget] = []
    for category in ("config", "cache", "data"):
        path = sandbox / category
        if _contained(path, sandbox) and not path.is_symlink():
            targets.append(
                StorageTarget(
                    category=category,
                    path=path,
                    display_path=_display_path(path, home),
                    provenance="flatpak",
                )
            )
    return targets


def storage_targets(
    package: Mapping[str, Any],
    *,
    registry: ManifestRegistry | None = None,
    home: Path | None = None,
) -> tuple[list[StorageTarget], dict[str, Any] | None]:
    actual_home = (home or Path.home()).resolve(strict=False)
    actual_registry = registry or ManifestRegistry()
    manifest = actual_registry.for_package(package)
    targets = _manifest_targets(manifest, home=actual_home)
    if not targets:
        targets = _flatpak_targets(package, home=actual_home)
    return targets, manifest


def _settings_descriptor(manifest: Mapping[str, Any] | None) -> dict[str, Any]:
    if not manifest:
        return {"available": False}
    raw = manifest.get("settings")
    if not isinstance(raw, Mapping):
        return {"available": False}
    provider = _safe_text(raw.get("provider"), fallback="", maximum=80)
    label = _safe_text(raw.get("label"), fallback="Application settings", maximum=120)
    route = _safe_text(raw.get("route"), fallback="", maximum=160)
    result: dict[str, Any] = {"available": bool(provider), "label": label}
    if provider:
        result["provider"] = provider
    if route:
        result["route"] = route
    return result


def build_app_management_snapshot(
    packages: Iterable[Mapping[str, Any]],
    *,
    registry: ManifestRegistry | None = None,
    home: Path | None = None,
    generated_at: datetime | None = None,
) -> dict[str, Any]:
    actual_home = (home or Path.home()).resolve(strict=False)
    actual_registry = registry or ManifestRegistry()
    applications: list[dict[str, Any]] = []

    for package in packages:
        if package.get("installed") is not True:
            continue
        if len(applications) >= _MAX_APPS:
            break

        name = _safe_text(package.get("name"), fallback="Unknown application")
        app_id = _package_id(package)
        source_name = _safe_text(
            package.get("primary_source") or package.get("source"),
            fallback="Unknown source",
            maximum=80,
        )
        source_id = _source_id(source_name)
        size_bytes, size_kind = _normalized_size(package)
        targets, manifest = storage_targets(
            package, registry=actual_registry, home=actual_home
        )

        category_rows: list[dict[str, Any]] = []
        storage_total = 0
        storage_complete = True
        for category in ("config", "cache", "data", "state"):
            category_targets = [target for target in targets if target.category == category]
            if not category_targets:
                continue
            category_size = 0
            category_complete = True
            paths: list[str] = []
            for target in category_targets:
                value, complete = _tree_size(target.path)
                category_size += value
                category_complete = category_complete and complete
                paths.append(target.display_path)
            storage_total += category_size
            storage_complete = storage_complete and category_complete
            category_rows.append(
                {
                    "id": category,
                    "bytes": category_size,
                    "complete": category_complete,
                    "paths": paths,
                }
            )

        application: dict[str, Any] = {
            "id": app_id,
            "name": name,
            "sourceId": source_id,
            "sourceName": source_name,
            "sizeKind": size_kind,
            "storageBytes": storage_total,
            "storageComplete": storage_complete,
            "storage": category_rows,
            "settings": _settings_descriptor(manifest),
            "capabilities": {
                "uninstall": source_id not in {"unknown", ""},
                "clearCache": any(target.category == "cache" for target in targets),
                "resetSettings": any(target.category == "config" for target in targets),
                "clearData": any(target.category in {"data", "state"} for target in targets),
            },
        }
        if size_bytes is not None:
            application["packageSizeBytes"] = size_bytes
        version = _safe_text(
            package.get("installed_version") or package.get("version"),
            fallback="",
            maximum=120,
        )
        if version:
            application["version"] = version
        applications.append(application)

    applications.sort(key=lambda item: item["name"].casefold())
    timestamp = generated_at or datetime.now(timezone.utc)
    if timestamp.tzinfo is None:
        timestamp = timestamp.replace(tzinfo=timezone.utc)

    return {
        "schema": SCHEMA,
        "version": SCHEMA_VERSION,
        "status": "success",
        "generatedAt": timestamp.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
        "applicationCount": len(applications),
        "applications": applications,
    }


async def export_app_management(
    backend: Any,
    *,
    registry: ManifestRegistry | None = None,
    home: Path | None = None,
) -> dict[str, Any]:
    result = await backend.run_list_installed(json_mode=False)
    if isinstance(result, Mapping) and result.get("status") != "success":
        raise RuntimeError("OmniStore could not collect installed applications")
    packages = _unwrap_packages(result)
    return build_app_management_snapshot(packages, registry=registry, home=home)


def _find_package(
    packages: Iterable[Mapping[str, Any]], app_id: str, source: str
) -> Mapping[str, Any] | None:
    wanted_source = _source_id(source)
    for package in packages:
        if package.get("installed") is not True:
            continue
        package_source = _source_id(
            str(package.get("primary_source") or package.get("source") or "")
        )
        if _package_id(package) == app_id and (not wanted_source or package_source == wanted_source):
            return package
    return None


def _remove_target(path: Path) -> int:
    if not path.exists():
        return 0
    if path.is_symlink():
        raise RuntimeError("Refusing to delete a symlink target")
    size, _ = _tree_size(path)
    if path.is_dir():
        shutil.rmtree(path)
    else:
        path.unlink()
    return size


async def perform_app_action(
    backend: Any,
    *,
    action: str,
    app_id: str,
    source: str,
    registry: ManifestRegistry | None = None,
    home: Path | None = None,
) -> dict[str, Any]:
    if action not in {"clear-cache", "reset-settings", "clear-data", "uninstall"}:
        raise ValueError("unsupported_action")
    if not _ID_RE.fullmatch(app_id):
        raise ValueError("invalid_app_id")

    result = await backend.run_list_installed(json_mode=False)
    packages = _unwrap_packages(result)
    package = _find_package(packages, app_id, source)
    if package is None:
        raise ValueError("application_not_found")

    source_name = _safe_text(
        package.get("primary_source") or package.get("source"),
        fallback="Unknown source",
        maximum=80,
    )
    if action == "uninstall":
        uninstall_result = await backend.run_uninstall(
            str(package.get("name") or app_id), source_name, False
        )
        if isinstance(uninstall_result, Mapping) and uninstall_result.get("status") == "error":
            raise RuntimeError("uninstall_failed")
        return {
            "schema": SCHEMA,
            "version": SCHEMA_VERSION,
            "status": "success",
            "action": action,
            "appId": app_id,
            "bytesFreed": 0,
        }

    targets, _manifest = storage_targets(
        package, registry=registry, home=home
    )
    categories = {
        "clear-cache": {"cache"},
        "reset-settings": {"config"},
        "clear-data": {"config", "cache", "data", "state"},
    }[action]
    selected = [target for target in targets if target.category in categories]
    if not selected:
        raise ValueError("action_not_supported")

    bytes_freed = 0
    for target in selected:
        bytes_freed += _remove_target(target.path)

    return {
        "schema": SCHEMA,
        "version": SCHEMA_VERSION,
        "status": "success",
        "action": action,
        "appId": app_id,
        "bytesFreed": bytes_freed,
    }
