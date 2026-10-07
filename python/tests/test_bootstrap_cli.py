from types import SimpleNamespace
from unittest.mock import AsyncMock
import json
import pytest
from core.cli_handler import handle_cli


@pytest.mark.asyncio
@pytest.mark.parametrize('success', [True, False])
async def test_cli_bootstrap_reports_actual_result(capsys, success):
    backend = SimpleNamespace(env=SimpleNamespace(bootstrap=AsyncMock(return_value=success)),
                              _flutter_callback=AsyncMock())
    await handle_cli(backend, SimpleNamespace(bootstrap=True, json=True))
    assert json.loads(capsys.readouterr().out)['status'] == ('success' if success else 'error')


@pytest.mark.asyncio
async def test_explicit_aur_request_is_separate_from_standard_bootstrap(capsys):
    ordinary = AsyncMock()
    community = AsyncMock(return_value=False)
    backend = SimpleNamespace(env=SimpleNamespace(bootstrap=ordinary, bootstrap_aur=community),
                              _flutter_callback=AsyncMock())
    await handle_cli(backend, SimpleNamespace(bootstrap_aur=True, json=True))
    ordinary.assert_not_called()
    community.assert_awaited_once()
    assert json.loads(capsys.readouterr().out)['status'] == 'error'
