import importlib.util
import json
import logging
import os
import shutil
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional

from core.sources.base import UnifiedSource


def _platform_key() -> str:
    if sys.platform == "win32":
        return "windows"
    if sys.platform == "darwin":
        return "macos"
    if sys.platform.startswith("linux"):
        return "linux"
    return sys.platform


@dataclass
class PluginInfo:
    id: str
    kind: str
    name: str
    version: str = "0.1.0"
    entry: str = ""
    platforms: List[str] = field(default_factory=list)
    capabilities: List[str] = field(default_factory=list)
    permissions: List[str] = field(default_factory=list)
    builtin: bool = False
    enabled: bool = True
    available: bool = True
    legacy: bool = False
    path: str = ""
    error: Optional[str] = None
    config_schema: Dict[str, Any] = field(default_factory=dict)
    trusted: bool = False
    default_enabled: bool = False
    requires_review: bool = True

    @classmethod
    def from_manifest(cls, data: Dict[str, Any], path: Path) -> "PluginInfo":
        return cls(
            id=str(data.get("id") or path.parent.name),
            kind=str(data.get("kind") or "source"),
            name=str(data.get("name") or data.get("id") or path.parent.name),
            version=str(data.get("version") or "0.1.0"),
            entry=str(data.get("entry") or ""),
            platforms=[str(p) for p in data.get("platforms", [])],
            capabilities=[str(c) for c in data.get("capabilities", [])],
            permissions=[str(p) for p in data.get("permissions", [])],
            builtin=bool(data.get("builtin", False)),
            trusted=bool(data.get("trusted", False)),
            default_enabled=bool(data.get("default_enabled", False)),
            requires_review=bool(data.get("requires_review", True)),
            path=str(path.parent),
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "kind": self.kind,
            "name": self.name,
            "version": self.version,
            "entry": self.entry,
            "platforms": self.platforms,
            "capabilities": self.capabilities,
            "permissions": self.permissions,
            "builtin": self.builtin,
            "enabled": self.enabled,
            "available": self.available,
            "legacy": self.legacy,
            "path": self.path,
            "error": self.error,
            "config_schema": self.config_schema,
            "trusted": self.trusted,
            "default_enabled": self.default_enabled,
            "requires_review": self.requires_review,
        }


