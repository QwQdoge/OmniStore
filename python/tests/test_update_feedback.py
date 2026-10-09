import json
import asyncio
from contextlib import asynccontextmanager
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from core.backend import OmnistoreBackend
from core.platform_profile import SystemProfile
from core.transaction_manager import TransactionRecord, _TaskCapture
from core.update_manager import UpdateManager


@pytest.mark.asyncio
async def test_update_feedback_tracks_sources_and_continues_after_failure(monkeypatch, tmp_path):
    manager = UpdateManager(config={"updates.include_aur_in_update_all": False})
    manager.profile = SystemProfile("linux", native_manager="pacman")
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(tmp_path))
    monkeypatch.setattr("core.update_manager.shutil.which", lambda name: "/usr/bin/" + name)
    manager.privilege.subprocess_environment = AsyncMock(return_value={})
    events = []

    async def run(command, callback, env=None):
        await callback("[INFO] Downloading packages 25%")
        return command[0] != "sudo"

    monkeypatch.setattr(manager, "_run_update_command", run)
    assert not await manager.apply_all_updates(events.append)
    source_events = [json.loads(event[len("[SOURCE] "):]) for event in events if event.startswith("[SOURCE] ")]
    assert any(event["source"] == "AUR" and event["status"] == "skipped" for event in source_events)
    assert any(event["source"] == "Pacman" and event["status"] == "failed" for event in source_events)
    assert any(event["source"] == "Flatpak" and event["status"] == "succeeded" for event in source_events)
    assert any(event["source"] == "Pacman" and event["progress"] == 0.25 for event in source_events)
    assert events[-1] == "[STAGE] Updates completed with failures"
    assert "[PROGRESS] 0" in events and "[PROGRESS] 100" in events


def test_disabled_plugin_is_also_excluded_from_updates():
    manager = UpdateManager(config={"plugins.enabled": {"builtin.flatpak": False}})
    assert not manager._source_enabled("flatpak")


@pytest.mark.asyncio
async def test_carriage_return_progress_is_streamed_before_process_finishes(monkeypatch):
    output = asyncio.StreamReader()
    events = []
    waiting = asyncio.Event()

    async def wait():
        waiting.set()

    @asynccontextmanager
    async def process(*args, **kwargs):
        yield SimpleNamespace(stdout=output, wait=wait, returncode=0)

    monkeypatch.setattr("core.update_manager.safe_subprocess", process)
    manager = UpdateManager()
    task = asyncio.create_task(manager._run_update_command(["test-only"], events.append))
    output.feed_data(b"Downloading 25%\rDownloading 50%\r")
    for _ in range(20):
        if events:
            break
        await asyncio.sleep(0)
    assert events == ["[INFO] Downloading 25%", "[INFO] Downloading 50%"]
    assert not waiting.is_set()
    output.feed_eof()
    assert await task


@pytest.mark.asyncio
async def test_source_feedback_survives_transaction_snapshot_without_hiding_fingerprint(capsys):
    backend = OmnistoreBackend.__new__(OmnistoreBackend)
    record = TransactionRecord(task_id="test", kind="update_all", name="all", source="all", status="running")
    capture = _TaskCapture(record)
    await backend._flutter_callback("[INFO] Place your finger on the reader", json_mode=True)
    capture.write(capsys.readouterr().out)
    prompt = record.authentication_prompt
    assert prompt
    update = {"source": "Pacman", "status": "running", "progress": 0.25, "detail": "Downloading"}
    await backend._flutter_callback("[SOURCE] " + json.dumps(update), json_mode=True)
    capture.write(capsys.readouterr().out)
    assert record.snapshot()["sourceUpdates"] == [update]
    assert record.authentication_prompt == prompt
    update["status"] = "succeeded"
    await backend._flutter_callback("[SOURCE] " + json.dumps(update), json_mode=True)
    capture.write(capsys.readouterr().out)
    assert len(record.snapshot()["sourceUpdates"]) == 1
    assert record.snapshot()["sourceUpdates"][0]["status"] == "succeeded"
