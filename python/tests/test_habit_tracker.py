import pytest
from core.habit_tracker import HabitTracker

def test_get_recommendation_tags(tmp_path, monkeypatch):
    monkeypatch.setattr("pathlib.Path.home", lambda: tmp_path)
    tracker = HabitTracker()
    tracker.habits = {
        "search_history": {
            "browser": 10,
            "game": 5,
            "office": 1,
            "music": 15,
            "video": 8,
            "editor": 3
        },
        "install_history": {
            "firefox": {"source": "native", "count": 1},
            "vlc": {"source": "flatpak", "count": 1},
            "steam": {"source": "native", "count": 1},
            "discord": {"source": "flatpak", "count": 1},
            "gimp": {"source": "native", "count": 1},
            "code": {"source": "flatpak", "count": 1}
        },
        "source_preference": {}
    }
    tags = tracker.get_recommendation_tags()

    # Check that top 5 searches are included
    assert "music" in tags
    assert "browser" in tags
    assert "video" in tags
    assert "game" in tags
    assert "editor" in tags
    assert "office" not in tags  # 6th item should not be in top 5 searches

    # Check that top 5 installed packages are included
    assert "firefox" in tags
    assert "vlc" in tags
    assert "steam" in tags
    assert "discord" in tags
    assert "gimp" in tags
    assert "code" not in tags # 6th item should not be in top 5 installs

def test_get_recommendation_tags_empty(tmp_path, monkeypatch):
    monkeypatch.setattr("pathlib.Path.home", lambda: tmp_path)
    tracker = HabitTracker()
    tracker.habits = {
        "search_history": {},
        "install_history": {},
        "source_preference": {}
    }
    tags = tracker.get_recommendation_tags()
    assert tags == []
