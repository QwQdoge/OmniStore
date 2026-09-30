import asyncio
import pytest
from unittest.mock import MagicMock, AsyncMock
from core.search.manager import SearchManager

class DummyConfigManager:
    def __init__(self):
        self.data = {
            "search.max_results": 50,
            "priority": {"pacman": 50, "flatpak": 60},
        }
    def get(self, key, default=None):
        return self.data.get(key, default)

class FaultySource:
    def __init__(self, name="Faulty", enabled=True):
        self.name = name
        self.enabled = enabled
        self.weight = 1.0

    async def search(self, query, **kwargs):
        raise RuntimeError("Simulated source catastrophic failure")

class HangingSource:
    def __init__(self, name="Hanging", enabled=True):
        self.name = name
        self.enabled = enabled
        self.weight = 1.0

    async def search(self, query, **kwargs):
        await asyncio.sleep(20) # Simulate hanging search
        return []

class SuccessfulSource:
    def __init__(self, name="Flatpak", enabled=True):
        self.name = name
        self.enabled = enabled
        self.weight = 1.0

    async def search(self, query, **kwargs):
        return [
            {
                "name": "Firefox",
                "source": "Flatpak",
                "description": "Fast, private web browser",
                "id": "org.mozilla.firefox",
                "installed": False,
            }
        ]

@pytest.mark.asyncio
async def test_search_manager_input_sanitization():
    cm = DummyConfigManager()
    session = MagicMock()
    sm = SearchManager(config_manager=cm, session=session)

    # 1. Null / Non-string query
    assert await sm.search_all(None) == []
    assert await sm.search_all(123) == []

    # 2. Short query (<2 chars)
    assert await sm.search_all("a") == []
    assert await sm.search_all("   a   ") == []

    # 3. Oversized query (>500 chars) should not crash
    huge_query = "x" * 1000
    res = await sm.search_all(huge_query)
    assert isinstance(res, list)

    # 4. Command injection attempt should fail security validation safely
    res_sec = await sm.search_all("firefox; rm -rf /")
    assert res_sec == []

@pytest.mark.asyncio
async def test_search_manager_fault_isolation():
    cm = DummyConfigManager()
    session = MagicMock()
    sm = SearchManager(config_manager=cm, session=session)

    # Inject faulty, hanging, and successful sources
    good = SuccessfulSource()
    faulty = FaultySource()
    hanging = HangingSource()

    sm.sources = {
        "flatpak": good,
        "faulty": faulty,
        "hanging": hanging,
    }

    # Search should isolate failures and return good results without raising
    results = await sm.search_all("firefox")
    assert len(results) == 1
    assert results[0]["name"] == "Firefox"

@pytest.mark.asyncio
async def test_search_manager_norm_cache_bounds():
    cm = DummyConfigManager()
    session = MagicMock()
    sm = SearchManager(config_manager=cm, session=session)

    # Populate cache up to max bound
    for i in range(2500):
        sm._normalize_app_name(f"App-{i}")

    # Cache should have cleared when reaching bound and stayed within limits
    assert len(sm._norm_cache) <= 2000

@pytest.mark.asyncio
async def test_search_manager_concurrency_locking():
    cm = DummyConfigManager()
    session = MagicMock()
    sm = SearchManager(config_manager=cm, session=session)

    sm.sources = {"flatpak": SuccessfulSource()}

    # Run 5 search queries concurrently
    tasks = [sm.search_all(f"query_{i}") for i in range(5)]
    results = await asyncio.gather(*tasks)

    assert len(results) == 5
    for res in results:
        assert isinstance(res, list)
