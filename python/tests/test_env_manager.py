import pytest
from unittest.mock import AsyncMock, patch
from core.env_manager import EnvManager

@pytest.fixture
def env_manager():
    with patch.object(EnvManager, '_check_arch', return_value=True):
        return EnvManager()

@pytest.mark.asyncio
async def test_bootstrap_non_arch():
    with patch.object(EnvManager, '_check_arch', return_value=False):
        env = EnvManager()
        callback = AsyncMock()
        result = await env.bootstrap(callback=callback)
        assert result is False
        callback.assert_called_once_with("[ERROR] Cannot bootstrap on non-Arch system.")

@pytest.mark.asyncio
async def test_bootstrap_all_installed(env_manager):
    callback = AsyncMock()
    env_manager._has_pkg = AsyncMock(return_value=True)
    env_manager._has_cmd = AsyncMock(return_value=True)
    env_manager._run_pacman = AsyncMock()
    env_manager._install_yay = AsyncMock()

    result = await env_manager.bootstrap(callback=callback)

    assert result is True
    env_manager._run_pacman.assert_not_called()
    env_manager._install_yay.assert_not_called()
    callback.assert_any_call("[INFO] Environment bootstrap completed successfully.")

@pytest.mark.asyncio
async def test_bootstrap_missing_deps_success(env_manager):
    callback = AsyncMock()
    env_manager._has_pkg = AsyncMock(return_value=False)
    env_manager._has_cmd = AsyncMock(return_value=False)
    env_manager._run_pacman = AsyncMock(return_value=True)
    env_manager._install_yay = AsyncMock(return_value=True)

    result = await env_manager.bootstrap(callback=callback)

    assert result is True
    env_manager._run_pacman.assert_called_once_with(
        ["-S", "--noconfirm", "--needed", "git", "base-devel", "libdbusmenu-gtk3", "libayatana-appindicator"],
        callback
    )
    env_manager._install_yay.assert_called_once_with(callback)

@pytest.mark.asyncio
async def test_bootstrap_pacman_failure(env_manager):
    callback = AsyncMock()
    env_manager._has_pkg = AsyncMock(return_value=False)
    env_manager._has_cmd = AsyncMock(return_value=False)
    env_manager._run_pacman = AsyncMock(return_value=False)
    env_manager._install_yay = AsyncMock()

    result = await env_manager.bootstrap(callback=callback)

    assert result is False
    env_manager._run_pacman.assert_called_once()
    env_manager._install_yay.assert_not_called()
    callback.assert_any_call("[ERROR] Failed to install dependencies.")

@pytest.mark.asyncio
async def test_bootstrap_yay_failure(env_manager):
    callback = AsyncMock()
    async def mock_has_cmd(cmd):
        if cmd == "git": return True
        if cmd == "yay": return False
        return True
    env_manager._has_pkg = AsyncMock(return_value=True)
    env_manager._has_cmd = AsyncMock(side_effect=mock_has_cmd)
    env_manager._run_pacman = AsyncMock()
    env_manager._install_yay = AsyncMock(return_value=False)

    result = await env_manager.bootstrap(callback=callback)

    assert result is False
    env_manager._run_pacman.assert_not_called()
    env_manager._install_yay.assert_called_once()

@pytest.mark.asyncio
async def test_bootstrap_libappindicator_fallback(env_manager):
    callback = AsyncMock()
    async def mock_has_pkg(pkg):
        if pkg == "libayatana-appindicator": return False
        return True
    async def mock_has_cmd(cmd):
        return True
    env_manager._has_pkg = AsyncMock(side_effect=mock_has_pkg)
    env_manager._has_cmd = AsyncMock(side_effect=mock_has_cmd)
    env_manager._run_pacman = AsyncMock()
    env_manager._install_yay = AsyncMock()

    result = await env_manager.bootstrap(callback=callback)

    assert result is True
    env_manager._run_pacman.assert_not_called()
