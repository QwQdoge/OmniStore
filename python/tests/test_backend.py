import pytest
import os
import json
import shutil
from unittest.mock import patch, MagicMock

from core.backend import OmnistoreBackend

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
