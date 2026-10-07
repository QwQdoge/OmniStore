import pytest

from core.update_manager import UpdateManager


@pytest.mark.asyncio
async def test_apt_update_parser(monkeypatch):
    manager = UpdateManager()

    async def fake_capture(command, timeout=45):
        assert command == ["apt", "list", "--upgradable"]
        return (
            0,
            "Listing... Done\n"
            "curl/noble-updates 8.5.0-2ubuntu10.6 amd64 [upgradable from: 8.5.0-2ubuntu10.5]\n",
        )

    monkeypatch.setattr(manager, "_capture", fake_capture)
    updates = await manager.check_apt_updates()

    assert updates == [
        {
            "name": "curl",
            "source": "APT",
            "current_version": "8.5.0-2ubuntu10.5",
            "new_version": "8.5.0-2ubuntu10.6",
            "description": "Update available from APT",
        }
    ]


@pytest.mark.asyncio
async def test_dnf_update_parser_accepts_exit_code_100(monkeypatch):
    manager = UpdateManager()
    monkeypatch.setattr("core.update_manager.shutil.which", lambda command: "/usr/bin/" + command)

    async def fake_capture(command, timeout=45):
        if command == ["dnf", "check-upgrade", "--quiet"]:
            return 100, "firefox.x86_64 141.0-1.fc42 updates\n"
        if command[:3] == ["rpm", "-qa", "--qf"]:
            return 0, "firefox.x86_64\t140.0-1.fc42\n"
        raise AssertionError(command)

    monkeypatch.setattr(manager, "_capture", fake_capture)
    updates = await manager.check_dnf_updates()

    assert updates == [
        {
            "id": "firefox.x86_64",
            "name": "firefox",
            "source": "DNF",
            "current_version": "140.0-1.fc42",
            "new_version": "141.0-1.fc42",
            "description": "Update available from DNF",
        }
    ]


@pytest.mark.asyncio
@pytest.mark.parametrize('method', ['check_apt_updates', 'check_dnf_updates', 'check_zypper_updates', 'check_apk_updates'])
async def test_native_failed_probe_is_not_up_to_date(monkeypatch, method):
    from unittest.mock import AsyncMock
    manager = UpdateManager()
    monkeypatch.setattr(manager, '_capture', AsyncMock(return_value=(124, '')))
    with pytest.raises(RuntimeError, match='probe failed'):
        await getattr(manager, method)()


@pytest.mark.asyncio
async def test_failed_native_probe_preserves_last_checked_state(monkeypatch):
    from unittest.mock import AsyncMock, Mock
    from core.platform_profile import SystemProfile
    manager = UpdateManager(config={'search.sources.apt': True, 'search.sources.flatpak': False})
    manager.profile = SystemProfile('linux', 'ubuntu', native_manager='apt')
    monkeypatch.setattr('core.update_manager.shutil.which', lambda name: '/usr/bin/apt' if name == 'apt' else None)
    monkeypatch.setattr(manager, 'check_apt_updates', AsyncMock(side_effect=RuntimeError('timeout')))
    write = Mock()
    monkeypatch.setattr('core.update_manager.write_state', write)
    with pytest.raises(RuntimeError, match='last known state retained'):
        await manager.check_all_updates()
    write.assert_not_called()


@pytest.mark.asyncio
async def test_alpine_hyphenated_names_and_single_installed_query(monkeypatch):
    from unittest.mock import AsyncMock
    manager = UpdateManager()
    capture = AsyncMock(side_effect=[
        (0, 'lib-foo-bar-1.2-r0 < 1.3-r1\nother-2.0-r1 < 2.1-r0\n'),
        (0, 'lib-foo-bar\nother\n'),
    ])
    monkeypatch.setattr(manager, '_capture', capture)
    updates = await manager.check_apk_updates()
    assert [item['name'] for item in updates] == ['lib-foo-bar', 'other']
    assert updates[0]['current_version'] == '1.2-r0'
    assert updates[0]['new_version'] == '1.3-r1'
    assert capture.await_count == 2


@pytest.mark.asyncio
async def test_zypper_headers_and_update_fields(monkeypatch):
    from unittest.mock import AsyncMock
    manager = UpdateManager()
    monkeypatch.setattr(manager, '_capture', AsyncMock(return_value=(0,
        'S | Repository | Name | Current Version | Available Version | Arch\n'
        'v | repo | curl | 1.0 | 1.1 | x86_64\n')))
    updates = await manager.check_zypper_updates()
    assert len(updates) == 1
    assert updates[0]['name'] == 'curl'
    assert updates[0]['new_version'] == '1.1'


@pytest.mark.asyncio
@pytest.mark.parametrize('name,command', [
    ('apt', ['sudo', '-A', 'apt-get', 'upgrade', '-y']),
    ('dnf', ['sudo', '-A', 'dnf', 'upgrade', '-y']),
    ('zypper', ['sudo', '-A', 'zypper', '--non-interactive', 'update']),
    ('apk', ['sudo', '-A', 'apk', 'upgrade']),
])
async def test_update_all_uses_selected_native_manager_and_existing_lock(monkeypatch, tmp_path, name, command):
    from unittest.mock import AsyncMock
    from core.platform_profile import SystemProfile
    manager = UpdateManager(config={f'search.sources.{name}': True, 'search.sources.flatpak': False})
    manager.profile = SystemProfile('linux', native_manager=name)
    monkeypatch.setenv('XDG_RUNTIME_DIR', str(tmp_path))
    monkeypatch.setenv('XDG_STATE_HOME', str(tmp_path / 'state'))
    executable = command[2]
    monkeypatch.setattr('core.update_manager.shutil.which', lambda value: '/usr/bin/' + value if value in {executable, 'pacman', 'yay'} else None)
    manager.privilege.subprocess_environment = AsyncMock(return_value={'SUDO_ASKPASS': '/test/helper'})
    manager.postflight_report = AsyncMock(return_value={})
    observed = []

    async def run(actual, callback, env=None):
        observed.append(actual)
        # The unchanged interprocess lock must cover the real mutation.
        assert UpdateManager._acquire_update_lock() is None
        return True

    monkeypatch.setattr(manager, '_run_update_command', run)
    assert await manager.apply_all_updates()
    assert observed == [command]


@pytest.mark.asyncio
async def test_immutable_host_cannot_reach_native_update_mutation(monkeypatch):
    from unittest.mock import AsyncMock
    from core.platform_profile import SystemProfile
    manager = UpdateManager()
    manager.profile = SystemProfile('linux', 'fedora', native_manager='dnf', immutable=True)
    monkeypatch.setattr('core.update_manager.shutil.which', lambda value: '/usr/bin/dnf' if value == 'dnf' else None)
    command = AsyncMock()
    monkeypatch.setattr(manager, '_run_update_command', command)
    assert not await manager._apply_all_updates_locked()
    command.assert_not_called()
