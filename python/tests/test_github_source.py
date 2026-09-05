import pytest
import asyncio
from unittest.mock import patch, MagicMock, AsyncMock
from pathlib import Path
from core.sources.github.github import GitHubSource

@pytest.fixture
def github_source():
    config_manager_mock = MagicMock()
    config_manager_mock.get.return_value = None
    session_mock = MagicMock()
    return GitHubSource(session_mock, config_manager_mock)

@pytest.mark.asyncio
async def test_github_atomic_download_success(github_source, tmp_path):
    dest_path = tmp_path / "target_executable"

    # Mock dl_resp
    dl_resp = AsyncMock()
    dl_resp.status = 200
    dl_resp.headers = {'content-length': '12'}

    async def mock_iter_chunked(size):
        yield b"chunk1"
        yield b"chunk2"

    dl_resp.content.iter_chunked = mock_iter_chunked

    github_source.session.get.return_value.__aenter__.return_value = dl_resp

    # Mock AssetMatcher to return our test asset
    test_asset = MagicMock()
    test_asset.download_url = "https://github.com/test/test/releases/download/v1/target_executable"
    test_asset.name = "target_executable"
    test_asset.type = "exe"

    with patch('core.sources.github.github.AssetMatcher.filter_assets_for_platform', return_value=[test_asset]), \
         patch.object(github_source, '_managed_base_dir', return_value=tmp_path):

        result = await github_source.install({"id": "test/repo"}, callback=MagicMock())

        assert result is True
        # Original file should exist
        assert (tmp_path / "test_repo" / "target_executable").exists()
        with open(tmp_path / "test_repo" / "target_executable", "rb") as f:
            assert f.read() == b"chunk1chunk2"

        # Temp file should be deleted
        temp_files = list(tmp_path.glob("test_repo/.tmp_*"))
        assert len(temp_files) == 0

@pytest.mark.asyncio
async def test_github_atomic_download_failure(github_source, tmp_path):
    dest_path = tmp_path / "target_executable"

    # Mock dl_resp throwing an exception midway
    dl_resp = AsyncMock()
    dl_resp.status = 200
    dl_resp.headers = {'content-length': '12'}

    async def mock_iter_chunked(size):
        yield b"chunk1"
        raise Exception("Network failure")

    dl_resp.content.iter_chunked = mock_iter_chunked

    github_source.session.get.return_value.__aenter__.return_value = dl_resp

    # Mock AssetMatcher to return our test asset
    test_asset = MagicMock()
    test_asset.download_url = "https://github.com/test/test/releases/download/v1/target_executable"
    test_asset.name = "target_executable"
    test_asset.type = "exe"

    with patch('core.sources.github.github.AssetMatcher.filter_assets_for_platform', return_value=[test_asset]), \
         patch.object(github_source, '_managed_base_dir', return_value=tmp_path):

        result = await github_source.install({"id": "test/repo"}, callback=MagicMock())

        assert result is False
        # Destination file should NOT exist because it failed
        assert not (tmp_path / "test_repo" / "target_executable").exists()

        # Temp file should be cleaned up
        temp_files = list(tmp_path.glob("test_repo/.tmp_*"))
        assert len(temp_files) == 0
