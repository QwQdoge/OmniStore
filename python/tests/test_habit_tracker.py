import json
from unittest.mock import patch

import pytest

from core.habit_tracker import HabitTracker

def test_load_habits_invalid_json(tmp_path):
    with patch("core.habit_tracker.Path.home", return_value=tmp_path):
        data_dir = tmp_path / ".config" / "omnistore"
        data_dir.mkdir(parents=True, exist_ok=True)
        data_path = data_dir / "user_habits.json"

        # Write invalid JSON
        data_path.write_text("{invalid_json: true", encoding="utf-8")

        tracker = HabitTracker()

        assert tracker.habits == {
            "search_history": {},
            "install_history": {},
            "source_preference": { "Native": 0, "AUR": 0, "Flatpak": 0, "AppImage": 0 }
        }

def test_load_habits_open_exception(tmp_path):
    with patch("core.habit_tracker.Path.home", return_value=tmp_path):
        data_dir = tmp_path / ".config" / "omnistore"
        data_dir.mkdir(parents=True, exist_ok=True)
        data_path = data_dir / "user_habits.json"

        # Write valid JSON
        data_path.write_text('{"search_history": {"foo": 1}}', encoding="utf-8")

        # Mock open to trigger the generic Exception block
        with patch("builtins.open", side_effect=IOError("Simulated read error")):
            tracker = HabitTracker()

            assert tracker.habits == {
                "search_history": {},
                "install_history": {},
                "source_preference": { "Native": 0, "AUR": 0, "Flatpak": 0, "AppImage": 0 }
            }
