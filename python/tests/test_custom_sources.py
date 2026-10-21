import asyncio
import json
from pathlib import Path

import pytest

from core.config_loader import ConfigManager, ConfigModel
from core.search import custom_sources
from core.search.custom_sources import GenericCustomSources, SPECS


@pytest.fixture
def cm(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    return ConfigManager()


def run(coro):
    return asyncio.run(coro)


def test_every_spec_has_a_config_slot(cm):
    for source in SPECS:
        assert source in cm.data["custom_repos"]


def test_track_mode_records_without_running_commands(cm, monkeypatch):
    async def fail(*_a, **_k):
        raise AssertionError("track mode must not run commands")

    manager = GenericCustomSources(cm)
    monkeypatch.setattr(manager, "_run", fail)
    assert run(manager.add("apt", "ppa-test", "https://example.org/apt"))
    assert manager.list("apt") == [{"name": "ppa-test", "url": "https://example.org/apt"}]
    assert run(manager.remove("apt", "ppa-test"))
    assert manager.list("apt") == []


def test_apply_mode_persists_only_after_cli_success(cm, monkeypatch):
    manager = GenericCustomSources(cm)
    monkeypatch.setattr(custom_sources.shutil, "which", lambda _b: "/usr/bin/x")
    calls = []

    async def ok(command):
        calls.append(list(command))
        return True

    monkeypatch.setattr(manager, "_run", ok)
    assert run(manager.add("scoop", "extras", "https://example.org/extras"))
    assert calls == [["scoop", "bucket", "add", "extras", "https://example.org/extras"]]

    async def bad(command):
        return False

    monkeypatch.setattr(manager, "_run", bad)
    assert not run(manager.add("scoop", "other", "https://example.org/o"))
    assert [i["name"] for i in manager.list("scoop")] == ["extras"]


def test_missing_binary_is_reported_and_nothing_saved(cm, monkeypatch):
    manager = GenericCustomSources(cm)
    monkeypatch.setattr(custom_sources.shutil, "which", lambda _b: None)
    assert not run(manager.add("winget", "mine", "https://example.org/w"))
    assert manager.list("winget") == []


@pytest.mark.parametrize("source,name,url", [
    ("apt", "-bad", "https://example.org"),
    ("apt", "a b", "https://example.org"),
    ("apt", "ok", "ftp://example.org"),
    ("apt", "ok", ""),
    ("github", "a/b/c", ""),
    ("unknown", "ok", "https://example.org"),
])
def test_invalid_input_rejected(cm, source, name, url):
    assert not run(GenericCustomSources(cm).add(source, name, url))


def test_github_and_brew_do_not_need_a_url(cm, monkeypatch):
    manager = GenericCustomSources(cm)
    assert run(manager.add("github", "QwQdoge/OmniStore", ""))
    assert manager.list("github")[0]["url"] == "https://github.com/QwQdoge/OmniStore"
    monkeypatch.setattr(custom_sources.shutil, "which", lambda _b: "/usr/bin/brew")

    async def ok(_c):
        return True

    monkeypatch.setattr(manager, "_run", ok)
    assert run(manager.add("brew", "homebrew/cask-fonts", ""))


def test_ai_api_key_is_never_persisted(cm):
    data = cm.data
    data["ai"]["api_key"] = "sk-secret-secret-secret"
    assert cm.save(data)
    assert "sk-secret" not in cm.config_path.read_text(encoding="utf-8")


def test_schema_matches_config_model():
    schema = json.loads((Path(__file__).resolve().parents[2] / "config_schema.json").read_text())
    sources = schema["properties"]["search"]["properties"]["sources"]
    model_sources = set(ConfigModel().search.sources.model_dump())
    assert set(sources["properties"]) == model_sources
    assert set(sources["required"]) == model_sources
    assert set(schema["properties"]) >= set(ConfigModel().model_dump())


def test_template_defaults_match_code_defaults():
    import yaml

    template = yaml.safe_load((Path(__file__).resolve().parents[1] / "config.yaml").read_text())
    defaults = ConfigModel().model_dump()
    for key, value in template["search"]["sources"].items():
        assert defaults["search"]["sources"][key] == value, key
    assert "api_key" not in template["ai"]
    ConfigModel(**template)
