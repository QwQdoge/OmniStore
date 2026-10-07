import pytest
from core.habit_tracker import HabitTracker

def test_get_recommendation_tags(tmp_path, monkeypatch):
    monkeypatch.delenv("XDG_CONFIG_HOME", raising=False)
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
    monkeypatch.delenv("XDG_CONFIG_HOME", raising=False)
    monkeypatch.setattr("pathlib.Path.home", lambda: tmp_path)
    tracker = HabitTracker()
    tracker.habits = {
        "search_history": {},
        "install_history": {},
        "source_preference": {}
    }
    tags = tracker.get_recommendation_tags()
    assert tags == []


def test_habit_tracker_honors_xdg_config_home(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path / "xdg-config"))
    tracker = HabitTracker()
    assert tracker.data_dir == tmp_path / "xdg-config" / "omnistore"


def test_corrupt_habit_file_falls_back_without_overwriting_it(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    data_dir = tmp_path / "omnistore"
    data_dir.mkdir()
    data_path = data_dir / "user_habits.json"
    corrupt = '{"search_history": broken}'
    data_path.write_text(corrupt, encoding="utf-8")
    tracker = HabitTracker()
    assert tracker.habits["search_history"] == {}
    assert tracker.habits["install_history"] == {}
    assert tracker.get_recommendation_tags() == []
    assert data_path.read_text(encoding="utf-8") == corrupt


@pytest.mark.parametrize("error", [PermissionError("unreadable"), OSError("read failure")])
def test_unreadable_habits_fall_back_without_rewriting_file(tmp_path, monkeypatch, error):
    from unittest.mock import patch
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    data_dir = tmp_path / "omnistore"
    data_dir.mkdir()
    data_path = data_dir / "user_habits.json"
    original = '{"search_history":{"private term":1}}'
    data_path.write_text(original, encoding="utf-8")
    with patch("builtins.open", side_effect=error):
        tracker = HabitTracker()
    assert tracker.habits["search_history"] == {}
    assert tracker.get_recommendation_tags() == []
    assert data_path.read_text(encoding="utf-8") == original


def test_recommendation_tags_deduplicate_search_and_install_history(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    tracker = HabitTracker()
    tracker.habits = {
        "search_history": {"editor": 5, "browser": 2},
        "install_history": {"editor": {}, "browser": {}},
        "source_preference": {},
    }
    tags = tracker.get_recommendation_tags()
    assert len(tags) == 2
    assert set(tags) == {"editor", "browser"}
