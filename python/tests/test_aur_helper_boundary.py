import contextlib
from unittest.mock import AsyncMock
import pytest
from core.sources.aur.aur import AurSource


@pytest.mark.asyncio
@pytest.mark.parametrize('name', ['--config=/tmp/injected', '-Syu', '/tmp/evil', 'foo bar', 'foo;bar'])
async def test_aur_bad_target_is_rejected_before_authorization(name):
    source = AurSource(None)
    source.privilege.ensure_privileged = AsyncMock()
    assert not await source.install({'name': name})
    assert not await source.uninstall({'name': name})
    source.privilege.ensure_privileged.assert_not_called()


@pytest.mark.asyncio
async def test_existing_paru_helper_reuses_current_graphical_authorization(monkeypatch):
    source = AurSource(None)
    source.privilege.ensure_privileged = AsyncMock(return_value=True)
    source.privilege.subprocess_environment = AsyncMock(return_value={'SUDO_ASKPASS': '/test/helper'})
    monkeypatch.setattr('core.sources.aur.aur.shutil.which', lambda command: '/usr/bin/paru' if command == 'paru' else None)
    proc = AsyncMock()
    proc.stdout = None
    proc.returncode = 0
    calls = []

    @contextlib.asynccontextmanager
    async def process(*args, **kwargs):
        calls.append((args, kwargs))
        yield proc

    monkeypatch.setattr('core.sources.aur.aur.safe_subprocess', process)
    assert await source.install({'name': 'yay-bin'})
    assert calls[0][0] == ('paru', '--sudoflags', '-A', '-S', '--noconfirm', 'yay-bin')
    assert calls[0][1]['env']['SUDO_ASKPASS'] == '/test/helper'
