import asyncio
import json
from unittest.mock import MagicMock
import sys
import os

# Add python directory to sys.path
sys.path.insert(0, os.path.abspath("python"))

from core.search.manager import SearchManager

async def test_merge_duplicates_preserves_id():
    # Mock dependencies
    config = MagicMock()
    config.get.return_value = {}
    session = MagicMock()

    manager = SearchManager(config, session)

    # Simulate search results where a lower priority source comes first
    combined = [
        {
            "name": "Firefox",
            "source": "Pacman",
            "last_version": "120.0",
            "description": "Pacman version",
            "installed": True,
            "_smart_score": 1000,
            "id": None
        },
        {
            "name": "Firefox",
            "source": "Flatpak",
            "last_version": "121.0",
            "description": "Flatpak version",
            "installed": False,
            "_smart_score": 900,
            "id": "org.mozilla.firefox"
        }
    ]

    merged = manager.merge_duplicates(combined)

    print(f"Merged results count: {len(merged)}")
    if len(merged) > 0:
        first = merged[0]
        print(f"Primary source: {first.get('primary_source')}")
        print(f"ID: {first.get('id')}")

        if first.get('primary_source') == 'Flatpak' and first.get('id') is None:
            print("BUG CONFIRMED: ID is missing even though Flatpak is primary source!")
        elif first.get('primary_source') == 'Flatpak' and first.get('id') == 'org.mozilla.firefox':
            print("ID preserved correctly.")
        else:
            print("Unexpected result.")

if __name__ == "__main__":
    asyncio.run(test_merge_duplicates_preserves_id())
