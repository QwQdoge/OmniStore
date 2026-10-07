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


def test_invalid_external_settings_keep_last_valid_config(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    manager = ConfigManager()
    assert manager.set("ui.font_scale", 1.5)
    manager.config_path.write_text("ui: {font_scale: -9}\n", encoding="utf-8")
    assert manager.get("ui.font_scale") == 1.5
    manager.config_path.write_text("- not a mapping\n", encoding="utf-8")
    assert manager.data["ui"]["font_scale"] == 1.5
    manager.config_path.write_text("ui: {font_scale: 1.25}\n", encoding="utf-8")
    assert manager.get("ui.font_scale") == 1.25


def test_concurrent_managers_use_distinct_private_temporary_files(tmp_path, monkeypatch):
    import concurrent.futures
    import threading
    from pathlib import Path
    import core.config_loader as config_loader

    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    first, second = ConfigManager(), ConfigManager()
    barrier = threading.Barrier(2)
    replace = config_loader.os.replace
    temporary_paths = []

    def synchronized_replace(source, destination):
        temporary_paths.append(source)
        assert Path(source).stat().st_mode & 0o777 == 0o600
        assert Path(source).is_file()
        barrier.wait(timeout=5)
        return replace(source, destination)

    monkeypatch.setattr(config_loader.os, "replace", synchronized_replace)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(manager.set, "ui.font_scale", value)
                   for manager, value in ((first, 1.25), (second, 1.5))]
        assert all(future.result(timeout=10) for future in futures)
    assert len(set(temporary_paths)) == 2
    assert all(not Path(path).exists() for path in temporary_paths)
    assert yaml.safe_load(first.config_path.read_text())["ui"]["font_scale"] in (1.25, 1.5)
