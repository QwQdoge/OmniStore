"""Stable, read-only installed-application usage export for Meo Settings.

This module deliberately exposes a small, versioned projection of OmniStore's
installed-app model.  It is not a disk scanner and must not be presented as a
filesystem accounting tool: package-manager and Flatpak values are source
reported payload sizes, while AppImage values can be exact file sizes.

The projection avoids installation locations, descriptions, URLs, account
state, and any GUI preferences.  Consumers only receive enough data to show
the source mix and the relative share of known application-size metadata.
"""

from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation, ROUND_FLOOR
import re
from typing import Any, Iterable, Mapping


SCHEMA = "org.meo.omnistore.installed-usage"
SCHEMA_VERSION = 1
_MAX_TEXT_LENGTH = 256
_MAX_SIZE_BYTES = 4 * 1024**5  # Four PiB, safely below JSON's exact integer range.
_SIZE_RE = re.compile(r"^\s*(\d+(?:[.,]\d+)?)\s*([kmgtpe]?i?b)\s*$", re.IGNORECASE)


def _safe_text(value: Any, *, fallback: str, maximum: int = _MAX_TEXT_LENGTH) -> str:
    """Return bounded display text without control characters or path details."""
    if not isinstance(value, str):
        return fallback
    compact = " ".join(value.replace("\x00", " ").split())
    if not compact:
        return fallback
    return compact[:maximum]


def _source_id(label: str) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "-", label.lower()).strip("-")
    return normalized[:64] or "unknown"


def _size_from_reported_value(value: Any) -> int | None:
    """Convert only explicit B/KB/KiB-style source metadata to bytes.

    Decimal units use powers of 1000; IEC units use powers of 1024.  Anything
    that does not state a unit remains unknown rather than being guessed.
    """
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value if 0 <= value <= _MAX_SIZE_BYTES else None
    if not isinstance(value, str):
        return None

    match = _SIZE_RE.match(value.replace("\u00a0", " "))
    if not match:
        return None
    try:
        amount = Decimal(match.group(1).replace(",", "."))
    except InvalidOperation:
        return None
    if not amount.is_finite() or amount < 0:
        return None

    unit = match.group(2).lower()
    powers = {"b": 0, "kb": 1, "mb": 2, "gb": 3, "tb": 4, "pb": 5, "eb": 6}
    power = powers.get(unit.replace("i", ""))
    if power is None:
        return None
    multiplier = Decimal(1024 if "i" in unit else 1000) ** power
    bytes_value = int((amount * multiplier).to_integral_value(rounding=ROUND_FLOOR))
    return bytes_value if bytes_value <= _MAX_SIZE_BYTES else None


def _normalized_size(package: Mapping[str, Any]) -> tuple[int | None, str]:
    """Return a byte count and evidence type without mixing in download size."""
    raw_disk_size = package.get("disk_size")
    if isinstance(raw_disk_size, int) and not isinstance(raw_disk_size, bool):
        if 0 <= raw_disk_size <= _MAX_SIZE_BYTES:
            return raw_disk_size, "exact"

    reported = _size_from_reported_value(package.get("installed_size"))
    if reported is not None:
        return reported, "reported"
    return None, "unknown"


def _unwrap_packages(result: Any) -> list[Mapping[str, Any]]:
    """Accept the backend's normal list or its JSON-mode command envelope."""
    if isinstance(result, Mapping):
        if result.get("status") != "success":
            return []
        result = result.get("response")
    if not isinstance(result, list):
        return []
    return [package for package in result if isinstance(package, Mapping)]


def build_installed_usage_snapshot(
    packages: Iterable[Mapping[str, Any]], *, generated_at: datetime | None = None
) -> dict[str, Any]:
    """Build the schema-v1 export from OmniStore's installed-app result.

    Values are intentionally computed here instead of forwarding the source's
    aggregate data: a consumer can safely trust that every share has the same
    scope as the emitted application records.
    """
    applications: list[dict[str, Any]] = []
    source_totals: dict[str, dict[str, Any]] = {}

    for package in packages:
        if package.get("installed") is not True:
            continue
        name = _safe_text(package.get("name"), fallback="Unknown application")
        source_name = _safe_text(
            package.get("primary_source") or package.get("source"),
            fallback="Unknown source",
            maximum=80,
        )
        source_key = _source_id(source_name)
        size_bytes, size_kind = _normalized_size(package)
        application = {
            "name": name,
            "sourceId": source_key,
            "sourceName": source_name,
            "sizeKind": size_kind,
        }
        if size_bytes is not None:
            application["sizeBytes"] = size_bytes
        applications.append(application)

        source = source_totals.setdefault(
            source_key,
            {
                "id": source_key,
                "name": source_name,
                "applicationCount": 0,
                "knownSizeBytes": 0,
                "unknownSizeCount": 0,
            },
        )
        source["applicationCount"] += 1
        if size_bytes is None:
            source["unknownSizeCount"] += 1
        else:
            source["knownSizeBytes"] += size_bytes

    applications.sort(
        key=lambda item: (
            -int(item.get("sizeBytes") or -1),
            item["name"].casefold(),
            item["sourceId"],
        )
    )
    sources = sorted(
        source_totals.values(),
        key=lambda item: (-item["knownSizeBytes"], item["name"].casefold(), item["id"]),
    )
    known_size_bytes = sum(int(item["knownSizeBytes"]) for item in sources)
    unknown_size_count = sum(int(item["unknownSizeCount"]) for item in sources)
    timestamp = generated_at or datetime.now(timezone.utc)
    if timestamp.tzinfo is None:
        timestamp = timestamp.replace(tzinfo=timezone.utc)

    return {
        "schema": SCHEMA,
        "version": SCHEMA_VERSION,
        "status": "success",
        "generatedAt": timestamp.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
        "applicationCount": len(applications),
        "knownSizeBytes": known_size_bytes,
        "unknownSizeCount": unknown_size_count,
        "sources": sources,
        "applications": applications,
    }


async def export_installed_usage(backend: Any) -> dict[str, Any]:
    """Read OmniStore's existing installed-app data without invoking its GUI.

    The backend's command wrapper may return a JSON-mode envelope when the
    canonical CLI is invoked with ``--json``.  Treat a malformed or failed
    response as a collection failure rather than manufacturing a zero-sized
    application inventory.
    """
    result = await backend.run_list_installed(json_mode=False)
    if isinstance(result, Mapping) and result.get("status") != "success":
        raise RuntimeError("OmniStore could not collect installed applications")
    packages = _unwrap_packages(result)
    if result is not None and not isinstance(result, (list, Mapping)):
        raise RuntimeError("OmniStore returned an unsupported installed-app response")
    return build_installed_usage_snapshot(packages)
