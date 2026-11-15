import asyncio
import json

import pytest

from core.sources.base import UnifiedSource
from core.sources.bottles import BottlesSource, parse_bottle_list
from core.sources.catalog import CatalogError, CatalogSource, install_catalog, validate_index
from core.sources.plugin_registry import PluginRegistry


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
        self.data[key] = value  # flat keys; get() resolves dotted paths over nested dicts too


def make_registry(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    return PluginRegistry(Config())


def test_offer_requires_detection_and_no_decision(tmp_path, monkeypatch):
    reg = make_registry(tmp_path, monkeypatch)
    src = reg.package_dir / "fake"
    src.mkdir(parents=True, exist_ok=True)
    manifest = {"id": "fake.tool", "kind": "source", "name": "Fake", "offer": "on_detect",
                "detect": {"commands": ["python3"]}, "builtin": False}
    (src / "plugin.json").write_text(json.dumps(manifest))
    try:
        reg.discover()
        assert reg.plugins["fake.tool"].offered is True
        reg.enable("fake.tool", False)
        reg.discover()
        assert reg.plugins["fake.tool"].offered is False  # user decided
        manifest["detect"] = {"commands": ["definitely-not-installed-xyz"]}
        (src / "plugin.json").write_text(json.dumps(manifest))
        reg.cm.data.pop("plugins.enabled")
        reg.discover()
        assert reg.plugins["fake.tool"].offered is False  # not detected
    finally:
        (src / "plugin.json").unlink()
        src.rmdir()


def test_bottles_hides_programs_until_user_lists_the_bottle():
    cm = Config()
    source = BottlesSource(cm)
    source.enabled = True

    async def fake_run(*args, timeout=30):
        if args[:2] == ("list", "bottles"):
            return 0, "Found 2 bottles:\n- Office\n- Games\n"
        if args[:2] == ("programs", "-b"):
            return 0, f"Found programs:\n- {args[2]}App\n"
        return 1, ""

    source._run = fake_run
    assert parse_bottle_list("Found 1 bottles:\n- A\n") == ["A"]
    assert asyncio.run(source.list_installed()) == []
    assert asyncio.run(source.pending_bottles()) == ["Office", "Games"]
    source.set_listed("Office", True)
    source.set_listed("Games", False)
    items = asyncio.run(source.list_installed())
    assert [i["id"] for i in items] == ["Office::OfficeApp"]
    assert items[0]["app_class"] == "wrapped"
    assert asyncio.run(source.pending_bottles()) == []


GOOD = {"schema": 1, "id": "acme", "name": "Acme", "platforms": ["linux"],
        "apps": [{"id": "a", "name": "Alpha", "install": {"type": "delegate", "source": "flatpak", "id": "org.a.A"}}]}


def test_catalog_validation_rejects_arbitrary_install_targets():
    validate_index(GOOD)
    bad = json.loads(json.dumps(GOOD))
    bad["apps"][0]["install"] = {"type": "shell", "command": "rm -rf /"}
    with pytest.raises(CatalogError):
        validate_index(bad)
    with pytest.raises(CatalogError):
        install_catalog("http://insecure.example/i.json", "/tmp")


def test_catalog_installs_disabled_and_delegates(tmp_path, monkeypatch):
    reg = make_registry(tmp_path, monkeypatch)
    plugin_id = reg.add_catalog("https://example.org/i.json", opener=lambda u: json.dumps(GOOD).encode())
    assert plugin_id == "catalog.acme"
    reg.discover()
    info = reg.plugins[plugin_id]
    assert info.enabled is False and info.requires_review is True and "acme" not in reg.sources

    calls = []

    class Fake(UnifiedSource):
        def __init__(self):
            super().__init__("Flatpak")

        async def search(self, *a, **k): return []
        async def uninstall(self, *a, **k): return True
        async def launch(self, *a, **k): return True
        async def locate(self, *a, **k): return True
        async def get_details(self, *a, **k): return {}
        async def check_update(self, *a, **k): return None

        async def install(self, package, callback=None):
            calls.append(package["id"])
            return True

    source = CatalogSource.from_dir(plugin_id, "Acme", reg.user_dir / plugin_id, lambda key: Fake())
    assert [r["id"] for r in asyncio.run(source.search("alp"))] == ["a"]
    assert asyncio.run(source.install({"id": "a"})) is True
    assert calls == ["org.a.A"]
