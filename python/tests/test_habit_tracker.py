import json
import asyncio
from unittest.mock import patch, MagicMock
import pytest

from core.habit_tracker import HabitTracker

@pytest.fixture
def habit_tracker(tmp_path):
    with patch("core.habit_tracker.Path.home", return_value=tmp_path):
        tracker = HabitTracker()
        yield tracker

def test_initialization_no_file(habit_tracker):
    assert not habit_tracker.data_path.exists()
    assert habit_tracker.habits["search_history"] == {}
    assert habit_tracker.habits["install_history"] == {}
    assert habit_tracker.habits["source_preference"] == {"Native": 0, "AUR": 0, "Flatpak": 0, "AppImage": 0}

def test_initialization_existing_file(tmp_path):
    mock_home = tmp_path
    test_data = {
        "search_history": {"test": 2},
        "install_history": {"pkg": {"source": "AUR", "count": 1}},
        "source_preference": {"Native": 1, "AUR": 5, "Flatpak": 0, "AppImage": 0}
    }
    # create directory and file before tracker init
    data_dir = mock_home / ".config" / "omnistore"
    data_dir.mkdir(parents=True, exist_ok=True)
    with open(data_dir / "user_habits.json", "w") as f:
        json.dump(test_data, f)

    with patch("core.habit_tracker.Path.home", return_value=mock_home):
        tracker = HabitTracker()
        assert tracker.habits == test_data

def test_initialization_invalid_json(tmp_path):
    mock_home = tmp_path
    data_dir = mock_home / ".config" / "omnistore"
    data_dir.mkdir(parents=True, exist_ok=True)
    with open(data_dir / "user_habits.json", "w") as f:
        f.write("invalid json")

    with patch("core.habit_tracker.Path.home", return_value=mock_home):
        tracker = HabitTracker()
        assert tracker.habits["search_history"] == {}

def test_record_search(habit_tracker):
    # Test normal insertion
    habit_tracker.record_search("test query")
    assert habit_tracker.habits["search_history"]["test query"] == 1

    # Test increment
    habit_tracker.record_search("test query")
    assert habit_tracker.habits["search_history"]["test query"] == 2

    # Test strip and lowercase
    habit_tracker.record_search("  TEST query  ")
    assert habit_tracker.habits["search_history"]["test query"] == 3

    # Test short query is ignored
    habit_tracker.record_search("a")
    assert "a" not in habit_tracker.habits["search_history"]

def test_get_recommendation_tags(habit_tracker):
    # Populate data
    habit_tracker.habits["search_history"] = {
        "browser": 10,
        "music": 5,
        "video": 1,
    }
    habit_tracker.habits["install_history"] = {
        "firefox": {"source": "Flatpak", "count": 1},
        "vlc": {"source": "Native", "count": 1}
    }

    tags = habit_tracker.get_recommendation_tags()
    assert "browser" in tags
    assert "music" in tags
    assert "video" in tags
    assert "firefox" in tags
    assert "vlc" in tags

@pytest.mark.asyncio
async def test_save_habits_async(habit_tracker):
    # Initial state shouldn't exist
    assert not habit_tracker.data_path.exists()

    # Record something to trigger save
    habit_tracker.record_search("test")

    # Since _save_habits creates an asyncio task, wait for it to complete
    await asyncio.sleep(0.1)

    assert habit_tracker.data_path.exists()
    with open(habit_tracker.data_path, "r") as f:
        data = json.load(f)
    assert data["search_history"]["test"] == 1

def test_save_habits_sync_fallback(habit_tracker):
    # Test when there's no running loop
    # Just call it directly, it should handle RuntimeError and do sync save
    with patch("asyncio.get_running_loop", side_effect=RuntimeError):
        habit_tracker.record_search("test")

    assert habit_tracker.data_path.exists()
    with open(habit_tracker.data_path, "r") as f:
        data = json.load(f)
    assert data["search_history"]["test"] == 1

def test_save_habits_coalescing(habit_tracker):
    # Mock the async loop and run_in_executor to verify coalescing
    mock_loop = MagicMock()

    with patch("asyncio.get_running_loop", return_value=mock_loop):
        # First call sets _is_saving
        habit_tracker._save_habits()
        assert habit_tracker._is_saving is True
        assert habit_tracker._needs_another_save is False

        # Second call while saving sets _needs_another_save
        habit_tracker._save_habits()
        assert habit_tracker._is_saving is True
        assert habit_tracker._needs_another_save is True
