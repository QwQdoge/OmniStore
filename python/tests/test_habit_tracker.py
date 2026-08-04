import pytest
from pathlib import Path
from core.habit_tracker import HabitTracker

def test_habit_tracker_empty(tmp_path, monkeypatch):
    monkeypatch.setattr(Path, "home", lambda: tmp_path)
    tracker = HabitTracker()
    assert tracker.get_recommendation_tags() == []

def test_habit_tracker_get_recommendation_tags(tmp_path, monkeypatch):
    monkeypatch.setattr(Path, "home", lambda: tmp_path)
    tracker = HabitTracker()

    # Pre-populate dictionary
    tracker.habits = {
        "search_history": {
            "browser": 10,
            "game": 5,
            "office": 2,
            "editor": 15,
            "music": 1,
            "video": 8,
            "chat": 3
        },
        "install_history": {
            "org.mozilla.firefox": {"source": "Flatpak", "count": 2},
            "org.gimp.GIMP": {"source": "Flatpak", "count": 1},
            "com.valvesoftware.Steam": {"source": "Native", "count": 1},
            "org.videolan.VLC": {"source": "Flatpak", "count": 1},
            "com.visualstudio.code": {"source": "AUR", "count": 1},
            "org.telegram.desktop": {"source": "Flatpak", "count": 1}
        },
        "source_preference": { "Native": 0, "AUR": 0, "Flatpak": 0, "AppImage": 0 }
    }

    tags = tracker.get_recommendation_tags()

    expected_tags = {
        "editor", "browser", "video", "game", "chat",
        "org.mozilla.firefox", "org.gimp.GIMP", "com.valvesoftware.Steam",
        "org.videolan.VLC", "com.visualstudio.code"
    }

    assert set(tags) == expected_tags
