import gzip
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from core.category_catalog import native_category_apps
from tests.test_search_source_profile import manager_for


def test_native_categories_use_package_ids_and_deduplicate(tmp_path):
    data = b'''<components><component type="desktop-application"><id>org.example.Game</id>
    <name>Example Game</name><pkgname>example-game-bin</pkgname><summary>A game</summary>
    <categories><category>Game</category></categories></component></components>'''
    (tmp_path / "extra.xml.gz").write_bytes(gzip.compress(data))
    (tmp_path / "duplicate.xml").write_bytes(data)
    (tmp_path / "broken.xml").write_text("<components>broken")
    rows = native_category_apps("Game", tmp_path)
    assert len(rows) == 1
    assert rows[0]["id"] == "example-game-bin"
    assert rows[0]["variants"][0]["id"] == "example-game-bin"
    assert rows[0]["source"] == "Pacman"
    assert native_category_apps("Office", tmp_path) == []


@pytest.mark.asyncio
async def test_category_uses_enabled_native_catalog_without_keyword_search():
    native = SimpleNamespace(name="Pacman", enabled=True,
                             get_category_apps=AsyncMock(return_value=[{"id": "native-game"}]),
                             search=AsyncMock())
    disabled = SimpleNamespace(name="Flatpak", enabled=False, search=AsyncMock())
    manager = manager_for({"pacman": native, "flatpak": disabled})
    manager.recommender.get_category_apps = AsyncMock()
    assert await manager.search_all("category:games") == [{"id": "native-game"}]
    native.get_category_apps.assert_awaited_once_with("Game")
    native.search.assert_not_awaited()
    manager.recommender.get_category_apps.assert_not_awaited()


@pytest.mark.asyncio
async def test_category_failure_does_not_send_category_as_search_text():
    flatpak = SimpleNamespace(name="Flatpak", enabled=True, search=AsyncMock())
    unrelated = SimpleNamespace(name="AUR", enabled=True, search=AsyncMock())
    manager = manager_for({"flatpak": flatpak, "aur": unrelated})
    manager.recommender.get_category_apps = AsyncMock(side_effect=RuntimeError("offline"))
    assert await manager.search_all("category:Game") == []
    flatpak.search.assert_not_awaited()
    unrelated.search.assert_not_awaited()
