import asyncio
from unittest.mock import AsyncMock, MagicMock, patch, PropertyMock
import pytest

from core.backend import OmnistoreBackend, CommandResponse
import aiohttp

@pytest.fixture
def mock_dependencies():
    with patch("core.backend.ConfigManager") as mock_config_manager, \
         patch("core.backend.CacheManager") as mock_cache_manager, \
         patch("core.backend.EnvManager") as mock_env_manager, \
         patch("core.backend.HabitTracker") as mock_habit_tracker, \
         patch("core.backend.ResourceCoordinator") as mock_resource_coordinator:

        mock_env_instance = mock_env_manager.return_value
        mock_env_instance.check_env = AsyncMock(return_value={"status": "ok", "sys": "linux"})

        mock_resource_instance = mock_resource_coordinator.return_value
        mock_resource_instance.cleanup = AsyncMock()

        yield {
            "config": mock_config_manager,
            "cache": mock_cache_manager,
            "env": mock_env_manager,
            "env_instance": mock_env_instance,
            "habit": mock_habit_tracker,
            "resources": mock_resource_coordinator,
            "resource_instance": mock_resource_instance
        }

@pytest.fixture
def mock_ai():
    ai_mock = MagicMock()
    ai_mock.generate_health_report = AsyncMock(return_value="System is healthy.")
    return ai_mock

@pytest.fixture
async def backend(mock_dependencies, mock_ai):
    b = OmnistoreBackend()
    b._ai = mock_ai

    # We must patch _handle_error to avoid "Double fault" as we mocked everything else
    b._handle_error = AsyncMock()

    yield b

    # We need to manually close the session if the backend initialized it
    if b.session and not b.session.closed:
        await b.session.close()

@pytest.mark.asyncio
async def test_run_ai_health_plain_mode(backend, mock_dependencies, mock_ai):
    with patch.object(OmnistoreBackend, 'ai', new_callable=PropertyMock) as mock_ai_prop, \
         patch("core.backend.hijacked_print") as mock_print, \
         patch("aiohttp.ClientSession"):

        mock_ai_prop.return_value = mock_ai

        result = await backend.run_ai_health(json_mode=False)

        mock_dependencies["env_instance"].check_env.assert_awaited_once()
        mock_ai.generate_health_report.assert_awaited_once_with({"status": "ok", "sys": "linux"})
        mock_print.assert_called_once_with("System is healthy.")
        assert result == "System is healthy."

@pytest.mark.asyncio
async def test_run_ai_health_json_mode(backend, mock_dependencies, mock_ai):
    with patch.object(OmnistoreBackend, 'ai', new_callable=PropertyMock) as mock_ai_prop, \
         patch.object(backend, "_output_command_response") as mock_output, \
         patch("aiohttp.ClientSession"):

        mock_ai_prop.return_value = mock_ai

        result = await backend.run_ai_health(json_mode=True)

        mock_dependencies["env_instance"].check_env.assert_awaited_once()
        mock_ai.generate_health_report.assert_awaited_once_with({"status": "ok", "sys": "linux"})

        mock_output.assert_called_once()
        response = mock_output.call_args[0][0]
        assert response.status == "success"
        assert response.response == "System is healthy."
        assert response.context == "ai_health"

        assert result == "System is healthy."

@pytest.mark.asyncio
async def test_run_ai_health_error(backend, mock_dependencies, mock_ai):
    with patch.object(OmnistoreBackend, 'ai', new_callable=PropertyMock) as mock_ai_prop, \
         patch("aiohttp.ClientSession"):

        ai_error = Exception("AI error")
        mock_ai.generate_health_report = AsyncMock(side_effect=ai_error)
        mock_ai_prop.return_value = mock_ai

        result = await backend.run_ai_health(json_mode=False)

        backend._handle_error.assert_awaited_once_with("Command Error (run_ai_health)", ai_error, False)

        assert result is False
