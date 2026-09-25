from datetime import datetime, timezone
import json
from pathlib import Path

import pytest

from core.app_management import (
    MANIFEST_SCHEMA,
    MANIFEST_VERSION,
    ManifestRegistry,
    SCHEMA,
    build_app_management_snapshot,
    perform_app_action,
)


def _write_manifest(root: Path) -> None:
    root.mkdir(parents=True)
    (root / "example.json").write_text(
        json.dumps(
            {
                "schema": MANIFEST_SCHEMA,
                "version": MANIFEST_VERSION,
                "match": {"names": ["Example App"], "sources": ["pacman"]},
                "settings": {
                    "provider": "meo-schema",
                    "label": "Example settings",
                    "route": "provider:example",
                },
                "storage": {
                    "config": [{"root": "config", "path": "example-app"}],
                    "cache": [{"root": "cache", "path": "example-app"}],
                    "data": [{"root": "data", "path": "example-app"}],
                },
            }
        ),
        encoding="utf-8",
    )


def test_management_snapshot_exposes_safe_app_scoped_storage(tmp_path, monkeypatch):
    home = tmp_path / "home"
    monkeypatch.setenv("XDG_CONFIG_HOME", str(home / ".config"))
    monkeypatch.setenv("XDG_CACHE_HOME", str(home / ".cache"))
    monkeypatch.setenv("XDG_DATA_HOME", str(home / ".local/share"))
    manifest_root = tmp_path / "manifests"
    _write_manifest(manifest_root)

    config = home / ".config/example-app"
    cache = home / ".cache/example-app"
    config.mkdir(parents=True)
    cache.mkdir(parents=True)
    (config / "settings.ini").write_bytes(b"abc")
    (cache / "thumbs.db").write_bytes(b"12345")

    snapshot = build_app_management_snapshot(
        [{
            "id": "example-app",
            "name": "Example App",
            "primary_source": "Pacman",
            "installed": True,
            "installed_size": "2 MiB",
            "version": "1.2.3",
        }],
        registry=ManifestRegistry([manifest_root]),
        home=home,
        generated_at=datetime(2026, 9, 25, tzinfo=timezone.utc),
    )

    assert snapshot["schema"] == SCHEMA
    assert snapshot["applicationCount"] == 1
    app = snapshot["applications"][0]
    assert app["id"] == "example-app"
    assert app["settings"]["provider"] == "meo-schema"
    assert app["capabilities"]["clearCache"] is True
    assert app["capabilities"]["resetSettings"] is True
    assert app["capabilities"]["clearData"] is True
    assert app["storageBytes"] == 8
    assert all(path.startswith("~/") for row in app["storage"] for path in row["paths"])


def test_flatpak_storage_is_discovered_without_a_manifest(tmp_path):
    home = tmp_path / "home"
    sandbox = home / ".var/app/org.example.Flatpak"
    (sandbox / "config").mkdir(parents=True)
    (sandbox / "cache").mkdir(parents=True)
    (sandbox / "data").mkdir(parents=True)
    (sandbox / "config/settings.json").write_bytes(b"{}")
    (sandbox / "cache/thumb").write_bytes(b"123")
    (sandbox / "data/state.db").write_bytes(b"abcd")

    snapshot = build_app_management_snapshot(
        [{
            "id": "org.example.Flatpak",
            "name": "org.example.Flatpak",
            "primary_source": "Flatpak",
            "installed": True,
        }],
        registry=ManifestRegistry([tmp_path / "missing"]),
        home=home,
    )

    app = snapshot["applications"][0]
    assert {row["id"] for row in app["storage"]} == {"config", "cache", "data"}
    assert app["storageBytes"] == 9
    assert app["capabilities"] == {
        "uninstall": True,
        "clearCache": True,
        "resetSettings": True,
        "clearData": True,
    }


@pytest.mark.asyncio
async def test_clear_cache_never_accepts_a_caller_path(tmp_path, monkeypatch):
    home = tmp_path / "home"
    monkeypatch.setenv("XDG_CACHE_HOME", str(home / ".cache"))
    manifest_root = tmp_path / "manifests"
    _write_manifest(manifest_root)
    cache = home / ".cache/example-app"
    cache.mkdir(parents=True)
    (cache / "payload").write_bytes(b"cache")

    class Backend:
        async def run_list_installed(self, *, json_mode):
            return [{
                "id": "example-app",
                "name": "Example App",
                "primary_source": "Pacman",
                "installed": True,
            }]

    result = await perform_app_action(
        Backend(),
        action="clear-cache",
        app_id="example-app",
        source="pacman",
        registry=ManifestRegistry([manifest_root]),
        home=home,
    )
    assert result["status"] == "success"
    assert result["bytesFreed"] == 5
    assert not cache.exists()


@pytest.mark.asyncio
async def test_unmanifested_native_app_has_no_destructive_storage_action(tmp_path):
    class Backend:
        async def run_list_installed(self, *, json_mode):
            return [{
                "id": "plain-app",
                "name": "Plain App",
                "primary_source": "Pacman",
                "installed": True,
            }]

    with pytest.raises(ValueError, match="action_not_supported"):
        await perform_app_action(
            Backend(),
            action="clear-data",
            app_id="plain-app",
            source="pacman",
            registry=ManifestRegistry([tmp_path / "missing"]),
            home=tmp_path / "home",
        )
