import asyncio
import logging
import pytest
from unittest.mock import AsyncMock, patch

from core.sources.external import ScoopSource, BrewSource


@pytest.mark.asyncio
async def test_scoop_get_installed_ids():
    source = ScoopSource()
    source.enabled = True

    mock_proc = AsyncMock()
    mock_proc.communicate.return_value = (
        b"Name    Version Source\n----    ------- ------\ncurl    7.80.0  main\ngit     2.35.1  main\n",
        b"",
    )

    with patch("core.sources.external.safe_subprocess") as mock_sub:
        mock_sub.return_value.__aenter__.return_value = mock_proc
        installed_ids = await source._get_installed_ids()

    assert installed_ids == {"curl", "git"}


@pytest.mark.asyncio
async def test_brew_get_installed_ids():
    source = BrewSource()
    source.enabled = True

    mock_proc = AsyncMock()
    mock_proc.communicate.return_value = (
        b"wget 1.21.2\npython@3.12 3.12.1\n",
        b"",
    )

    with patch("core.sources.external.safe_subprocess") as mock_sub:
        mock_sub.return_value.__aenter__.return_value = mock_proc
        installed_ids = await source._get_installed_ids()

    assert installed_ids == {"wget", "python@3.12"}


@pytest.mark.asyncio
async def test_scoop_search_does_not_call_list_installed():
    source = ScoopSource()
    source.enabled = True

    mock_proc = AsyncMock()
    mock_proc.communicate.return_value = (
        b"git 2.35.1 [main]\n",
        b"",
    )

    mock_get_installed = AsyncMock(return_value={"git"})
    mock_list_installed = AsyncMock(side_effect=AssertionError("list_installed should not be called"))

    source._get_installed_ids = mock_get_installed
    source.list_installed = mock_list_installed

    with patch("core.sources.external.safe_subprocess") as mock_sub:
        mock_sub.return_value.__aenter__.return_value = mock_proc
        results = await source.search("git")

    assert len(results) == 1
    assert results[0]["id"] == "git"
    assert results[0]["installed"] is True
    mock_get_installed.assert_called_once()
    mock_list_installed.assert_not_called()


@pytest.mark.asyncio
async def test_brew_search_does_not_call_list_installed():
    source = BrewSource()
    source.enabled = True

    mock_proc = AsyncMock()
    mock_proc.communicate.return_value = (
        b"wget\n",
        b"",
    )

    mock_get_installed = AsyncMock(return_value={"wget"})
    mock_list_installed = AsyncMock(side_effect=AssertionError("list_installed should not be called"))

    source._get_installed_ids = mock_get_installed
    source.list_installed = mock_list_installed

    with patch("core.sources.external.safe_subprocess") as mock_sub:
        mock_sub.return_value.__aenter__.return_value = mock_proc
        results = await source.search("wget")

    assert len(results) == 1
    assert results[0]["id"] == "wget"
    assert results[0]["installed"] is True
    mock_get_installed.assert_called_once()
    mock_list_installed.assert_not_called()


@pytest.mark.asyncio
async def test_search_timeout_handles_gracefully(caplog):
    source = ScoopSource()
    source.enabled = True

    mock_proc = AsyncMock()
    mock_proc.communicate.side_effect = asyncio.TimeoutError()

    with patch("core.sources.external.safe_subprocess") as mock_sub:
        mock_sub.return_value.__aenter__.return_value = mock_proc
        with caplog.at_level(logging.WARNING):
            results = await source.search("timeout_app")

    assert results == []
    assert "Scoop search failed" in caplog.text
