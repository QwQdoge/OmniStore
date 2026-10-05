"""Stable state and identity contract for Meo/OmniStore updates.

The update UI may group records, but it must never erase the source/resource
identity of an individual candidate.  This module is deliberately independent
from Flutter and the daemon so Meo Settings can consume the same JSON state.
"""

from __future__ import annotations

import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


SCHEMA = "org.meo.update-state"
SCHEMA_VERSION = 1
MAX_STATE_BYTES = 4 * 1024 * 1024


def state_path() -> Path:
    root = os.environ.get("XDG_STATE_HOME")
    if root:
        return Path(root) / "meo-update" / "state.json"
    return Path.home() / ".local" / "state" / "meo-update" / "state.json"


def normalize_candidate(candidate: dict[str, Any]) -> dict[str, Any]:
    name = str(candidate.get("name", "")).strip()
    source = str(candidate.get("source", "unknown")).strip() or "unknown"
    source_id = str(candidate.get("source_id", source.casefold())).strip().casefold()
    package_id = str(candidate.get("id", name)).strip() or name
    resource_id = str(candidate.get("resource_id", f"{source_id}:{package_id}")).strip()
    return {
        "resource_id": resource_id,
        "source_id": source_id,
        "repository": str(candidate.get("repository", "")).strip(),
        "id": package_id,
        "name": name,
        "source": source,
        "current_version": str(candidate.get("current_version", "")).strip(),
        "new_version": str(candidate.get("new_version", "")).strip(),
        "description": str(candidate.get("description", "")).strip(),
    }


def canonical_plan(updates: Iterable[dict[str, Any]]) -> dict[str, Any]:
    resources = sorted(
        (normalize_candidate(item) for item in updates),
        key=lambda item: (item["source_id"], item["resource_id"]),
    )
    canonical = json.dumps(resources, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return {
        "schema": "org.meo.update-plan",
        "version": 1,
        "plan_hash": hashlib.sha256(canonical.encode("utf-8")).hexdigest(),
        "resources": resources,
    }


def build_state(updates: Iterable[dict[str, Any]], *, postflight: dict[str, Any] | None = None) -> dict[str, Any]:
    plan = canonical_plan(updates)
    sources: dict[str, int] = {}
    for item in plan["resources"]:
        sources[item["source_id"]] = sources.get(item["source_id"], 0) + 1
    payload: dict[str, Any] = {
        "schema": SCHEMA,
        "version": SCHEMA_VERSION,
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "count": len(plan["resources"]),
        "sources": sources,
        "plan_hash": plan["plan_hash"],
        "updates": plan["resources"],
    }
    if postflight is not None:
        payload["postflight"] = postflight
    return payload


def write_state(payload: dict[str, Any], target: Path | None = None) -> Path:
    destination = target or state_path()
    destination.parent.mkdir(parents=True, exist_ok=True)
    encoded = (json.dumps(payload, ensure_ascii=False, sort_keys=True) + "\n").encode("utf-8")
    if len(encoded) > MAX_STATE_BYTES:
        raise ValueError("update state exceeds its safety limit")
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    temporary.write_bytes(encoded)
    os.chmod(temporary, 0o600)
    temporary.replace(destination)
    return destination


def read_state(target: Path | None = None) -> dict[str, Any]:
    source = target or state_path()
    raw = source.read_bytes()
    if len(raw) > MAX_STATE_BYTES:
        raise ValueError("update state exceeds its safety limit")
    payload = json.loads(raw)
    if payload.get("schema") != SCHEMA or payload.get("version") != SCHEMA_VERSION:
        raise ValueError("unsupported update state")
    if not isinstance(payload.get("updates"), list):
        raise ValueError("invalid update state")
    return payload
