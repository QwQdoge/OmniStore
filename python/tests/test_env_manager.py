import asyncio
import sys
from unittest.mock import AsyncMock

import pytest
from core.env_manager import EnvManager
from core.platform_profile import SystemProfile


def manager_for(monkeypatch, profile, commands=()):
    monkeypatch.setattr('core.env_manager.detect_system_profile', lambda: profile)
    manager = EnvManager()
    monkeypatch.setattr(manager, '_has_cmd', lambda command: command in commands)
    return manager


@pytest.mark.asyncio
async def test_non_arch_supported_host_is_not_fatal(monkeypatch):
    manager = manager_for(monkeypatch, SystemProfile('linux', 'ubuntu', native_manager='apt'), ('apt-get',))
    result = await manager.check_env()
    assert all(item['status'] != 'fatal' for item in result.values())
    assert result['system']['native_manager'] == 'apt'
    assert result['system']['recommended_sources'] == ['apt', 'flatpak', 'appimage']
    assert 'aur_helper' not in result


@pytest.mark.asyncio
@pytest.mark.parametrize('platform', ['macos', 'windows'])
async def test_desktop_platform_does_not_mutate_linux_host(monkeypatch, platform):
    manager = manager_for(monkeypatch, SystemProfile(platform))
    command = AsyncMock()
    monkeypatch.setattr(manager, '_run_host_command', command)
    assert await manager.bootstrap()
    command.assert_not_called()


@pytest.mark.asyncio
async def test_immutable_host_never_mutated_through_dnf(monkeypatch):
    manager = manager_for(monkeypatch, SystemProfile('linux', 'fedora', immutable=True), ('dnf',))
    command = AsyncMock()
    monkeypatch.setattr(manager, '_run_host_command', command)
    assert not await manager.bootstrap()
    command.assert_not_called()
    monkeypatch.setattr(manager, '_has_cmd', lambda command: command in ('flatpak', 'dnf'))
    remote = AsyncMock(return_value=True)
    monkeypatch.setattr(manager, '_ensure_flathub', remote)
    assert await manager.bootstrap()
    remote.assert_awaited_once()
    command.assert_not_called()


@pytest.mark.asyncio
@pytest.mark.parametrize('name,expected', [
    ('pacman', ['pacman', '-S', '--noconfirm', '--needed', 'flatpak']),
    ('apt', ['apt-get', 'install', '-y', 'flatpak']),
    ('dnf', ['dnf', 'install', '-y', 'flatpak']),
    ('zypper', ['zypper', '--non-interactive', 'install', 'flatpak']),
    ('apk', ['apk', 'add', 'flatpak']),
])
async def test_native_bootstrap_routes_static_packages(monkeypatch, name, expected):
    manager = manager_for(monkeypatch, SystemProfile('linux', native_manager=name))
    command = AsyncMock(return_value=True)
    monkeypatch.setattr(manager, '_run_host_command', command)
    assert await manager._install_native_packages(['flatpak'])
    assert command.call_args.args[0] == expected
    if name == 'apt':
        assert command.call_args_list[0].args[0] == ['apt-get', 'update']
        assert await manager._install_native_packages(['flatpak'])
        assert sum(call.args[0] == ['apt-get', 'update'] for call in command.call_args_list) == 1


@pytest.mark.asyncio
async def test_failed_metadata_update_prevents_install(monkeypatch):
    manager = manager_for(monkeypatch, SystemProfile('linux', native_manager='apt'))
    command = AsyncMock(return_value=False)
    monkeypatch.setattr(manager, '_run_host_command', command)
    assert not await manager._install_native_packages(['flatpak'])
    command.assert_awaited_once()
    assert not manager._apt_updated


@pytest.mark.asyncio
async def test_real_operation_uses_askpass_not_cached_sudo(monkeypatch):
    manager = manager_for(monkeypatch, SystemProfile('linux', native_manager='apt'), ('sudo',))
    monkeypatch.setattr('core.env_manager.os.geteuid', lambda: 1000)
    manager.privilege.subprocess_environment = AsyncMock(return_value={'SUDO_ASKPASS': '/test/helper'})
    command = AsyncMock(return_value=True)
    monkeypatch.setattr(manager, '_run_command', command)
    assert await manager._run_host_command(['apt-get', 'install', '-y', 'flatpak'])
    assert command.call_args.args[0] == ['sudo', '-A', 'apt-get', 'install', '-y', 'flatpak']
    assert command.call_args.kwargs['env']['SUDO_ASKPASS'] == '/test/helper'


@pytest.mark.asyncio
async def test_silent_process_cannot_evade_streaming_deadline(monkeypatch):
    manager = manager_for(monkeypatch, SystemProfile('linux'))
    callback = AsyncMock()
    started = asyncio.get_running_loop().time()
    assert not await manager._run_command([sys.executable, '-c', 'import time; time.sleep(30)'], callback, timeout=.1)
    assert asyncio.get_running_loop().time() - started < 5
    callback.assert_awaited_with('[ERROR] System command timed out.')


@pytest.mark.asyncio
async def test_aur_build_is_not_started_as_root(monkeypatch):
    manager = manager_for(monkeypatch, SystemProfile('linux', native_manager='pacman'))
    monkeypatch.setattr('core.env_manager.os.geteuid', lambda: 0)
    command = AsyncMock()
    monkeypatch.setattr(manager, '_run_command', command)
    assert not await manager._install_yay()
    command.assert_not_called()


@pytest.mark.asyncio
async def test_standard_bootstrap_never_builds_community_helper_without_opt_in(monkeypatch):
    manager = manager_for(monkeypatch, SystemProfile('linux', 'arch', native_manager='pacman'), ('pacman', 'flatpak'))
    monkeypatch.setattr(manager, '_ensure_flathub', AsyncMock(return_value=True))
    helper = AsyncMock()
    monkeypatch.setattr(manager, '_install_yay', helper)
    assert await manager.bootstrap()
    helper.assert_not_called()


@pytest.mark.asyncio
async def test_explicit_aur_setup_preserves_existing_paru(monkeypatch):
    manager = manager_for(monkeypatch, SystemProfile('linux', 'arch', native_manager='pacman'), ('pacman', 'paru'))
    helper = AsyncMock()
    monkeypatch.setattr(manager, '_install_yay', helper)
    assert await manager.bootstrap_aur()
    helper.assert_not_called()


@pytest.mark.asyncio
async def test_explicit_aur_setup_does_not_mutate_other_distribution(monkeypatch):
    manager = manager_for(monkeypatch, SystemProfile('linux', 'ubuntu', native_manager='apt'), ('apt-get',))
    packages = AsyncMock()
    monkeypatch.setattr(manager, '_install_native_packages', packages)
    assert not await manager.bootstrap_aur()
    packages.assert_not_called()
