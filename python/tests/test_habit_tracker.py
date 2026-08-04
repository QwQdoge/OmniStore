import pytest
from unittest.mock import patch
from core.habit_tracker import HabitTracker

def test_load_habits_fallback_invalid_json(tmp_path):
    tracker = HabitTracker()
    tracker.data_path = tmp_path / "user_habits.json"

    # Write invalid JSON
    tracker.data_path.write_text("{invalid_json: 123", encoding="utf-8")

    # Reload habits to trigger _load_habits()
    habits = tracker._load_habits()

    assert habits == {
        "search_history": {},
        "install_history": {},
        "source_preference": { "Native": 0, "AUR": 0, "Flatpak": 0, "AppImage": 0 }
    }

def test_load_habits_fallback_read_error(tmp_path):
    tracker = HabitTracker()
    tracker.data_path = tmp_path / "user_habits.json"
    tracker.data_path.write_text("{}", encoding="utf-8") # File must exist to pass first check

    # Mock open to raise an exception
    with patch("builtins.open", side_effect=PermissionError("Permission denied")):
        habits = tracker._load_habits()

    assert habits == {
        "search_history": {},
        "install_history": {},
        "source_preference": { "Native": 0, "AUR": 0, "Flatpak": 0, "AppImage": 0 }
    }
