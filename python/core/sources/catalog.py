"""Third-party catalog sources.

A catalog is a static JSON index published by anyone. It runs no code: each app
points at an install target that an existing built-in source already knows how to
handle (``delegate``). OmniStore keeps the downloaded index next to a generated
``plugin.json`` in the user's config directory; the source starts disabled and
needs review before it is switched on.
"""

import json
import re
import urllib.request
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional
from urllib.parse import urlparse

from core.sources.base import UnifiedSource

MAX_INDEX_BYTES = 2 * 1024 * 1024
SCHEMA_VERSION = 1
_ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")
VALID_PLATFORMS = {"linux", "windows", "macos"}
# Sources a catalog may delegate to. Nothing here spawns code the catalog wrote.
DELEGATE_TARGETS = {
    "flatpak", "appimage", "pacman", "aur", "apt", "dnf", "zypper", "apk",
    "winget", "scoop", "chocolatey", "brew", "brewcask", "fdroid", "github", "bottles",
}


class CatalogError(ValueError):
    pass


def validate_index(data: Any) -> Dict[str, Any]:
    """Return a cleaned copy of the index or raise CatalogError."""
    if not isinstance(data, dict):
        raise CatalogError("Index must be a JSON object.")
    if data.get("schema") != SCHEMA_VERSION:
        raise CatalogError(f"Unsupported schema; expected {SCHEMA_VERSION}.")
    catalog_id = str(data.get("id") or "")
    if not _ID_RE.match(catalog_id):
        raise CatalogError("Index id must be lowercase letters, digits, '.', '_' or '-'.")
    name = str(data.get("name") or "").strip()
    if not name:
        raise CatalogError("Index name is required.")
    platforms = [str(p) for p in data.get("platforms", [])]
    if any(p not in VALID_PLATFORMS for p in platforms):
        raise CatalogError("platforms may only contain linux, windows, macos.")
    apps: List[Dict[str, Any]] = []
    for raw in data.get("apps", []):
        if not isinstance(raw, dict) or not raw.get("id") or not raw.get("name"):
            raise CatalogError("Every app needs an id and a name.")
        install = raw.get("install") or {}
        if install.get("type") != "delegate" or install.get("source") not in DELEGATE_TARGETS or not install.get("id"):
            raise CatalogError(f"App {raw.get('id')}: install must delegate to a known source.")
        apps.append({
            "id": str(raw["id"]),
            "name": str(raw["name"]),
            "description": str(raw.get("description") or ""),
            "version": str(raw.get("version") or "Unknown"),
            "homepage": str(raw.get("homepage") or ""),
            "icon": str(raw.get("icon") or ""),
            "install": {"type": "delegate", "source": str(install["source"]), "id": str(install["id"])},
        })
    return {"schema": SCHEMA_VERSION, "id": catalog_id, "name": name,
            "version": str(data.get("version") or "1.0.0"), "platforms": platforms, "apps": apps}


def fetch_index(url: str, opener: Optional[Callable[[str], bytes]] = None) -> Dict[str, Any]:
    if urlparse(url).scheme != "https":
        raise CatalogError("Catalog URLs must use https.")
    if opener is None:
        def opener(u: str) -> bytes:
            req = urllib.request.Request(u, headers={"User-Agent": "OmniStore"})
            with urllib.request.urlopen(req, timeout=20) as resp:
                return resp.read(MAX_INDEX_BYTES + 1)
    body = opener(url)
    if len(body) > MAX_INDEX_BYTES:
        raise CatalogError("Index is larger than 2 MB.")
    try:
        return validate_index(json.loads(body.decode("utf-8")))
    except (UnicodeDecodeError, ValueError) as exc:
        if isinstance(exc, CatalogError):
            raise
        raise CatalogError(f"Index is not valid JSON: {exc}")


def install_catalog(url: str, user_dir: Path, opener: Optional[Callable[[str], bytes]] = None) -> str:
    """Download, validate and store a catalog. Returns its plugin id."""
    index = fetch_index(url, opener)
    plugin_id = f"catalog.{index['id']}"
    target = Path(user_dir) / plugin_id
    target.mkdir(parents=True, exist_ok=True)
    (target / "catalog.json").write_text(json.dumps(index, ensure_ascii=False, indent=2), encoding="utf-8")
    manifest = {
        "id": plugin_id, "kind": "source", "type": "catalog", "name": index["name"],
        "version": index["version"], "index": url, "platforms": index["platforms"],
        "capabilities": ["search", "details", "install", "uninstall", "launch"],
        "permissions": ["network", "delegates"], "builtin": False, "trusted": False,
        "default_enabled": False, "requires_review": True, "offer": "manual",
    }
    (target / "plugin.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return plugin_id


class CatalogSource(UnifiedSource):
    def __init__(self, plugin_id: str, name: str, apps: List[Dict[str, Any]],
                 resolver: Callable[[str], Optional[UnifiedSource]]):
        super().__init__(name=name)
        self.source_id = plugin_id
        self.apps = {a["id"]: a for a in apps}
        self.resolver = resolver
        self.capabilities.update({"list_installed": False, "update": False, "locate": False})

    @classmethod
    def from_dir(cls, plugin_id: str, name: str, directory: Path, resolver) -> "CatalogSource":
        index = validate_index(json.loads((Path(directory) / "catalog.json").read_text(encoding="utf-8")))
        return cls(plugin_id, name, index["apps"], resolver)

    def _entry(self, app: Dict[str, Any]) -> Dict[str, Any]:
        return {**{k: app[k] for k in ("id", "name", "description", "version", "homepage", "icon")},
                "source": self.name, "primary_source": self.name, "last_version": app["version"],
                "installed": False,
                "variants": [{"source": self.name, "id": app["id"], "installed": False}]}

    def _target(self, package: Dict[str, Any]):
        app = self.apps.get(str(package.get("id") or ""))
        if not app:
            return None, None
        inst = app["install"]
        return self.resolver(inst["source"]), {**package, "id": inst["id"], "name": app["name"]}

    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None, **kwargs) -> List[Dict[str, Any]]:
        needle = (query or "").strip().lower()
        return [self._entry(a) for a in self.apps.values()
                if needle and (needle in a["name"].lower() or needle in a["description"].lower())]

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        app = self.apps.get(package_id)
        return self._entry(app) if app else {"id": package_id, "name": package_id, "source": self.name}

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        return None

    async def _delegate(self, method: str, package: Dict[str, Any], *extra) -> bool:
        source, target = self._target(package)
        if source is None or not getattr(source, "enabled", False):
            return False
        return bool(await getattr(source, method)(target, *extra))

    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        return await self._delegate("install", package, callback)

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        return await self._delegate("uninstall", package, callback)

    async def launch(self, package: Dict[str, Any]) -> bool:
        return await self._delegate("launch", package)

    async def locate(self, package: Dict[str, Any]) -> bool:
        return False
