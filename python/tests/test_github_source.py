import aiohttp
import pytest
from unittest.mock import patch, MagicMock, AsyncMock
from core.sources.github.github import GitHubSource


@pytest.fixture
def github_source():
    config_manager_mock = MagicMock()
    config_manager_mock.get.return_value = None
    session_mock = MagicMock()
    return GitHubSource(session_mock, config_manager_mock)


def _test_asset():
    asset = MagicMock()
    asset.download_url = "https://github.com/test/test/releases/download/v1/target_executable"
    asset.name = "target_executable"
    asset.type = "exe"
    return asset


@pytest.mark.asyncio
async def test_github_atomic_download_success(github_source, tmp_path):
    dl_resp = AsyncMock()
    dl_resp.status = 200
    dl_resp.headers = {'content-length': '12'}

    async def mock_iter_chunked(size):
        yield b"chunk1"
        yield b"chunk2"

    dl_resp.content.iter_chunked = mock_iter_chunked
    github_source.session.get.return_value.__aenter__.return_value = dl_resp

    with patch(
        'core.sources.github.github.AssetMatcher.filter_assets_for_platform',
        return_value=[_test_asset()],
    ), patch.object(github_source, '_managed_base_dir', return_value=tmp_path):
        result = await github_source.install({"id": "test/repo"}, callback=MagicMock())

    destination = tmp_path / "test_repo" / "target_executable"
    assert result is True
    assert destination.read_bytes() == b"chunk1chunk2"
    assert not list((tmp_path / "test_repo").glob(".tmp_*"))


@pytest.mark.asyncio
async def test_github_atomic_download_failure_cleans_temp(github_source, tmp_path):
    dl_resp = AsyncMock()
    dl_resp.status = 200
    dl_resp.headers = {'content-length': '12'}

    async def mock_iter_chunked(size):
        yield b"chunk1"
        raise aiohttp.ClientPayloadError("Network failure")

    dl_resp.content.iter_chunked = mock_iter_chunked
    github_source.session.get.return_value.__aenter__.return_value = dl_resp

    with patch(
        'core.sources.github.github.AssetMatcher.filter_assets_for_platform',
        return_value=[_test_asset()],
    ), patch.object(github_source, '_managed_base_dir', return_value=tmp_path):
        result = await github_source.install({"id": "test/repo"}, callback=MagicMock())

    destination = tmp_path / "test_repo" / "target_executable"
    assert result is False
    assert not destination.exists()
    assert not list((tmp_path / "test_repo").glob(".tmp_*"))


@pytest.mark.asyncio
async def test_github_atomic_download_failure_preserves_existing_file(github_source, tmp_path):
    install_dir = tmp_path / "test_repo"
    install_dir.mkdir()
    destination = install_dir / "target_executable"
    destination.write_bytes(b"old-version")

    dl_resp = AsyncMock()
    dl_resp.status = 200
    dl_resp.headers = {'content-length': '12'}

    async def mock_iter_chunked(size):
        yield b"chunk1"
        raise aiohttp.ClientPayloadError("Network failure")

    dl_resp.content.iter_chunked = mock_iter_chunked
    github_source.session.get.return_value.__aenter__.return_value = dl_resp

    with patch(
        'core.sources.github.github.AssetMatcher.filter_assets_for_platform',
        return_value=[_test_asset()],
    ), patch.object(github_source, '_managed_base_dir', return_value=tmp_path):
        result = await github_source.install({"id": "test/repo"}, callback=MagicMock())

    assert result is False
    assert destination.read_bytes() == b"old-version"
    assert not list(install_dir.glob(".tmp_*"))


@pytest.mark.asyncio
async def test_github_atomic_download_propagates_programming_errors(github_source, tmp_path):
    dl_resp = AsyncMock()
    dl_resp.status = 200
    dl_resp.headers = {'content-length': '12'}

    async def mock_iter_chunked(size):
        raise TypeError("programming error")
        yield b"unreachable"

    dl_resp.content.iter_chunked = mock_iter_chunked
    github_source.session.get.return_value.__aenter__.return_value = dl_resp

    with patch(
        'core.sources.github.github.AssetMatcher.filter_assets_for_platform',
        return_value=[_test_asset()],
    ), patch.object(github_source, '_managed_base_dir', return_value=tmp_path):
        with pytest.raises(TypeError, match="programming error"):
            await github_source.install({"id": "test/repo"}, callback=MagicMock())

    assert not list((tmp_path / "test_repo").glob(".tmp_*"))
