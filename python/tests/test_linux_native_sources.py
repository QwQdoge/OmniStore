import contextlib
from unittest.mock import AsyncMock
import pytest

from core.sources.linux_native import PrivilegedApkSource, PrivilegedAptSource, PrivilegedDnfSource, PrivilegedZypperSource


@pytest.mark.asyncio
@pytest.mark.parametrize('source_class', [PrivilegedApkSource, PrivilegedAptSource, PrivilegedDnfSource, PrivilegedZypperSource])
@pytest.mark.parametrize('identifier', ['--config=/tmp/hostile', '-y', '/tmp/package', 'https://example.com/p.rpm', 'foo;id', 'foo\nbar', ''])
async def test_untrusted_package_identifier_cannot_reach_authorization(monkeypatch, source_class, identifier):
    source = source_class()
    source.enabled = True
    mutation = AsyncMock()
    monkeypatch.setattr(source, '_run_mutation', mutation)
    assert not await source.install({'id': identifier})
    assert not await source.uninstall({'id': identifier})
    mutation.assert_not_called()


@pytest.mark.asyncio
@pytest.mark.parametrize('source_class,command', [
    (PrivilegedApkSource, ['apk', 'add', 'curl']),
    (PrivilegedAptSource, ['apt-get', 'install', '-y', 'curl']),
    (PrivilegedDnfSource, ['dnf', 'install', '-y', 'curl']),
    (PrivilegedZypperSource, ['zypper', '--non-interactive', 'install', 'curl']),
])
async def test_mutation_authorizes_actual_command_with_current_askpass(monkeypatch, source_class, command):
    source = source_class()
    source.enabled = True
    monkeypatch.setattr('core.sources.linux_native.os.geteuid', lambda: 1000)
    source._privilege_manager.subprocess_environment = AsyncMock(return_value={'SUDO_ASKPASS': '/test/helper'})
    proc = AsyncMock()
    proc.stdout = None
    proc.returncode = 0
    captured = []

    @contextlib.asynccontextmanager
    async def process(*args, **kwargs):
        captured.append((args, kwargs))
        yield proc

    monkeypatch.setattr('core.sources.linux_native.safe_subprocess', process)
    assert await source.install({'id': 'curl'})
    assert list(captured[0][0]) == ['sudo', '-A', *command]
    assert captured[0][1]['env']['SUDO_ASKPASS'] == '/test/helper'
    proc.wait.assert_awaited_once()


@pytest.mark.asyncio
async def test_refused_authorization_does_not_start_mutation(monkeypatch):
    source = PrivilegedAptSource()
    source.enabled = True
    monkeypatch.setattr('core.sources.linux_native.os.geteuid', lambda: 1000)
    source._privilege_manager.subprocess_environment = AsyncMock(side_effect=RuntimeError('unavailable'))
    start = AsyncMock()
    monkeypatch.setattr('core.sources.linux_native.safe_subprocess', start)
    assert not await source.install({'id': 'curl'})
    start.assert_not_called()


@pytest.mark.asyncio
async def test_apt_installed_inventory_excludes_removed_and_unconfigured_packages(monkeypatch):
    source = PrivilegedAptSource()
    source.enabled = True
    proc = AsyncMock()
    proc.communicate.return_value = (b'curl\t1.0\tii \nold\t2.0\trc \nunpacked\t3.0\tiU \n', b'')
    proc.returncode = 0
    captured = []

    @contextlib.asynccontextmanager
    async def process(*args, **kwargs):
        captured.append(args)
        yield proc

    monkeypatch.setattr('core.sources.linux_native.safe_subprocess', process)
    installed = await source.list_installed()
    assert captured[0][0] == 'dpkg-query'
    assert [item['id'] for item in installed] == ['curl']
    assert installed[0]['installed'] is True
    assert installed[0]['installed_version'] == '1.0'
    assert 'sudo' not in captured[0]


def test_zypper_search_uses_package_column_and_real_install_status():
    source = PrivilegedZypperSource()
    results = source._parse_search_output(
        'S  | Name | Summary | Type\n'
        'i+ | curl | Client | package\n'
        '   | curl-devel | Headers | package\n'
        '   | development | Group | pattern\n', 'curl')
    assert [item['id'] for item in results] == ['curl', 'curl-devel']
    assert results[0]['installed'] is True
    assert results[1]['installed'] is False
    assert results[0]['variants'][0]['id'] == 'curl'
