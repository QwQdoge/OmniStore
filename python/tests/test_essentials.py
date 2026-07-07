import json
import os
from unittest.mock import mock_open, patch, MagicMock

import pytest

from core.essentials import EssentialsManager


@pytest.fixture
def essentials_manager():
    config_manager_mock = MagicMock()
    return EssentialsManager(config_manager_mock)


def test_import_from_file_not_exists(essentials_manager):
    with patch("os.path.exists", return_value=False):
        assert essentials_manager.import_from_file("nonexistent.json") == []


def test_import_from_file_json_valid(essentials_manager, tmp_path):
    filepath = tmp_path / "test.json"
    data = [
        "pkg1",
        {"name": "pkg2", "source": "AUR"},
        {"other": "invalid"}  # should be skipped as it has no "name"
    ]
    tmp_path = filepath.with_suffix(".tmp")
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(data, f)
    tmp_path.replace(filepath)

    result = essentials_manager.import_from_file(str(filepath))
    assert result == [
        {"name": "pkg1", "source": "Native"},
        {"name": "pkg2", "source": "AUR"}
    ]


def test_import_from_file_json_not_list(essentials_manager, tmp_path):
    filepath = tmp_path / "test.json"
    data = {"name": "pkg1", "source": "Native"}  # dictionary instead of list
    tmp_path = filepath.with_suffix(".tmp")
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(data, f)
    tmp_path.replace(filepath)

    result = essentials_manager.import_from_file(str(filepath))
    assert result == []


def test_import_from_file_text_valid(essentials_manager, tmp_path):
    filepath = tmp_path / "test.txt"
    content = """
# This is a comment
pkg1

pkg2
# Another comment
"""
    tmp_path = filepath.with_suffix(".tmp")
    with open(tmp_path, "w", encoding="utf-8") as f:
        f.write(content)
    tmp_path.replace(filepath)

    result = essentials_manager.import_from_file(str(filepath))
    assert result == [
        {"name": "pkg1", "source": "Native"},
        {"name": "pkg2", "source": "Native"}
    ]


def test_import_from_file_json_decode_error(essentials_manager, tmp_path):
    filepath = tmp_path / "invalid.json"
    tmp_path = filepath.with_suffix(".tmp")
    with open(tmp_path, "w", encoding="utf-8") as f:
        f.write("invalid json content")
    tmp_path.replace(filepath)

    with patch("builtins.print") as mock_print:
        result = essentials_manager.import_from_file(str(filepath))
        assert result == []
        mock_print.assert_called_once()
        args = mock_print.call_args[0][0]
        assert "[EssentialsManager] Error importing:" in args


def test_import_from_file_io_error(essentials_manager, tmp_path):
    filepath = tmp_path / "test.txt"
    # Create the file so os.path.exists passes
    filepath.touch()

    with patch("builtins.open", side_effect=IOError("Permission denied")):
        with patch("builtins.print") as mock_print:
            result = essentials_manager.import_from_file(str(filepath))
            assert result == []
            mock_print.assert_called_once()
            args = mock_print.call_args[0][0]
            assert "[EssentialsManager] Error importing: Permission denied" in args
