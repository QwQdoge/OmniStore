from datetime import datetime, timezone

import pytest

from core.apps_usage_export import (
    SCHEMA,
    SCHEMA_VERSION,
    _size_from_reported_value,
    build_installed_usage_snapshot,
    export_installed_usage,
)


def test_parses_only_explicit_units_without_guessing():
    assert _size_from_reported_value("1.5 MiB") == 1572864
    assert _size_from_reported_value("511.1\u00a0MB") == 511100000
    assert _size_from_reported_value("100") is None
    assert _size_from_reported_value("ten MiB") is None
    assert _size_from_reported_value(-1) is None


def test_snapshot_is_bounded_to_installed_app_metadata():
    snapshot = build_installed_usage_snapshot(
        [
            {
                "name": "Exact App",
                "primary_source": "AppImage",
                "installed": True,
                "disk_size": 4096,
                "installed_size": "999 GiB",
                "install_location": "/home/example/Applications/exact.AppImage",
            },
            {
                "name": "Reported App",
                "primary_source": "Flatpak",
                "installed": True,
                "installed_size": "2 MB",
            },
            {
                "name": "Unknown App",
                "primary_source": "Pacman",
                "installed": True,
                "installed_size": "unknown",
            },
            {"name": "Not installed", "primary_source": "Pacman", "installed": False},
        ],
        generated_at=datetime(2026, 8, 23, 0, 0, tzinfo=timezone.utc),
    )

    assert snapshot["schema"] == SCHEMA
    assert snapshot["version"] == SCHEMA_VERSION
    assert snapshot["status"] == "success"
    assert snapshot["generatedAt"] == "2026-08-23T00:00:00Z"
    assert snapshot["applicationCount"] == 3
    assert snapshot["knownSizeBytes"] == 2_004_096
    assert snapshot["unknownSizeCount"] == 1
    exact_app = next(app for app in snapshot["applications"] if app["name"] == "Exact App")
    assert "install_location" not in exact_app
    assert exact_app["sizeKind"] == "exact"
    assert {source["id"] for source in snapshot["sources"]} == {
        "appimage",
        "flatpak",
        "pacman",
    }


@pytest.mark.asyncio
async def test_export_unwraps_the_json_mode_command_envelope():
    class Backend:
        async def run_list_installed(self, *, json_mode):
            assert json_mode is False
            return {
                "status": "success",
                "response": [
                    {
                        "name": "Store App",
                        "primary_source": "Pacman",
                        "installed": True,
                        "installed_size": "3 KiB",
                    }
                ],
            }

    snapshot = await export_installed_usage(Backend())
    assert snapshot["applicationCount"] == 1
    assert snapshot["knownSizeBytes"] == 3072


@pytest.mark.asyncio
async def test_export_does_not_convert_a_backend_failure_to_an_empty_inventory():
    class Backend:
        async def run_list_installed(self, *, json_mode):
            return {"status": "error", "error": "Timeout"}

    with pytest.raises(RuntimeError):
        await export_installed_usage(Backend())
