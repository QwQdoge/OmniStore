import ast
import asyncio
import json
import sys
import zipfile
from pathlib import Path

from core.sources.base import UnifiedSource
from core.sources.external import BrewSource, ScoopSource, WingetSource
from core.sources.github.github import GitHubSource
from core.sources.bitu.bitu import BituSource
from core.sources.pacman import PacmanSource
from core.sources.aur.aur import AurSource
from core.sources.flatpak.flatpak import FlatpakSource
from core.sources.appimage.appimage import AppImageSource
from core.config_loader import ConfigManager
from core.sources.plugin_registry import PluginRegistry


class DummySession:
    pass


class DummyConfig:
    def get(self, key, default=None):
        return default

    def set(self, key, value):
        return None


CLASS_BY_PLUGIN = {
    "builtin.appimage": lambda: AppImageSource(DummySession(), DummyConfig()),
    "builtin.aur": lambda: AurSource(DummySession()),
    "builtin.bitu": lambda: BituSource(DummySession(), DummyConfig()),
    "builtin.brew": BrewSource,
    "builtin.flatpak": FlatpakSource,
    "builtin.github": lambda: GitHubSource(DummySession(), DummyConfig()),
    "builtin.pacman": PacmanSource,
    "builtin.scoop": ScoopSource,
    "builtin.winget": WingetSource,
}

CAP_METHOD = {
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


def _plugin_manifests():
    root = Path(__file__).resolve().parents[2]
    for manifest in sorted((root / "plugins" / "sources").glob("*/plugin.json")):
        yield json.loads(manifest.read_text(encoding="utf-8"))


def _method_returns_only_false(method):
    source = Path(sys.modules[method.__module__].__file__)
    tree = ast.parse(source.read_text(encoding="utf-8"))
    for cls in [node for node in ast.walk(tree) if isinstance(node, ast.ClassDef)]:
        if cls.name != method.__qualname__.split(".")[0]:
            continue
        for fn in [node for node in cls.body if isinstance(node, ast.AsyncFunctionDef)]:
            if fn.name != method.__name__:
                continue
            returns = [ast.unparse(node.value) for node in ast.walk(fn) if isinstance(node, ast.Return) and node.value]
            return bool(returns) and set(returns) == {"False"}
    return False


def test_builtin_manifest_capabilities_have_real_implementations():
    for manifest in _plugin_manifests():
        plugin_id = manifest["id"]
        source = CLASS_BY_PLUGIN[plugin_id]()
        for cap in manifest["capabilities"]:
            method_name = CAP_METHOD.get(cap)
            if method_name:
                method = getattr(type(source), method_name)
                assert method is not getattr(UnifiedSource, method_name)
                assert not _method_returns_only_false(method), f"{plugin_id}.{cap} is a hardcoded False stub"
        if "mirrors" in manifest["capabilities"] or "repositories" in manifest["capabilities"]:
            schema = source.config_schema()
            properties = schema.get("properties", {})
            assert properties, f"{plugin_id} declares config capability but has no schema"


def test_plugin_registry_capabilities_match_manifest_and_filter_legacy():
    cm = ConfigManager()
    registry = PluginRegistry(cm, None)
    registry.discover()
    listed = {plugin["id"]: plugin for plugin in registry.list_plugins()}
    for manifest in _plugin_manifests():
        plugin = listed[manifest["id"]]
        assert set(plugin["capabilities"]) == set(manifest["capabilities"])
        if plugin["available"] and manifest["id"].replace("builtin.", "") in registry.sources:
            source = registry.sources[manifest["id"].replace("builtin.", "")]
            enabled_caps = {cap for cap, enabled in source.capabilities.items() if enabled}
            assert enabled_caps == set(manifest["capabilities"])

    legacy = listed.get("legacy.demoplugin")
    if legacy:
        assert "size" not in legacy["capabilities"]
        assert "list_installed" not in legacy["capabilities"]


def test_file_backed_plugins_install_size_and_uninstall_with_sync_callbacks(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("XDG_DATA_HOME", str(tmp_path / ".local" / "share"))
    monkeypatch.setattr(Path, "home", lambda: tmp_path)

    async def run_cycle():
        config = DummyConfig()
        logs = []

        appimage_file = tmp_path / "tool.AppImage"
        appimage_file.write_text("#!/bin/sh\necho appimage\n", encoding="utf-8")
        appimage_file.chmod(0o755)
        appimage = AppImageSource(DummySession(), config)
        app_pkg = {"id": "tool", "name": "tool", "url": appimage_file.as_uri()}
        assert await appimage.install(app_pkg, logs.append)
        assert any(item["name"] == "tool" for item in await appimage.list_installed())
        assert await appimage.uninstall(app_pkg, logs.append)
        assert not any(item["name"] == "tool" for item in await appimage.list_installed())

        github_file = tmp_path / "gh-tool"
        github_file.write_text("#!/bin/sh\necho github\n", encoding="utf-8")
        github_file.chmod(0o755)
        github = GitHubSource(DummySession(), config)
        gh_pkg = {
            "id": "local/gh-tool",
            "name": "gh-tool",
            "assets": [{
                "name": "gh-tool",
                "download_url": github_file.as_uri(),
                "size": github_file.stat().st_size,
            }],
        }
        assert await github.install(gh_pkg, logs.append)
        gh_size = await github.get_size(gh_pkg)
        assert gh_size["disk_size"] == github_file.stat().st_size
        assert await github.uninstall(gh_pkg, logs.append)

        bitu_zip = tmp_path / "bitu.zip"
        bitu_file = tmp_path / "bitu-tool"
        bitu_file.write_text("#!/bin/sh\necho bitu\n", encoding="utf-8")
        bitu_file.chmod(0o755)
        with zipfile.ZipFile(bitu_zip, "w") as archive:
            archive.write(bitu_file, "project/bitu-tool")
        bitu = BituSource(DummySession(), config)
        bitu_pkg = {"id": "local/bitu-tool", "name": "bitu-tool", "download_url": bitu_zip.as_uri()}
        assert await bitu.install(bitu_pkg, logs.append)
        assert any(item["id"] == "local/bitu-tool" for item in await bitu.list_installed())
        bitu_size = await bitu.get_size(bitu_pkg)
        assert bitu_size["disk_size"] == bitu_file.stat().st_size
        assert await bitu.uninstall(bitu_pkg, logs.append)
        assert not any(item["id"] == "local/bitu-tool" for item in await bitu.list_installed())

        assert logs

    asyncio.run(run_cycle())
