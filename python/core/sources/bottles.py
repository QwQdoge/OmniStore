"""Bottles source: Windows applications that run through Wine in a bottle.

A bottle is a container, not an app. The programs registered inside a bottle
are the apps. They stay out of the normal installed list until the user decides
per bottle (``bottles.listed``), so a fresh Bottles setup never floods the list.

Command syntax follows ``bottles-cli``. It has not been exercised against a live
Bottles install from this repository's tests; those use a fake command runner.
"""

import asyncio
import logging
import shutil
from typing import Any, Dict, List, Optional, Tuple

from core.sources.base import UnifiedSource
from core.subprocess_utils import safe_subprocess

FLATPAK_APP_ID = "com.usebottles.bottles"
SOURCE_NAME = "Bottles"


def _decode(data: bytes) -> str:
    return data.decode("utf-8", errors="ignore").replace("\r\n", "\n")


def bottles_command() -> List[str]:
    """Return the argv prefix that runs bottles-cli, or [] when unavailable."""
    if shutil.which("bottles-cli"):
        return ["bottles-cli"]
    if shutil.which("flatpak"):
        return ["flatpak", "run", "--command=bottles-cli", FLATPAK_APP_ID]
    return []


def parse_bottle_list(text: str) -> List[str]:
    """Parse ``bottles-cli list bottles`` output (one ``- name`` per line)."""
    names: List[str] = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.endswith(":") or line.lower().startswith("found"):
            continue
        if line.startswith(("-", "*")):
            line = line[1:].strip()
        if line:
            names.append(line)
    return names


def parse_program_list(text: str) -> List[str]:
    """Parse ``bottles-cli programs -b NAME`` output the same way."""
    return parse_bottle_list(text)


class BottlesSource(UnifiedSource):
    def __init__(self, config_manager: Any = None, weight: float = 1.0):
        super().__init__(name=SOURCE_NAME, weight=weight)
        self.cm = config_manager
        self.argv = bottles_command()
        self.enabled = bool(self.argv)
        self.capabilities.update({
            "install": True,  # run a Windows installer inside a chosen bottle
            "uninstall": False,
            "update": False,
            "details": True,
            "list_installed": True,
            "launch": True,
            "locate": False,
            "size": False,
        })

    # -- command plumbing -------------------------------------------------

    async def _run(self, *args: str, timeout: int = 30) -> Tuple[int, str]:
        if not self.argv:
            return 127, ""
        try:
            async with safe_subprocess(
                *self.argv, *args,
                stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT,
            ) as proc:
                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=timeout)
                return proc.returncode or 0, _decode(stdout or b"")
        except (asyncio.TimeoutError, OSError) as exc:
            logging.getLogger(__name__).warning("bottles-cli failed: %s", exc)
            return 1, ""

    async def bottles(self) -> List[str]:
        code, out = await self._run("list", "bottles")
        return parse_bottle_list(out) if code == 0 else []

    async def programs(self, bottle: str) -> List[str]:
        code, out = await self._run("programs", "-b", bottle)
        return parse_program_list(out) if code == 0 else []

    # -- user decision: which bottles show up as normal apps --------------

    def _listed_map(self) -> Dict[str, bool]:
        if self.cm is None:
            return {}
        return dict(self.cm.get("bottles.listed", {}) or {})

    def set_listed(self, bottle: str, listed: bool) -> None:
        if self.cm is None:
            return
        mapping = self._listed_map()
        mapping[bottle] = bool(listed)
        self.cm.set("bottles.listed", mapping)

    async def pending_bottles(self) -> List[str]:
        """Bottles the user has not decided about yet (ask once, not every time)."""
        decided = self._listed_map()
        return [b for b in await self.bottles() if b not in decided]

    # -- UnifiedSource ----------------------------------------------------

    @staticmethod
    def _entry(bottle: str, program: str, installed: bool = True) -> Dict[str, Any]:
        package_id = f"{bottle}::{program}"
        return {
            "name": program,
            "id": package_id,
            "bottle": bottle,
            "program": program,
            "source": SOURCE_NAME,
            "primary_source": SOURCE_NAME,
            "app_class": "wrapped",
            "runtime": "wine",
            "managed": True,
            "installed": installed,
            "description": f"Windows app in Bottles bottle “{bottle}”",
            "variants": [{"source": SOURCE_NAME, "id": package_id, "installed": installed, "managed": True}],
        }

    async def list_installed(self) -> List[Dict[str, Any]]:
        if not self.enabled:
            return []
        listed = self._listed_map()
        results: List[Dict[str, Any]] = []
        for bottle in await self.bottles():
            if not listed.get(bottle):
                continue
            for program in await self.programs(bottle):
                results.append(self._entry(bottle, program))
        return results

    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None, **kwargs) -> List[Dict[str, Any]]:
        """Search programs in the bottles the user chose to list."""
        needle = (query or "").strip().lower()
        if not needle:
            return []
        return [item for item in await self.list_installed() if needle in item["name"].lower()]

    @staticmethod
    def split_id(package: Dict[str, Any]) -> Tuple[str, str]:
        bottle = str(package.get("bottle") or "")
        program = str(package.get("program") or "")
        if not (bottle and program):
            bottle, _, program = str(package.get("id") or "").partition("::")
        return bottle.strip(), program.strip()

    async def launch(self, package: Dict[str, Any]) -> bool:
        bottle, program = self.split_id(package)
        if not (self.enabled and bottle and program):
            return False
        code, _ = await self._run("run", "-b", bottle, "-p", program, timeout=20)
        return code == 0

    async def locate(self, package: Dict[str, Any]) -> bool:
        return False

    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        """Run a Windows installer (``installer_path``) inside ``bottle``."""
        callback = self._async_callback(callback)
        bottle = str(package.get("bottle") or "").strip()
        installer = str(package.get("installer_path") or "").strip()
        if not (self.enabled and bottle and installer):
            if callback:
                await callback("[ERROR] Bottles needs a bottle and an installer file.")
            return False
        if callback:
            await callback(f"[INFO] Running installer in bottle {bottle}")
        code, out = await self._run("run", "-b", bottle, "-e", installer, timeout=1800)
        if callback:
            await callback("[PROGRESS] 100" if code == 0 else f"[ERROR] {out.strip()[-200:]}")
        return code == 0

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        callback = self._async_callback(callback)
        if callback:
            await callback("[ERROR] Remove Windows programs from inside their bottle.")
        return False

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        bottle, _, program = package_id.partition("::")
        return self._entry(bottle, program or package_id)

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        return None

    def config_schema(self) -> Dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "listed": {
                    "type": "object",
                    "description": "bottle name -> true to show its programs as normal apps.",
                    "additionalProperties": {"type": "boolean"},
                }
            },
        }

    async def health_check(self) -> Dict[str, Any]:
        info = await super().health_check()
        info["ok"] = bool(self.enabled)
        info["pending_bottles"] = await self.pending_bottles() if self.enabled else []
        return info
