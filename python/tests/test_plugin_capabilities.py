import ast
import asyncio
import pytest
import json
import sys
import zipfile
from pathlib import Path

from core.sources.base import UnifiedSource
from core.sources.external import (
    AptSource, ApkSource, BrewSource, ChocolateySource, DnfSource, FdroidSource,
    ScoopSource, WingetSource, ZypperSource,
)
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
    "builtin.apt": AptSource,
    "builtin.dnf": DnfSource,
    "builtin.zypper": ZypperSource,
    "builtin.apk": ApkSource,
    "builtin.chocolatey": ChocolateySource,
    "builtin.fdroid": FdroidSource,
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


def test_trusted_system_stores_are_enabled_by_default_and_risky_sources_stay_gated(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    cm = ConfigManager()
    registry = PluginRegistry(cm, None)
    registry.discover()
    listed = {plugin["id"]: plugin for plugin in registry.list_plugins()}

    manifest_ids = {manifest["id"] for manifest in _plugin_manifests()}
    enabled_by_default = [plugin_id for plugin_id in manifest_ids if listed[plugin_id]["enabled"]]

    assert set(enabled_by_default) == {
        "builtin.flatpak",
        "builtin.pacman",
        "builtin.winget",
    }
    assert cm.get("search.sources.pacman") is True
    assert cm.get("search.sources.flatpak") is True
    assert listed["builtin.winget"]["trusted"] is True
    assert listed["builtin.winget"]["default_enabled"] is True
    assert listed["builtin.aur"]["trusted"] is False
    assert listed["builtin.aur"]["default_enabled"] is False


@pytest.mark.asyncio
async def test_appimage_search_pre_scan_optimization(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("XDG_DATA_HOME", str(tmp_path / ".local" / "share"))
    monkeypatch.setattr(Path, "home", lambda: tmp_path)

    config = DummyConfig()
    appimage = AppImageSource(DummySession(), config)

    # Mock _fetch_feed
    async def dummy_fetch_feed():
        return [
            {
                "name": "SuperTool",
                "description": "An awesome utility tool",
                "version": "1.0",
                "links": [{"type": "Download", "url": "https://example.com/supertool.AppImage"}]
            },
            {
                "name": "NonInstalledTool",
                "description": "Another utility",
                "version": "2.0",
                "links": [{"type": "Download", "url": "https://example.com/noninstalled.AppImage"}]
            }
        ]
    monkeypatch.setattr(appimage, "_fetch_feed", dummy_fetch_feed)

    # 1. Test when Applications folder is empty
    results = await appimage.search("tool")
    assert len(results) == 2
    assert results[0]["installed"] is False
    assert results[1]["installed"] is False

    # 2. Test when Applications folder has SuperTool.AppImage installed
    apps_dir = tmp_path / "Applications"
    apps_dir.mkdir(parents=True, exist_ok=True)
    super_tool_file = apps_dir / "SuperTool.AppImage"
    super_tool_file.write_text("#!/bin/sh\n", encoding="utf-8")

    results_installed = await appimage.search("tool")
    assert len(results_installed) == 2

    # Confirm SuperTool is found as installed, and NonInstalledTool is not installed
    super_tool_res = next(r for r in results_installed if r["name"] == "SuperTool")
    non_inst_res = next(r for r in results_installed if r["name"] == "NonInstalledTool")
    assert super_tool_res["installed"] is True
    assert non_inst_res["installed"] is False


@pytest.mark.asyncio
async def test_scoop_and_brew_get_installed_ids_optimization(monkeypatch):
    scoop = ScoopSource()
    brew = BrewSource()

    scoop.enabled = True
    brew.enabled = True

    # Ensure list_installed is NOT called during search
    async def forbidden_list_installed():
        pytest.fail("list_installed should not be called during search")

    monkeypatch.setattr(scoop, "list_installed", forbidden_list_installed)
    monkeypatch.setattr(brew, "list_installed", forbidden_list_installed)

    async def mock_scoop_installed_ids():
        return {"curl", "git"}

    async def mock_brew_installed_ids():
        return {"wget", "htop"}

    monkeypatch.setattr(scoop, "_get_installed_ids", mock_scoop_installed_ids)
    monkeypatch.setattr(brew, "_get_installed_ids", mock_brew_installed_ids)

    class DummyProc:
        def __init__(self, stdout_data):
            self._stdout_data = stdout_data
            self.pid = 12345
            self.returncode = 0

        async def communicate(self):
            return (self._stdout_data, b"")

        async def wait(self):
            return 0

    async def mock_create_subprocess_exec(*args, **kwargs):
        cmd = args[0]
        if cmd == "scoop":
            return DummyProc(b"Name Version Source\ncurl 7.88.0 [main]\n7zip 22.01 [main]\n")
        elif cmd == "brew":
            return DummyProc(b"wget\nffmpeg\nhtop\n")
        return DummyProc(b"")

    monkeypatch.setattr("asyncio.create_subprocess_exec", mock_create_subprocess_exec)

    scoop_results = await scoop.search("test")
    assert len(scoop_results) == 2
    assert next(r for r in scoop_results if r["name"] == "curl")["installed"] is True
    assert next(r for r in scoop_results if r["name"] == "7zip")["installed"] is False

    brew_results = await brew.search("test")
    assert len(brew_results) == 3
    assert next(r for r in brew_results if r["name"] == "wget")["installed"] is True
    assert next(r for r in brew_results if r["name"] == "htop")["installed"] is True
    assert next(r for r in brew_results if r["name"] == "ffmpeg")["installed"] is False


@pytest.mark.asyncio
async def test_get_installed_ids_parsing_and_timeouts(monkeypatch, caplog):
    scoop = ScoopSource()
    brew = BrewSource()
    scoop.enabled = True
    brew.enabled = True

    class NormalProc:
        def __init__(self, stdout_data):
            self._stdout_data = stdout_data
            self.pid = 123
            self.returncode = 0

        async def communicate(self):
            return (self._stdout_data, b"")

        async def wait(self):
            return 0

    class TimeoutProc:
        def __init__(self):
            self.pid = 456
            self.returncode = None

        async def communicate(self):
            await asyncio.sleep(100)
            return (b"", b"")

        async def wait(self):
            return 0

    async def mock_exec_normal(*args, **kwargs):
        cmd = args[0]
        if cmd == "scoop":
            return NormalProc(b"Name Version\n7zip 22.01\ncurl 7.88.0\n")
        elif cmd == "brew":
            return NormalProc(b"wget 1.21.4\nhtop 3.2.2\n")
        return NormalProc(b"")

    monkeypatch.setattr("asyncio.create_subprocess_exec", mock_exec_normal)
    scoop_ids = await scoop._get_installed_ids()
    brew_ids = await brew._get_installed_ids()
    assert scoop_ids == {"7zip", "curl"}
    assert brew_ids == {"wget", "htop"}

    async def mock_exec_timeout(*args, **kwargs):
        return TimeoutProc()

    monkeypatch.setattr("asyncio.create_subprocess_exec", mock_exec_timeout)

    async def mock_wait_for(fut, timeout):
        if asyncio.iscoroutine(fut):
            fut.close()
        raise asyncio.TimeoutError()

    monkeypatch.setattr("asyncio.wait_for", mock_wait_for)

    with caplog.at_level("WARNING"):
        scoop_timeout_ids = await scoop._get_installed_ids()
        brew_timeout_ids = await brew._get_installed_ids()
        assert scoop_timeout_ids == set()
        assert brew_timeout_ids == set()
        assert "ScoopSource._get_installed_ids timed out" in caplog.text
        assert "BrewSource._get_installed_ids timed out" in caplog.text
