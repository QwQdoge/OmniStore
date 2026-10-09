import pytest
import os
import json
import shutil
from unittest.mock import patch, MagicMock

from core.backend import OmnistoreBackend


@pytest.mark.asyncio
async def test_details_use_selected_native_provider_without_flathub(mock_backend):
    from types import SimpleNamespace
    from unittest.mock import AsyncMock
    provider = SimpleNamespace(name="Pacman", enabled=True,
        get_details=AsyncMock(return_value={"id": "editor-bin", "name": "Editor", "installed": True}))
    mock_backend.manager = SimpleNamespace(sources={"pacman": provider})
    recommender = SimpleNamespace(get_details=AsyncMock())
    mock_backend.recommender = recommender
    mock_backend.initialize = AsyncMock()
    mock_backend.cleanup = AsyncMock()
    result = await mock_backend.run_app_details("editor-bin", source="Pacman")
    assert result.id == "editor-bin"
    assert result.installed
    assert result.primary_source == "Pacman"
    assert result.variants[0].id == "editor-bin"
    recommender.get_details.assert_not_awaited()


@pytest.mark.asyncio
async def test_native_launch_alias_routes_to_platform_provider(mock_backend):
    from types import SimpleNamespace
    from unittest.mock import AsyncMock
    from core.platform_profile import SystemProfile
    provider = SimpleNamespace(name="Pacman", enabled=True, launch=AsyncMock(return_value=True))
    mock_backend.manager = SimpleNamespace(sources={"pacman": provider})
    mock_backend.initialize = AsyncMock()
    mock_backend.cleanup = AsyncMock()
    with patch("core.platform_profile.detect_system_profile", return_value=SystemProfile(platform="linux", native_manager="pacman")):
        assert await mock_backend.run_launch("editor-bin", "Native")
    provider.launch.assert_awaited_once_with({"id": "editor-bin", "name": "editor-bin"})

@pytest.fixture
def mock_backend():
    with patch("core.backend.ConfigManager") as MockConfigManager, \
         patch("core.backend.CacheManager"), \
         patch("core.backend.EnvManager"), \
         patch("core.backend.HabitTracker"):
        mock_config = MockConfigManager.return_value
        mock_config.get.return_value = None
        # Provide any necessary mock setups for OmnistoreBackend
        backend = OmnistoreBackend(json_mode=False)
        return backend

@pytest.mark.asyncio
async def test_run_get_storage_info(mock_backend):
    # Mock shutil.disk_usage
    mock_usage = (1000, 400, 600)  # total, used, free

    with patch("shutil.disk_usage", return_value=mock_usage) as mock_disk_usage:
        with patch("os.path.expanduser", return_value="/home/user") as mock_expanduser:
            # Call the method
            result = await mock_backend.run_get_storage_info(json_mode=False)

            # Assertions
            mock_expanduser.assert_any_call("~")
            mock_disk_usage.assert_called_once_with("/home/user")

            expected_result = {
                "disk_total": 1000,
                "disk_used": 400,
                "disk_free": 600
            }
            assert result == expected_result

@pytest.mark.asyncio
async def test_run_get_storage_info_json_mode(mock_backend):
    # Mock shutil.disk_usage
    mock_usage = (2000, 1500, 500)  # total, used, free

    with patch("shutil.disk_usage", return_value=mock_usage):
        with patch("os.path.expanduser", return_value="/home/user"):
            with patch("sys.stdout") as mock_stdout:
                # Call the method with json_mode=True
                result = await mock_backend.run_get_storage_info(json_mode=True)

                # Check that the dict was returned
                expected_result = {
                    "disk_total": 2000,
                    "disk_used": 1500,
                    "disk_free": 500
                }
                assert result == expected_result

                # Check sys.stdout.write was called with json string
                expected_json_str = json.dumps(expected_result) + "\n"
                mock_stdout.write.assert_called_with(expected_json_str)
                mock_stdout.flush.assert_called_once()


@pytest.mark.asyncio
@pytest.mark.parametrize("json_mode", [False, True])
async def test_ai_health_response_and_owned_cleanup(mock_backend, json_mode):
    from unittest.mock import AsyncMock
    ai = MagicMock()
    ai.generate_health_report = AsyncMock(return_value="Healthy fixture")
    ai.close = AsyncMock()
    mock_backend._ai = ai
    mock_backend.env.check_env = AsyncMock(return_value={"status": "ok"})
    mock_backend.initialize = AsyncMock()
    with patch.object(mock_backend, "_output_command_response") as output, patch("core.backend.hijacked_print") as plain:
        result = await mock_backend.run_ai_health(json_mode=json_mode)
    assert result == "Healthy fixture"
    ai.generate_health_report.assert_awaited_once_with({"status": "ok"})
    ai.close.assert_awaited_once()
    assert mock_backend._active_commands == {}
    assert mock_backend._ref_count == 0
    if json_mode:
        response = output.call_args.args[0]
        assert response.status == "success"
        assert response.context == "ai_health"
        assert response.response == "Healthy fixture"
        plain.assert_not_called()
    else:
        plain.assert_called_once_with("Healthy fixture")
        output.assert_not_called()


@pytest.mark.asyncio
async def test_ai_health_failure_still_closes_owned_client(mock_backend):
    from unittest.mock import AsyncMock
    ai = MagicMock()
    ai.generate_health_report = AsyncMock(side_effect=RuntimeError("fixture failure"))
    ai.close = AsyncMock()
    mock_backend._ai = ai
    mock_backend.env.check_env = AsyncMock(return_value={"status": "ok"})
    mock_backend.initialize = AsyncMock()
    mock_backend._handle_error = AsyncMock()
    assert await mock_backend.run_ai_health(json_mode=False) is False
    ai.close.assert_awaited_once()
    assert mock_backend._active_commands == {}
    assert mock_backend._ref_count == 0
