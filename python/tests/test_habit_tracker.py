import pytest
from core.habit_tracker import HabitTracker

def test_get_recommendation_tags_sorting_and_limiting(monkeypatch, tmp_path):
    monkeypatch.setattr("pathlib.Path.home", lambda: tmp_path)
    tracker = HabitTracker()
    tracker.habits = {
        "search_history": {
            "lowest": 1,
            "highest": 100,
            "medium1": 50,
            "medium2": 40,
            "medium3": 30,
            "medium4": 20
        },
        "install_history": {
            "app1": {},
            "app2": {},
            "app3": {},
            "app4": {},
            "app5": {},
            "app6": {}
        }
    }
    tags = tracker.get_recommendation_tags()

    # Top 5 searches should be included, 'lowest' should be excluded
    assert "highest" in tags
    assert "medium1" in tags
    assert "medium2" in tags
    assert "medium3" in tags
    assert "medium4" in tags
    assert "lowest" not in tags

    # First 5 installs should be included, 'app6' should be excluded
    assert "app1" in tags
    assert "app2" in tags
    assert "app3" in tags
    assert "app4" in tags
    assert "app5" in tags
    assert "app6" not in tags

    assert len(tags) == 10

def test_get_recommendation_tags_deduplication(monkeypatch, tmp_path):
    monkeypatch.setattr("pathlib.Path.home", lambda: tmp_path)
    tracker = HabitTracker()
    tracker.habits = {
        "search_history": {
            "app1": 10,
            "app2": 5
        },
        "install_history": {
            "app1": {},
            "app2": {}
        }
    }
    tags = tracker.get_recommendation_tags()

    assert len(tags) == 2
    assert set(tags) == {"app1", "app2"}

def test_get_recommendation_tags_empty(monkeypatch, tmp_path):
    monkeypatch.setattr("pathlib.Path.home", lambda: tmp_path)
    tracker = HabitTracker()
    tracker.habits = {
        "search_history": {},
        "install_history": {}
    }
    tags = tracker.get_recommendation_tags()
    assert tags == []
