import pytest
from unittest.mock import patch, MagicMock, AsyncMock

from core.download import unified_install, unified_uninstall

@pytest.mark.asyncio
async def test_unified_install_pacman():
    with patch("core.sources.pacman.download.install_pacman", new_callable=AsyncMock) as mock_install:
        mock_install.return_value = True
        package = {"name": "test-pkg"}
        callback = MagicMock()

        result = await unified_install("pacman", package, callback)

        assert result is True
        mock_install.assert_called_once_with(package, callback)

@pytest.mark.asyncio
async def test_unified_install_unknown_source():
    package = {"name": "test-pkg"}
    result = await unified_install("unknown", package)
    assert result is False

@pytest.mark.asyncio
async def test_unified_uninstall_pacman():
    with patch("core.sources.pacman.download.uninstall_pacman", new_callable=AsyncMock) as mock_uninstall:
        mock_uninstall.return_value = True
        package = {"name": "test-pkg"}
        callback = MagicMock()

        result = await unified_uninstall("pacman", package, callback)

        assert result is True
        mock_uninstall.assert_called_once_with(package, callback)

@pytest.mark.asyncio
async def test_unified_uninstall_unknown_source():
    package = {"name": "test-pkg"}
    result = await unified_uninstall("unknown", package)
    assert result is False
