from pathlib import Path

import pytest

from core import app_preferences
from core.app_management import ManifestRegistry


class FakeConfig:
    def __init__(self, data=None):
        self._data = data or {}
        self.saved = None

    @property
    def data(self):
        import copy
        return copy.deepcopy(self._data)

    def get(self, key, default=None):
        value = self._data
        for part in key.split("."):
            if not isinstance(value, dict) or part not in value:
                return default
            value = value[part]
        return value

    def save(self, data):
        self._data = data
        self.saved = data
        return True


def test_defaults_are_conservative():
    prefs = app_preferences.read_preferences(FakeConfig())
    assert prefs["autoUpdate"] is False
    assert prefs["notifyUpdates"] is True
    assert prefs["cacheLimitMb"] == 0
    assert 1024 in prefs["cacheLimitChoicesMb"]


def test_legacy_daemon_switch_is_honoured():
    prefs = app_preferences.read_preferences(FakeConfig({"daemon": {"auto_update": True}}))
    assert prefs["autoUpdate"] is True


def test_apply_writes_both_updates_and_daemon_keys():
    config = FakeConfig()
    prefs = app_preferences.apply_preferences(config, {"autoUpdate": True, "cacheLimitMb": 512})
    assert prefs["autoUpdate"] is True and prefs["cacheLimitMb"] == 512
    assert config.saved["daemon"]["auto_update"] is True
    assert config.saved["updates"]["app_cache_limit_mb"] == 512


@pytest.mark.parametrize("changes", [{}, {"cacheLimitMb": 300}, {"autoUpdate": "yes"}, {"other": 1}, []])
def test_invalid_changes_are_rejected(changes):
    with pytest.raises(ValueError):
        app_preferences.apply_preferences(FakeConfig(), changes)


def _flatpak(home: Path, app_id: str, cache_bytes: int, data_bytes: int = 3):
    sandbox = home / ".var/app" / app_id
    (sandbox / "cache").mkdir(parents=True)
    (sandbox / "data").mkdir(parents=True)
    (sandbox / "cache/blob").write_bytes(b"x" * cache_bytes)
    (sandbox / "data/keep").write_bytes(b"y" * data_bytes)
    return {"id": app_id, "name": app_id, "primary_source": "Flatpak", "installed": True}


def test_trim_removes_largest_caches_only_until_under_limit(tmp_path):
    home = tmp_path / "home"
    packages = [_flatpak(home, "org.example.Big", 600), _flatpak(home, "org.example.Small", 100)]
    result = app_preferences.trim_caches(packages, 300, registry=ManifestRegistry([tmp_path / "none"]), home=home)
    assert result["cacheBytesBefore"] == 700
    assert result["bytesFreed"] == 600
    assert result["cacheBytesAfter"] == 100
    assert not (home / ".var/app/org.example.Big/cache").exists()
    assert (home / ".var/app/org.example.Small/cache/blob").exists()
    # Data is never part of the cache policy.
    assert (home / ".var/app/org.example.Big/data/keep").exists()


def test_trim_is_a_no_op_when_off_or_under_limit(tmp_path):
    home = tmp_path / "home"
    packages = [_flatpak(home, "org.example.App", 50)]
    registry = ManifestRegistry([tmp_path / "none"])
    assert app_preferences.trim_caches(packages, 0, registry=registry, home=home)["bytesFreed"] == 0
    assert app_preferences.trim_caches(packages, 1000, registry=registry, home=home)["bytesFreed"] == 0
    assert (home / ".var/app/org.example.App/cache/blob").exists()
