import pytest
import os
import asyncio
from unittest.mock import patch, mock_open, MagicMock, AsyncMock

from core.env_manager import EnvManager

@pytest.fixture
def mock_safe_subprocess():
    with patch("core.env_manager.safe_subprocess") as m:
        yield m

def test_check_arch_true():
    with patch("os.path.exists", return_value=True), \
         patch("builtins.open", mock_open(read_data="name=arch linux")):
        manager = EnvManager()
        assert manager.is_arch is True

def test_check_arch_false():
    with patch("os.path.exists", return_value=True), \
         patch("builtins.open", mock_open(read_data="name=ubuntu")):
        manager = EnvManager()
        assert manager.is_arch is False

def test_check_arch_not_exists():
    with patch("os.path.exists", return_value=False):
        manager = EnvManager()
        assert manager.is_arch is False

@pytest.mark.asyncio
async def test_has_cmd_true(mock_safe_subprocess):
    proc_mock = AsyncMock()
    proc_mock.returncode = 0
    mock_safe_subprocess.return_value.__aenter__.return_value = proc_mock

    manager = EnvManager()
    assert await manager._has_cmd("git") is True

@pytest.mark.asyncio
async def test_has_cmd_false(mock_safe_subprocess):
    proc_mock = AsyncMock()
    proc_mock.returncode = 1
    mock_safe_subprocess.return_value.__aenter__.return_value = proc_mock

    manager = EnvManager()
    assert await manager._has_cmd("git") is False

@pytest.mark.asyncio
async def test_has_pkg_true():
    manager = EnvManager()
    with patch.object(manager, "_has_cmd", return_value=True), \
         patch("core.env_manager.safe_subprocess") as mock_sp:

        proc_mock = AsyncMock()
        proc_mock.returncode = 0
        mock_sp.return_value.__aenter__.return_value = proc_mock

        assert await manager._has_pkg("base-devel") is True

@pytest.mark.asyncio
async def test_check_env():
    manager = EnvManager()
    manager.is_arch = True
    with patch.object(manager, "_has_cmd", side_effect=lambda x: x == "git"), \
         patch.object(manager, "_has_pkg", side_effect=lambda x: x == "base-devel"):

        status = await manager.check_env()
        assert status["is_arch"]["status"] == "ok"
        assert status["git"]["status"] == "ok"
        assert status["yay"]["status"] == "warning"
        assert status["base-devel"]["status"] == "ok"
        assert status["libdbusmenu-gtk3"]["status"] == "warning"
        assert status["libappindicator-gtk3"]["status"] == "warning"

@pytest.mark.asyncio
async def test_bootstrap_non_arch():
    manager = EnvManager()
    manager.is_arch = False
    cb = AsyncMock()
    assert await manager.bootstrap(cb) is False
    cb.assert_called_with("[ERROR] Cannot bootstrap on non-Arch system.")

@pytest.mark.asyncio
async def test_bootstrap_success():
    manager = EnvManager()
    manager.is_arch = True

    async def mock_has_cmd(cmd):
        return cmd == "pacman"

    async def mock_has_pkg(pkg):
        return False

    with patch.object(manager, "_has_cmd", side_effect=mock_has_cmd), \
         patch.object(manager, "_has_pkg", side_effect=mock_has_pkg), \
         patch.object(manager, "_run_pacman", return_value=True) as mock_rp, \
         patch.object(manager, "_install_yay", return_value=True) as mock_iy:

        cb = AsyncMock()
        assert await manager.bootstrap(cb) is True

        mock_rp.assert_called_once()
        args = mock_rp.call_args[0][0]
        assert "git" in args
        assert "base-devel" in args
        assert "libdbusmenu-gtk3" in args
        assert "libayatana-appindicator" in args

        mock_iy.assert_called_once()
