import json

import pytest

from core.update_state import (
    SCHEMA,
    build_state,
    canonical_plan,
    normalize_candidate,
    read_state,
    write_state,
)


def test_resource_identity_is_stable_and_source_scoped():
    native = normalize_candidate({"name": "demo", "source": "Pacman", "current_version": "1", "new_version": "2"})
    flatpak = normalize_candidate({"id": "org.demo.App", "name": "demo", "source": "Flatpak", "current_version": "1", "new_version": "2"})

    assert native["resource_id"] == "pacman:demo"
    assert flatpak["resource_id"] == "flatpak:org.demo.App"
    assert native["resource_id"] != flatpak["resource_id"]


def test_plan_hash_is_order_independent():
    first = {"id": "a", "name": "A", "source": "Pacman", "current_version": "1", "new_version": "2"}
    second = {"id": "b", "name": "B", "source": "Flatpak", "current_version": "1", "new_version": "2"}
    assert canonical_plan([first, second])["plan_hash"] == canonical_plan([second, first])["plan_hash"]


def test_state_round_trip_is_atomic_and_versioned(tmp_path):
    target = tmp_path / "state.json"
    payload = build_state([{"name": "demo", "source": "Pacman", "current_version": "1", "new_version": "2"}])
    write_state(payload, target)

    loaded = read_state(target)
    assert loaded["schema"] == SCHEMA
    assert loaded["count"] == 1
    assert not target.with_suffix(".json.tmp").exists()


def test_state_rejects_wrong_schema(tmp_path):
    target = tmp_path / "state.json"
    target.write_text(json.dumps({"schema": "wrong", "version": 1, "updates": []}))
    with pytest.raises(ValueError, match="unsupported"):
        read_state(target)
