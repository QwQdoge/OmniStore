import asyncio
from types import SimpleNamespace

import pytest

from core.backend import ResourceCoordinator, safe_command
import daemon_main


@pytest.mark.asyncio
async def test_repeated_cancellation_finishes_handle_and_file_cleanup(tmp_path):
    started, release = asyncio.Event(), asyncio.Event()

    class Handle:
        closed = False

        async def close(self):
            started.set()
            await release.wait()
            self.closed = True

    handle = Handle()
    coordinator = ResourceCoordinator()
    coordinator.track_handle(handle)
    temporary = tmp_path / 'owned-temporary'
    temporary.write_text('fixture')
    coordinator.track_file(temporary)
    caller = asyncio.create_task(coordinator.cleanup())
    await started.wait()
    caller.cancel()
    await asyncio.sleep(0)
    caller.cancel()
    await asyncio.sleep(0)
    assert not caller.done()
    release.set()
    with pytest.raises(asyncio.CancelledError):
        await caller
    assert handle.closed
    assert not temporary.exists()
    assert coordinator._handles == []
    assert coordinator._files == set()


@pytest.mark.asyncio
async def test_concurrent_duplicate_check_and_registration_are_atomic():
    entered, release = asyncio.Event(), asyncio.Event()
    calls = []

    @safe_command
    async def run_install(self):
        calls.append(1)
        entered.set()
        await release.wait()
        return True

    owner = SimpleNamespace(_command_lock=asyncio.Lock(), _active_commands={}, json_mode=False)
    # Queue both requests behind the same held critical section. A split
    # check/register implementation lets both checks run before registration.
    await owner._command_lock.acquire()
    first = asyncio.create_task(run_install(owner))
    second = asyncio.create_task(run_install(owner))
    await asyncio.sleep(0)
    owner._command_lock.release()
    await entered.wait()
    assert await second is False
    assert calls == [1]
    release.set()
    assert await first is True
    assert owner._active_commands == {}


@pytest.mark.asyncio
async def test_cancelled_daemon_cleanup_still_terminates_process(monkeypatch):
    cancelling, release = asyncio.Event(), asyncio.Event()

    async def background():
        try:
            await asyncio.Event().wait()
        finally:
            cancelling.set()
            await release.wait()

    class Process:
        returncode = None
        pid = 999999

        def terminate(self):
            self.returncode = 0

    worker = asyncio.create_task(background())
    await asyncio.sleep(0)
    proc = Process()
    monkeypatch.setattr(daemon_main, '_active_tasks', {worker})
    monkeypatch.setattr(daemon_main, '_active_processes', {proc})
    monkeypatch.setattr(daemon_main, '_shutdown_lock', asyncio.Lock())
    caller = asyncio.create_task(daemon_main.cleanup_daemon_resources())
    await cancelling.wait()
    caller.cancel()
    await asyncio.sleep(0)
    assert not caller.done()
    release.set()
    with pytest.raises(asyncio.CancelledError):
        await caller
    assert proc.returncode == 0
    assert daemon_main._active_processes == set()
