import pytest
from unittest.mock import MagicMock, AsyncMock, patch
from core.sources.flatpak.flatpak import FlatpakSource
import asyncio

@pytest.mark.asyncio
async def test_flatpak_list_installed_parsing():
    # Mocking the response of safe_subprocess
    mock_stdout = (
        b"Firefox\torg.mozilla.firefox\t120.0\tA web browser\t250 MB\n"
        b"VLC\torg.videolan.VLC\t3.0.20\tMedia player\t150 MB\n"
        b"Incomplete\torg.test.incomplete\n" # Test line with missing columns
    )

    source = FlatpakSource()
    source.enabled = True

    # We need to mock safe_subprocess which is used as an async context manager
    with patch("core.sources.flatpak.flatpak.safe_subprocess") as mock_sub:
        mock_proc = AsyncMock()
        mock_proc.communicate.return_value = (mock_stdout, b"")
        mock_proc.__aenter__.return_value = mock_proc
        mock_sub.return_value = mock_proc

        results = await source.list_installed()

        assert len(results) == 3

        # Verify first item
        firefox = next(r for r in results if r["id"] == "org.mozilla.firefox")
        assert firefox["name"] == "Firefox"
        assert firefox["version"] == "120.0"
        assert firefox["description"] == "A web browser"
        assert firefox["installed_size"] == "250 MB"
        assert firefox["size_confidence"] == "reported"
        assert firefox["size_source"] == "flatpak list"

        # Verify second item
        vlc = next(r for r in results if r["id"] == "org.videolan.VLC")
        assert vlc["installed_size"] == "150 MB"

        # Verify incomplete item
        incomplete = next(r for r in results if r["id"] == "org.test.incomplete")
        assert incomplete["name"] == "Incomplete"
        assert incomplete["version"] == "Unknown"
        assert incomplete["installed_size"] is None
        assert incomplete["size_confidence"] == "unknown"

@pytest.mark.asyncio
async def test_flatpak_list_installed_empty():
    source = FlatpakSource()
    source.enabled = True

    with patch("core.sources.flatpak.flatpak.safe_subprocess") as mock_sub:
        mock_proc = AsyncMock()
        mock_proc.communicate.return_value = (b"", b"")
        mock_proc.__aenter__.return_value = mock_proc
        mock_sub.return_value = mock_proc

        results = await source.list_installed()
        assert results == []
