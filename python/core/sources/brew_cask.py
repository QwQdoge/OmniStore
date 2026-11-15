"""Homebrew casks: macOS .app bundles. Experimental, macOS only."""

import asyncio
import json
import logging
import shutil
import sys
from typing import Any, Dict, List, Optional

from core.sources.base import UnifiedSource
from core.sources.external import _decode_output, _stream_simple_command
from core.subprocess_utils import safe_subprocess

NAME = "Homebrew Cask"


class BrewCaskSource(UnifiedSource):
    def __init__(self, weight: float = 1.0):
        super().__init__(name=NAME, weight=weight)
        self.enabled = sys.platform == "darwin" and shutil.which("brew") is not None
        self.capabilities.update({"locate": False, "size": False, "list_installed": True})

    async def _out(self, *args: str, timeout: int = 30) -> str:
        if not self.enabled:
            return ""
        try:
            async with safe_subprocess(
                "brew", *args, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL,
            ) as proc:
                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=timeout)
                return _decode_output(stdout or b"")
        except (asyncio.TimeoutError, OSError) as exc:
            logging.getLogger(__name__).warning("brew cask command failed: %s", exc)
            return ""

    def _entry(self, name: str, installed: bool, version: str = "Unknown") -> Dict[str, Any]:
        return {
            "name": name, "id": name, "source": NAME, "primary_source": NAME,
            "app_class": "native", "experimental": True, "installed": installed,
            "managed": True, "version": version, "last_version": version,
            "description": f"macOS app (Homebrew cask {name})",
            "variants": [{"source": NAME, "id": name, "installed": installed, "managed": True}],
        }

    async def _installed_versions(self) -> Dict[str, str]:
        found: Dict[str, str] = {}
        for line in (await self._out("list", "--cask", "--versions")).splitlines():
            parts = line.split()
            if parts:
                found[parts[0].lower()] = parts[1] if len(parts) > 1 else "Unknown"
        return found

    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None, **kwargs) -> List[Dict[str, Any]]:
        installed = await self._installed_versions()
        names = [n.strip() for n in (await self._out("search", "--cask", query)).splitlines()]
        return [self._entry(n, n.lower() in installed) for n in names if n and not n.startswith("==>")]

    async def list_installed(self) -> List[Dict[str, Any]]:
        return [self._entry(n, True, v) for n, v in (await self._installed_versions()).items()]

    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        name = str(package.get("id") or package.get("name") or "").strip()
        if not name:
            return False
        return await _stream_simple_command(["brew", "install", "--cask", name], self.enabled, self._async_callback(callback), "brew", timeout=1800)

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        name = str(package.get("id") or package.get("name") or "").strip()
        if not name:
            return False
        return await _stream_simple_command(["brew", "uninstall", "--cask", name], self.enabled, self._async_callback(callback), "brew", timeout=900)

    async def launch(self, package: Dict[str, Any]) -> bool:
        name = str(package.get("name") or package.get("id") or "").strip()
        if not (self.enabled and name):
            return False
        try:
            from core.desktop_actions import launch_detached
            return await launch_detached("open", "-a", name)
        except Exception:
            return False

    async def locate(self, package: Dict[str, Any]) -> bool:
        return False

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        info = self._entry(package_id, package_id.lower() in await self._installed_versions())
        try:
            data = json.loads(await self._out("info", "--cask", "--json=v2", package_id) or "{}")
            item = (data.get("casks") or [{}])[0]
            info["description"] = item.get("desc") or info["description"]
            info["version"] = item.get("version") or info["version"]
            info["homepage"] = item.get("homepage")
        except (ValueError, IndexError):
            pass
        return info

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        try:
            data = json.loads(await self._out("outdated", "--cask", "--json=v2", package_id) or "{}")
        except ValueError:
            return None
        items = data.get("casks") or []
        if not items:
            return None
        item = items[0]
        installed = item.get("installed_versions") or ["Unknown"]
        return {
            "name": item.get("name", package_id), "id": item.get("name", package_id),
            "source": NAME, "current_version": installed[0] if isinstance(installed, list) else installed,
            "new_version": item.get("current_version", "Unknown"),
        }
