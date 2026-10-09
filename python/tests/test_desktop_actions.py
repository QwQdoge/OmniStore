import asyncio
import os
from pathlib import Path
import subprocess
import sys
import time
from unittest.mock import AsyncMock

import pytest

from core.desktop_actions import launch_detached, launch_native_package, locate_native_package


def test_application_survives_backend_exit(tmp_path):
    marker = tmp_path / "still-running"
    worker = tmp_path / "app.py"
    worker.write_text("import sys,time\nfrom pathlib import Path\ntime.sleep(0.7)\nPath(sys.argv[1]).touch()\n")
    script = ("import asyncio,sys\nfrom core.desktop_actions import launch_detached\n"
              "assert asyncio.run(launch_detached(sys.executable, sys.argv[1], sys.argv[2]))\n")
    subprocess.run([sys.executable, "-c", script, str(worker), str(marker)], check=True,
                   env={**os.environ, "PYTHONPATH": str(Path(__file__).parents[1])}, timeout=5)
    for _ in range(30):
        if marker.exists():
            break
        time.sleep(0.05)
    assert marker.exists()


@pytest.mark.asyncio
async def test_immediate_launch_failure_is_not_success():
    assert not await launch_detached(sys.executable, "-c", "raise SystemExit(3)")
    assert not await launch_detached("/nonexistent-omnistore-test-program")


@pytest.mark.asyncio
async def test_native_package_uses_owned_desktop_entry(tmp_path, monkeypatch):
    applications = tmp_path / "applications"
    applications.mkdir()
    desktop = applications / "org.example.Editor.desktop"
    desktop.write_text("[Desktop Entry]\nType=Application\nName=Editor\nExec=actual-editor %U\n")
    monkeypatch.setattr("core.desktop_actions.native_package_files", AsyncMock(return_value=[desktop]))
    monkeypatch.setattr("core.desktop_actions.shutil.which", lambda _: "/usr/bin/gio")
    launch = AsyncMock(return_value=True)
    monkeypatch.setattr("core.desktop_actions.launch_detached", launch)
    assert await launch_native_package("editor-bin")
    launch.assert_awaited_once_with("gio", "launch", str(desktop))
    launch.reset_mock()
    assert await locate_native_package("editor-bin")
    launch.assert_awaited_once_with("xdg-open", str(applications))


@pytest.mark.asyncio
async def test_unknown_package_does_not_run_arbitrary_binary(monkeypatch):
    monkeypatch.setattr("core.desktop_actions.native_package_files", AsyncMock(return_value=[]))
    launch = AsyncMock()
    monkeypatch.setattr("core.desktop_actions.launch_detached", launch)
    assert not await launch_native_package("not-installed")
    launch.assert_not_awaited()