class PluginRegistry:
    def __init__(self, config_manager: Any, session: Any = None):
        self.cm = config_manager
        self.session = session
        self.root = self._find_project_root()
        self.package_dir = self.root / "plugins" / "sources"
        self.legacy_dir = self.root / "plugins"
        self.plugins: Dict[str, PluginInfo] = {}
        self.sources: Dict[str, UnifiedSource] = {}
        self.errors: Dict[str, str] = {}

    def _find_project_root(self) -> Path:
        candidates = [Path.cwd(), Path(__file__).resolve()]
        for start in candidates:
            directory = start if start.is_dir() else start.parent
            for parent in [directory, *directory.parents]:
                if (parent / "python" / "main.py").exists() and (parent / "plugins").exists():
                    return parent
                if parent.name == "python" and (parent / "main.py").exists():
                    return parent.parent
        return Path.cwd()

    def discover(self) -> None:
        self.plugins = {}
        self.sources = {}
        self.errors = {}
        self.package_dir.mkdir(parents=True, exist_ok=True)
        self._load_manifest_packages()
        self._load_legacy_plugins()

    def load_sources(self) -> Dict[str, UnifiedSource]:
        self.discover()
        return self.sources

    def list_plugins(self) -> List[Dict[str, Any]]:
        return [info.to_dict() for info in sorted(self.plugins.values(), key=lambda p: (not p.builtin, p.name.lower()))]

    def enable(self, plugin_id: str, enabled: bool) -> bool:
        enabled_map = self._enabled_map()
        enabled_map[plugin_id] = bool(enabled)
        self.cm.set("plugins.enabled", enabled_map)
        legacy_key = self._legacy_source_key(plugin_id)
        if legacy_key:
            self.cm.set(f"search.sources.{legacy_key}", bool(enabled))
        return True

    def remove(self, plugin_id: str) -> bool:
        info = self.plugins.get(plugin_id)
        if not info:
            return False
        if info.builtin:
            return self.enable(plugin_id, False)
        path = Path(info.path)
        if path.exists() and self.package_dir in path.parents:
            shutil.rmtree(path)
        config = dict(self.cm.get("plugins.config", {}) or {})
        config.pop(plugin_id, None)
        self.cm.set("plugins.config", config)
        enabled_map = self._enabled_map()
        enabled_map.pop(plugin_id, None)
        self.cm.set("plugins.enabled", enabled_map)
        return True

    def _load_manifest_packages(self) -> None:
        for manifest_path in sorted(self.package_dir.glob("*/plugin.json")):
            try:
                data = json.loads(manifest_path.read_text(encoding="utf-8"))
                info = PluginInfo.from_manifest(data, manifest_path)
                info.enabled = self._is_enabled(info)
                info.available = self._is_platform_available(info)
                schema_path = manifest_path.parent / "schema.json"
                if schema_path.exists():
                    info.config_schema = json.loads(schema_path.read_text(encoding="utf-8"))
                elif info.builtin:
                    info.config_schema = self._builtin_config_schema(info)
                self.plugins[info.id] = info
                if info.kind == "source" and info.enabled and info.available:
                    source = self._instantiate_manifest_source(info, manifest_path.parent)
                    if source:
                        self._register_source(info, source)
            except Exception as exc:
                plugin_id = manifest_path.parent.name
                self.errors[plugin_id] = str(exc)
                self.plugins[plugin_id] = PluginInfo(
                    id=plugin_id,
                    kind="source",
                    name=plugin_id,
                    path=str(manifest_path.parent),
                    enabled=False,
                    available=False,
                    error=str(exc),
                )

    def _instantiate_manifest_source(self, info: PluginInfo, plugin_dir: Path) -> Optional[UnifiedSource]:
        try:
            source = self._builtin_source(info)
            if source is None:
                source = self._load_entry_source(info, plugin_dir)
            if source is None:
                return None
            source.source_id = info.id
            source.display_name = info.name
            source.capabilities = {cap: False for cap in source.capabilities}
            source.capabilities.update({cap: True for cap in info.capabilities})
            runtime_available = bool(source.enabled)
            info.available = bool(info.available and runtime_available)
            source.enabled = bool(runtime_available and info.enabled and info.available)
            info.config_schema = info.config_schema or source.config_schema()
            return source
        except Exception as exc:
            info.error = str(exc)
            info.available = False
            self.errors[info.id] = str(exc)
            logging.getLogger("omnistore").warning("Failed to load plugin %s: %s", info.id, exc)
            return None

    def _builtin_source(self, info: PluginInfo) -> Optional[UnifiedSource]:
        if not info.builtin:
            return None
        from core.sources import PacmanSource, AurSource, FlatpakSource, AppImageSource, GitHubSource, BituSource
        from core.sources.external import (
            WingetSource, ScoopSource, BrewSource, AptSource, DnfSource, ZypperSource,
            ApkSource, ChocolateySource, FdroidSource,
        )

        factories: Dict[str, Callable[[], UnifiedSource]] = {
            "builtin.github": lambda: GitHubSource(self.session, self.cm),
            "builtin.bitu": lambda: BituSource(self.session, self.cm),
            "builtin.pacman": PacmanSource,
            "builtin.aur": lambda: AurSource(self.session),
            "builtin.flatpak": FlatpakSource,
            "builtin.appimage": lambda: AppImageSource(self.session, self.cm),
            "builtin.winget": WingetSource,
            "builtin.scoop": ScoopSource,
            "builtin.brew": BrewSource,
            "builtin.apt": AptSource,
            "builtin.dnf": DnfSource,
            "builtin.zypper": ZypperSource,
            "builtin.apk": ApkSource,
            "builtin.chocolatey": ChocolateySource,
            "builtin.fdroid": FdroidSource,
        }
        factory = factories.get(info.id)
        return factory() if factory else None

    def _builtin_config_schema(self, info: PluginInfo) -> Dict[str, Any]:
        try:
            source = self._builtin_source(info)
            return source.config_schema() if source else {}
        except Exception:
            return {}

    def _load_entry_source(self, info: PluginInfo, plugin_dir: Path) -> Optional[UnifiedSource]:
        if ":" not in info.entry:
            raise ValueError(f"Plugin {info.id} missing entry module:Class")
        module_name, class_name = info.entry.split(":", 1)
        module_path = plugin_dir / f"{module_name}.py"
        spec = importlib.util.spec_from_file_location(f"omnistore_plugin_{info.id}", module_path)
        if spec is None or spec.loader is None:
            raise ValueError(f"Could not load plugin entry {info.entry}")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        cls = getattr(module, class_name)
        instance = cls()
        if not isinstance(instance, UnifiedSource):
            raise TypeError(f"{info.entry} is not a UnifiedSource")
        return instance

    def _load_legacy_plugins(self) -> None:
        if not self.cm.get("search.sources.plugins", True):
            return
        if not self.legacy_dir.exists():
            return
        if str(self.legacy_dir) not in sys.path:
            sys.path.append(str(self.legacy_dir))
        for file_path in sorted(self.legacy_dir.glob("*.py")):
            if file_path.name.startswith("__"):
                continue
            try:
                spec = importlib.util.spec_from_file_location(file_path.stem, file_path)
                if spec is None or spec.loader is None:
                    continue
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                for attr_name in dir(module):
                    attr = getattr(module, attr_name)
                    if isinstance(attr, type) and issubclass(attr, UnifiedSource) and attr is not UnifiedSource:
                        instance = attr()
                        plugin_id = f"legacy.{instance.name.lower()}"
                        capabilities = self._implemented_capabilities(instance)
                        config_schema = instance.config_schema() if type(instance).config_schema is not UnifiedSource.config_schema else {}
                        info = PluginInfo(
                            id=plugin_id,
                            kind="source",
                            name=instance.name,
                            version="legacy",
                            platforms=[],
                            capabilities=capabilities,
                            permissions=["legacy"],
                            builtin=False,
                            enabled=False,
                            available=True,
                            legacy=True,
                            path=str(file_path),
                            config_schema=config_schema,
                        )
                        instance.source_id = plugin_id
                        instance.enabled = False
                        instance.capabilities = {cap: False for cap in instance.capabilities}
                        instance.capabilities.update({cap: True for cap in capabilities})
                        self.plugins[plugin_id] = info
                        self.sources[instance.name.lower()] = instance
            except Exception as exc:
                self.errors[f"legacy.{file_path.stem}"] = str(exc)

    def _register_source(self, info: PluginInfo, source: UnifiedSource) -> None:
        key = info.id.replace("builtin.", "").replace("legacy.", "").lower()
        self.sources[key] = source

    def _implemented_capabilities(self, source: UnifiedSource) -> List[str]:
        cap_to_method = {
            "search": "search",
            "install": "install",
            "uninstall": "uninstall",
            "update": "check_update",
            "details": "get_details",
            "list_installed": "list_installed",
            "size": "get_size",
            "launch": "launch",
            "locate": "locate",
        }
        implemented: List[str] = []
        for cap, method_name in cap_to_method.items():
            method = getattr(type(source), method_name, None)
            base_method = getattr(UnifiedSource, method_name, None)
            if method is not None and method is not base_method:
                implemented.append(cap)
        if type(source).config_schema is not UnifiedSource.config_schema:
            schema = source.config_schema() or {}
            properties = schema.get("properties", {}) if isinstance(schema, dict) else {}
            if any(name in properties for name in ("mirrors", "mirrorlist_path")):
                implemented.append("mirrors")
            if any(name in properties for name in ("repositories", "remotes", "feeds", "buckets", "taps")):
                implemented.append("repositories")
        return implemented

    def _is_platform_available(self, info: PluginInfo) -> bool:
        return not info.platforms or _platform_key() in info.platforms

    def _is_enabled(self, info: PluginInfo) -> bool:
        enabled_map = self._enabled_map()
        if info.id in enabled_map:
            return bool(enabled_map[info.id])
        if info.legacy:
            return False
        return bool(info.default_enabled and info.trusted)

    def _enabled_map(self) -> Dict[str, bool]:
        return dict(self.cm.get("plugins.enabled", {}) or {})

    def _legacy_source_key(self, plugin_id: str) -> str:
        return plugin_id.replace("builtin.", "", 1) if plugin_id.startswith("builtin.") else ""
