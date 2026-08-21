import os

import yaml

from core.config_loader import ConfigManager


def test_config_manager_reloads_external_source_changes(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    manager = ConfigManager()

    assert manager.get("search.sources.apt") is False

    path = tmp_path / "omnistore" / "config.yaml"
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    data["search"]["sources"]["apt"] = True
    data["plugins"]["enabled"]["builtin.apt"] = True
    path.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")

    # Guarantee an mtime change even on filesystems with coarse timestamp
    # behavior under test runners/containers.
    stat = path.stat()
    os.utime(path, ns=(stat.st_atime_ns, stat.st_mtime_ns + 1_000_000))

    assert manager.get("search.sources.apt") is True
    assert manager.get("plugins.enabled.builtin.apt") is True
