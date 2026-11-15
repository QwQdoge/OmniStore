"""End-to-end flows with fake command-line tools on PATH (no real Bottles/Homebrew needed)."""
import asyncio
import json
import os
import stat
import sys

import pytest

from core.platform_profile import SystemProfile
from core.sources import plugin_registry as pr
from core.sources.brew_cask import BrewCaskSource
from core.sources.resolve import resolve_source


class Config:
    def __init__(self):
        self.data = {}

    def get(self, key, default=None):
        if key in self.data:
            return self.data[key]
        value = self.data
        for part in key.split("."):
            if not isinstance(value, dict) or part not in value:
                return default
            value = value[part]
        return value

    def set(self, key, value):
        self.data[key] = value
        return True


def script(directory, name, body):
    path = directory / name
    path.write_text("#!/bin/sh\n" + body)
    path.chmod(path.stat().st_mode | stat.S_IEXEC)


@pytest.fixture
def fake_bin(tmp_path, monkeypatch):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    marker = tmp_path / "launched.txt"
    script(bin_dir, "bottles-cli", f'''
case "$1 $2" in
  "list bottles") printf 'Found 2 bottles:\\n- Office\\n- Games\\n' ;;
  "programs -b") printf 'Found programs:\\n- Word-%s\\n' "$3" ;;
  "run -b") echo "$3 $5" > {marker} ;;
esac
''')
    script(bin_dir, "brew", '''
case "$1 $2" in
  "search --cask") printf '==> Casks\\nfirefox\\nvlc\\n' ;;
  "list --cask") printf 'vlc 3.0.21\\n' ;;
  "install --cask") echo installed "$3" ;;
esac
''')
    monkeypatch.setenv("PATH", f"{bin_dir}{os.pathsep}{os.environ['PATH']}")
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path / "cfg"))
    return marker


def linux_registry(monkeypatch):
    monkeypatch.setattr(pr, "_platform_key", lambda: "linux")
    reg = pr.PluginRegistry(Config())
    reg.profile = SystemProfile(platform="linux", native_manager="pacman")
    return reg


def test_bottles_offer_enable_list_launch(fake_bin, monkeypatch):
    reg = linux_registry(monkeypatch)
    reg.discover()
    assert reg.plugins["builtin.bottles"].offered
    assert "bottles" not in reg.sources                      # clean until chosen
    assert [o["id"] for o in reg.list_offers()].count("builtin.bottles") == 1

    reg.enable("builtin.bottles", True)
    reg.discover()
    bottles = reg.sources["bottles"]
    assert bottles.enabled and not reg.plugins["builtin.bottles"].offered
    assert resolve_source(reg.sources, "Bottles") is bottles

    assert asyncio.run(bottles.list_installed()) == []        # nothing listed yet
    assert asyncio.run(bottles.pending_bottles()) == ["Office", "Games"]
    bottles.set_listed("Office", True)
    reg.discover()                                            # decision survives a restart
    bottles = reg.sources["bottles"]
    items = asyncio.run(bottles.list_installed())
    assert [i["id"] for i in items] == ["Office::Word-Office"]
    assert asyncio.run(bottles.search("word"))[0]["name"] == "Word-Office"

    assert asyncio.run(bottles.launch({"name": "Word-Office"}))   # bare name, as the store sends it
    assert fake_bin.read_text().split() == ["Office", "Word-Office"]
    assert asyncio.run(bottles.launch({"id": "Office::Word-Office"}))


def test_brew_cask_search_list_install(fake_bin, monkeypatch):
    monkeypatch.setattr(sys, "platform", "darwin")
    cask = BrewCaskSource()
    assert cask.enabled
    found = {r["id"]: r for r in asyncio.run(cask.search("v"))}
    assert set(found) == {"firefox", "vlc"} and found["vlc"]["installed"] and not found["firefox"]["installed"]
    assert [i["id"] for i in asyncio.run(cask.list_installed())] == ["vlc"]
    lines = []

    async def cb(msg):
        lines.append(msg)

    assert asyncio.run(cask.install({"id": "firefox"}, cb))
    assert any("installed firefox" in l for l in lines)
    assert resolve_source({"brewcask": cask}, "Homebrew Cask") is cask


def test_catalog_end_to_end_through_registry(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    monkeypatch.setattr(pr, "_platform_key", lambda: "linux")
    index = {"schema": 1, "id": "acme", "name": "Acme", "platforms": ["linux"],
             "apps": [{"id": "a", "name": "Alpha", "install": {"type": "delegate", "source": "flatpak", "id": "org.a.A"}}]}
    reg = pr.PluginRegistry(Config())
    reg.profile = SystemProfile(platform="linux", native_manager="pacman")
    reg.add_catalog("https://example.org/i.json", opener=lambda u: json.dumps(index).encode())
    reg.discover()
    assert "catalog.acme" not in reg.sources                 # off until reviewed
    reg.enable("catalog.acme", True)
    reg.discover()
    source = reg.sources["catalog.acme"]
    assert [r["id"] for r in asyncio.run(source.search("alpha"))] == ["a"]
    assert resolve_source(reg.sources, "Acme") is source
    reg.remove("catalog.acme")
    reg.discover()
    assert "catalog.acme" not in reg.plugins
