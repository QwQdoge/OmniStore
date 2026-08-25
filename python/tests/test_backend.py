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


@pytest.mark.asyncio
async def test_scoop_source_search_uses_get_installed_ids_without_list_installed():
    import contextlib
    from unittest.mock import AsyncMock
    from core.sources.external import ScoopSource

    source = ScoopSource()
    source.enabled = True

    @contextlib.asynccontextmanager
    async def mock_subproc(*args, **kwargs):
        mock_p = AsyncMock()
        mock_p.communicate.return_value = (b"git 2.30.0 [main]\ncurl 7.80.0 [main]\n", b"")
        yield mock_p

    with patch.object(source, "_get_installed_ids", new_callable=AsyncMock) as mock_get_ids, \
         patch.object(source, "list_installed") as mock_list_installed, \
         patch.object(source, "get_size") as mock_get_size, \
         patch("core.sources.external.safe_subprocess", side_effect=mock_subproc):

        mock_get_ids.return_value = {"git"}

        results = await source.search("git")

        mock_get_ids.assert_called_once()
        mock_list_installed.assert_not_called()
        mock_get_size.assert_not_called()

        assert len(results) == 2
        assert results[0]["name"] == "git"
        assert results[0]["installed"] is True
        assert results[1]["name"] == "curl"
        assert results[1]["installed"] is False


@pytest.mark.asyncio
async def test_brew_source_search_uses_get_installed_ids_without_list_installed():
    import contextlib
    from unittest.mock import AsyncMock
    from core.sources.external import BrewSource

    source = BrewSource()
    source.enabled = True

    @contextlib.asynccontextmanager
    async def mock_subproc(*args, **kwargs):
        mock_p = AsyncMock()
        mock_p.communicate.return_value = (b"wget\ncurl\n", b"")
        yield mock_p

    with patch.object(source, "_get_installed_ids", new_callable=AsyncMock) as mock_get_ids, \
         patch.object(source, "list_installed") as mock_list_installed, \
         patch.object(source, "get_size") as mock_get_size, \
         patch("core.sources.external.safe_subprocess", side_effect=mock_subproc):

        mock_get_ids.return_value = {"wget"}

        results = await source.search("wget")

        mock_get_ids.assert_called_once()
        mock_list_installed.assert_not_called()
        mock_get_size.assert_not_called()

        assert len(results) == 2
        assert results[0]["name"] == "wget"
        assert results[0]["installed"] is True
        assert results[1]["name"] == "curl"
        assert results[1]["installed"] is False
