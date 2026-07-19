import json
import time

import pytest

from core.recommendation_manager import RecommendationManager


class EmptySession:
    pass


@pytest.mark.asyncio
async def test_featured_is_stable_offline_and_ordered(tmp_path):
    manager = RecommendationManager(EmptySession())
    manager.cache_dir = tmp_path
    manager.cache_path = tmp_path / "recommendations.json"
    manager.metadata_cache_path = tmp_path / "metadata.json"
    manager._fetch_collection = lambda _url: (_ for _ in ()).throw(AssertionError("network must not be used"))

    result = manager._compose_recommendations(None)

    assert [app["id"] for app in result["featured"]] == [
        "org.mozilla.firefox", "org.libreoffice.LibreOffice", "org.videolan.VLC",
        "org.gimp.GIMP", "com.visualstudio.code",
    ]
    assert all(app["primary_source"] == "Flatpak" for app in result["featured"])


@pytest.mark.asyncio
async def test_expired_dynamic_cache_is_retained_when_refresh_fails(tmp_path, monkeypatch):
    manager = RecommendationManager(EmptySession())
    manager.cache_dir = tmp_path
    manager.cache_path = tmp_path / "recommendations.json"
    dynamic = {"trending": [{"id": "old", "name": "Old"}], "for_you": []}
    manager.cache_path.write_text(json.dumps({"version": manager.cache_version, "timestamp": time.time() - 7200, "recommendations": dynamic}), encoding="utf-8")

    async def failed_refresh(_sources, stale):
        return stale
    monkeypatch.setattr(manager, "_fetch_dynamic_recommendations", failed_refresh)

    result = await manager.get_recommendations(force_refresh=True)
    assert result["trending"] == dynamic["trending"]
    assert len(result["featured"]) == 5


@pytest.mark.asyncio
async def test_category_apps_cached(tmp_path):
    import asyncio
    manager = RecommendationManager(EmptySession())
    manager.cache_dir = tmp_path
    manager.metadata_cache_path = tmp_path / "metadata.json"
    manager._metadata_cache = manager._load_metadata_cache()

    fetch_count = 0
    async def mock_fetch_collection(url):
        nonlocal fetch_count
        fetch_count += 1
        return [{"id": "app.id", "name": "App Name", "source": "Flatpak"}]

    async def mock_enrich_item(item):
        pass

    manager._fetch_collection = mock_fetch_collection
    manager._enrich_item = mock_enrich_item

    # First fetch (should hit the "network"/mock_fetch_collection)
    apps_1 = await manager.get_category_apps("Development")
    assert fetch_count == 1
    assert len(apps_1) == 1
    assert apps_1[0]["id"] == "app.id"

    # Second fetch (should hit cache)
    apps_2 = await manager.get_category_apps("Development")
    assert fetch_count == 1
    assert len(apps_2) == 1
    assert apps_2[0]["id"] == "app.id"


@pytest.mark.asyncio
async def test_category_apps_deduplicated(tmp_path):
    import asyncio
    manager = RecommendationManager(EmptySession())
    manager.cache_dir = tmp_path
    manager.metadata_cache_path = tmp_path / "metadata.json"
    manager._metadata_cache = manager._load_metadata_cache()

    fetch_count = 0
    async def mock_fetch_collection(url):
        nonlocal fetch_count
        fetch_count += 1
        # Add a small delay to simulate network latency and test concurrency
        await asyncio.sleep(0.05)
        return [{"id": "app.id", "name": "App Name", "source": "Flatpak"}]

    async def mock_enrich_item(item):
        pass

    manager._fetch_collection = mock_fetch_collection
    manager._enrich_item = mock_enrich_item

    # Launch two concurrent requests
    res_1, res_2 = await asyncio.gather(
        manager.get_category_apps("Game"),
        manager.get_category_apps("Game")
    )

    assert fetch_count == 1
    assert len(res_1) == 1
    assert len(res_2) == 1
    assert res_1[0]["id"] == "app.id"
    assert res_2[0]["id"] == "app.id"
