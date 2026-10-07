import asyncio
import threading
from pathlib import Path
from unittest.mock import AsyncMock

import pytest

from core.sources.appimage.appimage import AppImageSource


@pytest.mark.asyncio
async def test_slow_inventory_yields_to_other_work_and_scans_only_once(monkeypatch, tmp_path):
    applications = tmp_path / "Applications"
    applications.mkdir()
    (applications / "ExampleApp.AppImage").touch()
    monkeypatch.setattr(Path, "home", lambda: tmp_path)
    real_glob = Path.glob
    loop = asyncio.get_running_loop()
    entered = asyncio.Event()
    release = threading.Event()
    scans = []

    def slow_glob(path, pattern, **kwargs):
        if path == applications:
            scans.append(pattern)
            loop.call_soon_threadsafe(entered.set)
            if not release.wait(2):
                raise TimeoutError("Inventory blocked the event loop")
        return real_glob(path, pattern, **kwargs)

    monkeypatch.setattr(Path, "glob", slow_glob)
    source = AppImageSource(None, None)
    monkeypatch.setattr(source, "_fetch_feed", AsyncMock(return_value=[
        {"name": "ExampleApp", "description": "an app"},
        {"name": "OtherApp", "description": "another app"},
    ]))
    task = asyncio.create_task(source.search("app"))
    try:
        await asyncio.wait_for(entered.wait(), timeout=1)
        # This independent coroutine must run while the inventory is blocked.
        await asyncio.sleep(0)
        assert not task.done()
        release.set()
        results = await asyncio.wait_for(task, timeout=1)
        assert scans == ["*.AppImage"]
        assert [item["installed"] for item in results] == [True, False]
    finally:
        release.set()
        await asyncio.gather(task, return_exceptions=True)


@pytest.mark.asyncio
async def test_unreadable_inventory_preserves_search_results(monkeypatch, tmp_path):
    monkeypatch.setattr(Path, "home", lambda: tmp_path)

    def denied(*_args, **_kwargs):
        raise PermissionError("fixture")

    monkeypatch.setattr(Path, "glob", denied)
    source = AppImageSource(None, None)
    monkeypatch.setattr(source, "_fetch_feed", AsyncMock(return_value=[
        {"name": "ExampleApp", "description": "an app"},
    ]))
    results = await source.search("example")
    assert len(results) == 1
    assert results[0]["installed"] is False
