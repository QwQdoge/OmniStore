from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock
import pytest
from core.platform_profile import SystemProfile
from core.search.manager import SearchManager


def manager_for(sources, disabled=None):
    manager = SearchManager.__new__(SearchManager)
    manager.sources = sources
    manager.cm = SimpleNamespace(get=lambda key, default=None: False if key == disabled else default)
    manager.cache = None
    manager.habit_tracker = Mock()
    manager.smart_scoring = Mock()
    manager.recommender = SimpleNamespace(get_recommendations=AsyncMock(return_value=[]))
    manager._norm_cache = {}
    return manager


@pytest.mark.asyncio
@pytest.mark.parametrize('native', ['apt', 'dnf', 'zypper', 'apk', 'pacman', 'brew'])
@pytest.mark.parametrize('separator', [' ', ':'])
async def test_native_source_filter_uses_detected_manager(monkeypatch, native, separator):
    monkeypatch.setattr('core.search.manager.detect_system_profile', lambda: SystemProfile(platform='linux', native_manager=native))
    selected = SimpleNamespace(name=native, enabled=True, search=AsyncMock(return_value=[]))
    unrelated = SimpleNamespace(name='github', enabled=True, search=AsyncMock(return_value=[]))
    manager = manager_for({native: selected, 'github': unrelated})
    assert await manager.search_all('source:native' + separator + 'editor') == []
    selected.search.assert_awaited_once()
    assert selected.search.await_args.args == ('editor',)
    unrelated.search.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize('query', ['source:missing editor', 'source:missing:editor', 'source:'])
async def test_unknown_explicit_source_does_not_search_other_sources(query):
    source = SimpleNamespace(name='github', enabled=True, search=AsyncMock(return_value=[]))
    manager = manager_for({'github': source})
    assert await manager.search_all(query) == []
    source.search.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize('query', ['source:apt', 'source:apt editor'])
async def test_disabled_explicit_source_does_not_search_or_recommend(query):
    source = SimpleNamespace(name='apt', enabled=True, search=AsyncMock(return_value=[]), get_recommendations=AsyncMock(return_value=[]))
    manager = manager_for({'apt': source}, disabled='search.sources.apt')
    assert await manager.search_all(query) == []
    source.search.assert_not_awaited()
    source.get_recommendations.assert_not_awaited()
