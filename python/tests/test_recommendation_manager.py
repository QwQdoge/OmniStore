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
