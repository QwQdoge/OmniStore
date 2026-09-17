import asyncio
import subprocess
from unittest.mock import AsyncMock, patch

import pytest

from core.sources.external import BrewSource, ScoopSource


def _process(stdout=b""):
    proc = AsyncMock()
    proc.communicate.return_value = (stdout, b"")
    return proc


@pytest.mark.asyncio
async def test_scoop_fast_probe_avoids_full_installed_scan():
    source = ScoopSource()
    source.enabled = True
    search_proc = _process(b"git 2.50.0 [main]\n")
    source._get_installed_ids = AsyncMock(return_value={"git"})
    source.list_installed = AsyncMock(side_effect=AssertionError("slow installed scan must not run"))
    with patch("core.sources.external.safe_subprocess") as safe:
        safe.return_value.__aenter__.return_value = search_proc
        results = await source.search("git")
    assert results[0]["installed"] is True
    source.list_installed.assert_not_called()


@pytest.mark.asyncio
async def test_scoop_probe_failure_falls_back_without_false_uninstalled_state():
    source = ScoopSource()
    source.enabled = True
    search_proc = _process(b"git 2.50.0 [main]\n")
    source._get_installed_ids = AsyncMock(return_value=None)
    source.list_installed = AsyncMock(return_value=[{"id": "git"}])
    with patch("core.sources.external.safe_subprocess") as safe:
        safe.return_value.__aenter__.return_value = search_proc
        results = await source.search("git")
    assert results[0]["installed"] is True
    source.list_installed.assert_awaited_once()


@pytest.mark.asyncio
async def test_brew_probe_failure_falls_back_without_false_uninstalled_state():
    source = BrewSource()
    source.enabled = True
    search_proc = _process(b"wget\n")
    source._get_installed_ids = AsyncMock(return_value=None)
    source.list_installed = AsyncMock(return_value=[{"id": "wget"}])
    with patch("core.sources.external.safe_subprocess") as safe:
        safe.return_value.__aenter__.return_value = search_proc
        results = await source.search("wget")
    assert results[0]["installed"] is True
    source.list_installed.assert_awaited_once()


@pytest.mark.asyncio
async def test_expected_probe_failure_returns_unknown_signal_and_logs(caplog):
    source = ScoopSource()
    source.enabled = True
    proc = AsyncMock()
    proc.communicate.side_effect = asyncio.TimeoutError()
    with patch("core.sources.external.safe_subprocess") as safe:
        safe.return_value.__aenter__.return_value = proc
        with caplog.at_level("WARNING"):
            installed = await source._get_installed_ids()
    assert installed is None
    assert "falling back" in caplog.text


@pytest.mark.asyncio
async def test_unexpected_probe_and_search_errors_propagate():
    source = ScoopSource()
    source.enabled = True
    proc = AsyncMock()
    proc.communicate.side_effect = TypeError("programming error")
    with patch("core.sources.external.safe_subprocess") as safe:
        safe.return_value.__aenter__.return_value = proc
        with pytest.raises(TypeError, match="programming error"):
            await source._get_installed_ids()
        with pytest.raises(TypeError, match="programming error"):
            await source.search("git")


@pytest.mark.asyncio
async def test_expected_search_subprocess_error_is_logged_and_safe(caplog):
    source = BrewSource()
    source.enabled = True
    proc = AsyncMock()
    proc.communicate.side_effect = subprocess.SubprocessError("brew failed")
    with patch("core.sources.external.safe_subprocess") as safe:
        safe.return_value.__aenter__.return_value = proc
        with caplog.at_level("WARNING"):
            results = await source.search("wget")
    assert results == []
    assert "Homebrew search failed" in caplog.text
