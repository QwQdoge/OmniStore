from __future__ import annotations

from datetime import datetime, timedelta, timezone
import hashlib
import json
from typing import Any

from core.security_validator import SecurityValidator


PLAN_SCHEMA = "org.meo.omnistore.transaction-plan"
PLAN_VERSION = 1
PLAN_TTL_SECONDS = 300


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(value: datetime) -> str:
    return value.isoformat().replace("+00:00", "Z")


def _plain(value: Any) -> Any:
    if hasattr(value, "model_dump"):
        return value.model_dump(exclude_none=True)
    if isinstance(value, dict):
        return {str(key): _plain(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_plain(item) for item in value]
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    return str(value)


def _source_key(value: Any) -> str:
    key = str(value or "").strip().lower()
    aliases = {
        "": "pacman",
        "native": "pacman",
        "arch": "pacman",
        "arch linux": "pacman",
        "flathub": "flatpak",
    }
    return aliases.get(key, key)


def _plugin_for(backend: Any, source: str) -> dict[str, Any] | None:
    manager = getattr(backend, "manager", None)
    registry = getattr(manager, "plugin_registry", None)
    if registry is None:
        return None

    requested = _source_key(source)
    for raw in registry.list_plugins():
        plugin = _plain(raw)
        plugin_id = str(plugin.get("id") or "")
        plugin_name = str(plugin.get("name") or "")
        candidates = {
            _source_key(plugin_name),
            _source_key(plugin_id.removeprefix("builtin.").removeprefix("legacy.")),
        }
        if requested in candidates:
            return plugin
    return None


def _variant_for(details: dict[str, Any], source: str) -> dict[str, Any]:
    requested = _source_key(source)
    variants = details.get("variants") or []
    for raw in variants:
        if isinstance(raw, dict) and _source_key(raw.get("source")) == requested:
            return dict(raw)

    primary = details.get("primary_source") or details.get("source")
    if _source_key(primary) == requested:
        return {
            "source": primary,
            "id": details.get("id"),
            "name": details.get("name"),
            "version": details.get("version"),
            "download_size": details.get("download_size"),
            "installed_size": details.get("installed_size"),
            "disk_size": details.get("disk_size"),
            "size_confidence": details.get("size_confidence"),
            "size_source": details.get("size_source"),
            "depends": details.get("depends"),
            "url": details.get("url"),
        }
    return {}


def _plan_hash(plan_without_hash: dict[str, Any]) -> str:
    encoded = json.dumps(
        plan_without_hash,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


async def build_install_plan(
    backend: Any,
    *,
    name: str,
    source: str = "Native",
    url: str | None = None,
) -> dict[str, Any]:
    """Build a read-only install plan from live backend/source metadata.

    The plan never guesses package size, dependencies, trust, or availability.
    Missing evidence remains null/empty and the package manager remains the
    authority for final dependency resolution during apply.
    """

    package_name = SecurityValidator.validate_string(name or "", "Package Name")
    source_name = SecurityValidator.validate_string(source or "Native", "Source")
    requested_url = SecurityValidator.validate_url(url) if url else None

    # Ensure SearchManager/PluginRegistry exist before reading source policy.
    await backend.initialize()

    details: dict[str, Any] = {}
    try:
        raw_details = await backend.run_app_details(package_name, False, source_name)
        plain_details = _plain(raw_details)
        if isinstance(plain_details, dict) and plain_details.get("status") != "error":
            details = plain_details
    except Exception:
        # Planning is still useful with source policy + exact requested identity.
        # Unknown metadata stays unknown instead of being fabricated.
        details = {}

    plugin = _plugin_for(backend, source_name)
    variant = _variant_for(details, source_name)

    capabilities = list(plugin.get("capabilities") or []) if plugin else []
    permissions = list(plugin.get("permissions") or []) if plugin else []
    available = bool(plugin and plugin.get("available", False))
    enabled = bool(plugin and plugin.get("enabled", False))
    trusted = bool(plugin and plugin.get("trusted", False))
    requires_review = bool(plugin and plugin.get("requires_review", True))
    supports_install = "install" in capabilities

    effective_url = requested_url or variant.get("url") or details.get("url")
    if effective_url:
        effective_url = SecurityValidator.validate_url(str(effective_url), "Package URL")

    package_id = str(variant.get("id") or details.get("id") or package_name)
    display_name = str(variant.get("name") or details.get("name") or package_name)
    version = variant.get("version") or details.get("version")
    dependencies = variant.get("depends") or []
    if not isinstance(dependencies, list):
        dependencies = []
    dependencies = [str(item) for item in dependencies if str(item).strip()][:256]

    warnings: list[str] = []
    if plugin is None:
        warnings.append("source_policy_unavailable")
    else:
        if not available:
            warnings.append("source_unavailable")
        if not enabled:
            warnings.append("source_disabled")
        if not supports_install:
            warnings.append("source_install_capability_missing")
        if requires_review:
            warnings.append("source_requires_review")
        elif not trusted:
            warnings.append("source_not_trusted")

    can_apply = bool(plugin and available and enabled and supports_install)
    trust = "trusted" if trusted and not requires_review else (
        "review-required" if requires_review else "untrusted"
    )
    requires_privilege = "system_package_manager" in permissions

    created = _utc_now()
    expires = created + timedelta(seconds=PLAN_TTL_SECONDS)
    plan: dict[str, Any] = {
        "schema": PLAN_SCHEMA,
        "version": PLAN_VERSION,
        "action": "install",
        "createdAt": _iso(created),
        "expiresAt": _iso(expires),
        "ttlSeconds": PLAN_TTL_SECONDS,
        "canApply": can_apply,
        "confirmationRequired": True,
        "request": {
            "name": package_name,
            "source": source_name,
            "url": effective_url,
        },
        "package": {
            "id": package_id,
            "name": display_name,
            "version": str(version) if version is not None else None,
            "downloadSize": variant.get("download_size") or details.get("download_size"),
            "installedSize": variant.get("installed_size") or details.get("installed_size"),
            "diskSize": variant.get("disk_size") or details.get("disk_size"),
            "sizeConfidence": variant.get("size_confidence") or details.get("size_confidence"),
            "sizeSource": variant.get("size_source") or details.get("size_source"),
            "dependencies": dependencies,
            "dependencyResolution": "package-manager",
        },
        "source": {
            "id": str(plugin.get("id") or "") if plugin else None,
            "name": str(plugin.get("name") or source_name) if plugin else source_name,
            "available": available,
            "enabled": enabled,
            "trusted": trusted,
            "requiresReview": requires_review,
            "trust": trust,
            "capabilities": capabilities,
            "permissions": permissions,
        },
        "requiresPrivilege": requires_privilege,
        "warnings": warnings,
    }
    plan["planHash"] = _plan_hash(plan)
    return plan
