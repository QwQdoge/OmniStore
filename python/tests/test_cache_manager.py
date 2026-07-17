import json
import time
from unittest.mock import mock_open, patch, MagicMock

import pytest

from core.cache_manager import CacheManager

@pytest.fixture
def cache_manager(tmp_path):
    with patch("core.cache_manager.Path.home", return_value=tmp_path):
        manager = CacheManager()
        yield manager

def test_get_installed_packages_no_cache(cache_manager):
    assert cache_manager.get_installed_packages() is None

def test_get_installed_packages_valid_cache(cache_manager):
    packages = [{"name": "test-pkg", "version": "1.0"}]
    data = {
        "version": cache_manager.INSTALLED_CACHE_VERSION,
        "timestamp": time.time() - 1000, # 1000 seconds ago, valid
        "packages": packages
    }

    tmp_path = cache_manager.installed_cache_path.with_suffix(".tmp")
    with open(tmp_path, "w") as f:
        json.dump(data, f)
    tmp_path.replace(cache_manager.installed_cache_path)

    assert cache_manager.get_installed_packages() == packages

def test_get_installed_packages_expired_cache(cache_manager):
    packages = [{"name": "test-pkg", "version": "1.0"}]
    data = {
        "version": cache_manager.INSTALLED_CACHE_VERSION,
        "timestamp": time.time() - 4000, # 4000 seconds ago, expired
        "packages": packages
    }

    tmp_path = cache_manager.installed_cache_path.with_suffix(".tmp")
    with open(tmp_path, "w") as f:
        json.dump(data, f)
    tmp_path.replace(cache_manager.installed_cache_path)

    assert cache_manager.get_installed_packages() is None

def test_get_installed_packages_invalid_json(cache_manager):
    tmp_path = cache_manager.installed_cache_path.with_suffix(".tmp")
    with open(tmp_path, "w") as f:
        f.write("invalid json")
    tmp_path.replace(cache_manager.installed_cache_path)

    assert cache_manager.get_installed_packages() is None

def test_save_installed_packages(cache_manager):
    packages = [{"name": "test-pkg", "version": "1.0"}]

    with patch("time.time", return_value=12345.0):
        cache_manager.save_installed_packages(packages)

    assert cache_manager.installed_cache_path.exists()
    with open(cache_manager.installed_cache_path, "r") as f:
        data = json.load(f)

    assert data["timestamp"] == 12345.0
    assert data["version"] == cache_manager.INSTALLED_CACHE_VERSION
    assert data["packages"] == packages

def test_get_installed_packages_legacy_cache_is_invalidated(cache_manager):
    data = {
        "timestamp": time.time(),
        "packages": [{"name": "old-source-only-cache"}],
    }

    with open(cache_manager.installed_cache_path, "w") as f:
        json.dump(data, f)

    assert cache_manager.get_installed_packages() is None

def test_save_installed_packages_error(cache_manager):
    packages = [{"name": "test-pkg", "version": "1.0"}]

    with patch("core.cache_manager.open", side_effect=IOError("test error")):
        with patch("builtins.print") as mock_print:
            cache_manager.save_installed_packages(packages)
            mock_print.assert_called_once_with("[Cache] Save Error: test error")

def test_invalidate_installed_cache(cache_manager):
    cache_manager.installed_cache_path.parent.mkdir(parents=True, exist_ok=True)
    cache_manager.installed_cache_path.touch()

    assert cache_manager.installed_cache_path.exists()

    cache_manager.invalidate_installed_cache()

    assert not cache_manager.installed_cache_path.exists()

def test_invalidate_installed_cache_not_exists(cache_manager):
    assert not cache_manager.installed_cache_path.exists()

    # Should not raise any error
    cache_manager.invalidate_installed_cache()
