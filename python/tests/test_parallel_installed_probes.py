import asyncio
import contextlib
from unittest.mock import AsyncMock
import pytest
from core.sources.external import BrewSource, ScoopSource


@pytest.mark.asyncio
@pytest.mark.parametrize('source_class,output', [(BrewSource, b'git\n'), (ScoopSource, b'git 2.50.0 [main]\n')])
async def test_search_command_and_installed_probe_overlap(monkeypatch, source_class, output):
    source = source_class()
    source.enabled = True
    probe_started, search_started = asyncio.Event(), asyncio.Event()

    async def probe():
        probe_started.set()
        await search_started.wait()
        return {'git'}

    async def communicate():
        search_started.set()
        await probe_started.wait()
        return output, b''

    proc = AsyncMock()
    proc.communicate = communicate
    source._get_installed_ids = probe

    @contextlib.asynccontextmanager
    async def process(*args, **kwargs):
        yield proc

    monkeypatch.setattr('core.sources.external.safe_subprocess', process)
    result = await asyncio.wait_for(source.search('git'), timeout=1)
    assert result[0]['installed'] is True


@pytest.mark.asyncio
async def test_repeated_search_cancellation_finishes_owned_probe_cleanup(monkeypatch):
    source = BrewSource()
    source.enabled = True
    probe_started, cleanup_started, cleanup_released, cleanup_finished = (asyncio.Event() for _ in range(4))

    async def probe():
        try:
            probe_started.set()
            await asyncio.Future()
        finally:
            cleanup_started.set()
            await cleanup_released.wait()
            cleanup_finished.set()

    async def communicate():
        await probe_started.wait()
        await asyncio.Future()

    proc = AsyncMock()
    proc.communicate = communicate
    source._get_installed_ids = probe

    @contextlib.asynccontextmanager
    async def process(*args, **kwargs):
        yield proc

    monkeypatch.setattr('core.sources.external.safe_subprocess', process)
    task = asyncio.create_task(source.search('git'))
    await asyncio.wait_for(probe_started.wait(), timeout=1)
    task.cancel()
    await asyncio.wait_for(cleanup_started.wait(), timeout=1)
    task.cancel()
    await asyncio.sleep(0)
    assert not task.done()
    assert not cleanup_finished.is_set()
    task.cancel()
    cleanup_released.set()
    with pytest.raises(asyncio.CancelledError):
        await asyncio.wait_for(task, timeout=1)
    assert cleanup_finished.is_set()
