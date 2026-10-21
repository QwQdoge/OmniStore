"""Custom repositories for every source that has a user-addable endpoint.

Flatpak, Pacman and AppImage keep their dedicated, tested implementation in
``custom_repo.py``.  Every other source is described here by a small spec:

* ``apply``: OmniStore asks the source's own CLI to register the endpoint
  (``brew tap``, ``scoop bucket add`` ...).  Nothing is recorded unless the
  CLI succeeds.
* ``track``: the source reads system files that need root (apt, dnf, zypper,
  apk).  OmniStore records the entry so the source can be shown and passed to
  the privileged helper, but never edits those files itself.
* ``feed``: the entry is only a URL/ref that OmniStore reads itself (GitHub
  repositories or organisations to watch).
"""

from __future__ import annotations

import asyncio
import copy
import logging
import re
import shutil
from dataclasses import dataclass
from typing import Any, Callable, Dict, List, Optional, Sequence

from core.subprocess_utils import safe_subprocess

logger = logging.getLogger(__name__)

NAME_PATTERN = re.compile(r"[A-Za-z0-9@._+:/-]{1,128}")
GITHUB_REF = re.compile(r"[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)?")


@dataclass(frozen=True)
class CustomSourceSpec:
    source: str
    mode: str  # "apply" | "track" | "feed"
    binary: Optional[str] = None
    needs_url: bool = True
    add: Optional[Callable[[str, str], Sequence[str]]] = None
    remove: Optional[Callable[[str], Sequence[str]]] = None


def _specs() -> Dict[str, CustomSourceSpec]:
    return {
        "brew": CustomSourceSpec(
            "brew", "apply", "brew", needs_url=False,
            add=lambda name, url: ["brew", "tap", name, *([url] if url else [])],
            remove=lambda name: ["brew", "untap", name],
        ),
        "scoop": CustomSourceSpec(
            "scoop", "apply", "scoop",
            add=lambda name, url: ["scoop", "bucket", "add", name, url],
            remove=lambda name: ["scoop", "bucket", "rm", name],
        ),
        "chocolatey": CustomSourceSpec(
            "chocolatey", "apply", "choco",
            add=lambda name, url: ["choco", "source", "add", f"--name={name}", f"--source={url}"],
            remove=lambda name: ["choco", "source", "remove", f"--name={name}"],
        ),
        "winget": CustomSourceSpec(
            "winget", "apply", "winget",
            add=lambda name, url: ["winget", "source", "add", "--name", name, "--arg", url],
            remove=lambda name: ["winget", "source", "remove", "--name", name],
        ),
        "fdroid": CustomSourceSpec(
            "fdroid", "apply", "fdroidcl",
            add=lambda name, url: ["fdroidcl", "repo", "add", name, url],
            remove=lambda name: ["fdroidcl", "repo", "remove", name],
        ),
        "apt": CustomSourceSpec("apt", "track"),
        "dnf": CustomSourceSpec("dnf", "track"),
        "zypper": CustomSourceSpec("zypper", "track"),
        "apk": CustomSourceSpec("apk", "track"),
        "github": CustomSourceSpec("github", "feed", needs_url=False),
        "snap": CustomSourceSpec("snap", "track"),
        "bitu": CustomSourceSpec("bitu", "feed"),
    }


SPECS = _specs()
NATIVE_TYPES = ("flatpak", "pacman", "appimage")
ALL_TYPES = (*NATIVE_TYPES, *SPECS.keys())


def valid_url(url: str) -> bool:
    value = (url or "").strip()
    return 1 <= len(value) <= 2048 and value.startswith(("https://", "http://", "file://"))


class GenericCustomSources:
    def __init__(self, config_manager: Any):
        self.cm = config_manager
        self._lock = asyncio.Lock()

    @staticmethod
    def supports(source: str) -> bool:
        return source in SPECS

    def describe(self) -> List[Dict[str, Any]]:
        """Capability table for UIs: what each source can accept."""
        rows = [{"source": s, "mode": "native", "needs_url": True} for s in NATIVE_TYPES]
        rows += [
            {
                "source": spec.source,
                "mode": spec.mode,
                "needs_url": spec.needs_url,
                "available": spec.binary is None or shutil.which(spec.binary) is not None,
            }
            for spec in SPECS.values()
        ]
        return rows

    def list(self, source: str) -> List[Dict[str, str]]:
        items = self.cm.get(f"custom_repos.{source}", []) if self.cm is not None else []
        out: List[Dict[str, str]] = []
        for item in items if isinstance(items, list) else []:
            if isinstance(item, dict) and item.get("name"):
                out.append({"name": str(item["name"]), "url": str(item.get("url", ""))})
            elif isinstance(item, str) and item:
                out.append({"name": item, "url": item})
        return out

    def list_all(self) -> Dict[str, List[Dict[str, str]]]:
        return {source: self.list(source) for source in SPECS}

    async def _run(self, command: Sequence[str]) -> bool:
        try:
            async with safe_subprocess(
                *command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
            ) as process:
                await asyncio.wait_for(process.communicate(), timeout=120)
                return process.returncode == 0
        except (OSError, asyncio.TimeoutError) as error:
            logger.error("Custom source command failed: %s", error)
            return False

    def _persist(self, source: str, entries: List[Dict[str, str]]) -> bool:
        return self.cm.set(f"custom_repos.{source}", copy.deepcopy(entries)) is not False

    async def add(self, source: str, name: str, url: str, callback: Any = None) -> bool:
        spec = SPECS.get(source)
        say = callback or (lambda _m: None)

        async def emit(message: str) -> None:
            result = say(message)
            if asyncio.iscoroutine(result):
                await result

        if spec is None:
            await emit(f"[ERROR] '{source}' does not accept custom repositories.")
            return False
        name = (name or "").strip()
        url = (url or "").strip()
        if source == "github":
            if not GITHUB_REF.fullmatch(name):
                await emit("[ERROR] GitHub entries are 'owner' or 'owner/repo'.")
                return False
            url = url or f"https://github.com/{name}"
        if not NAME_PATTERN.fullmatch(name) or name.startswith("-"):
            await emit(f"[ERROR] Invalid repository name '{name}'.")
            return False
        if (spec.needs_url or url) and not valid_url(url):
            await emit("[ERROR] A valid http(s):// or file:// URL is required.")
            return False
        async with self._lock:
            entries = self.list(source)
            if any(item["name"].casefold() == name.casefold() for item in entries):
                await emit(f"[WARNING] '{name}' is already configured for {source}.")
                return True
            if spec.mode == "apply":
                if shutil.which(spec.binary or "") is None:
                    await emit(f"[ERROR] {spec.binary} is not installed on this system.")
                    return False
                await emit(f"[INFO] Adding {source} repository '{name}'...")
                if not await self._run(spec.add(name, url)):
                    await emit(f"[ERROR] {spec.binary} refused to add '{name}'.")
                    return False
            entries.append({"name": name, "url": url})
            if not self._persist(source, entries):
                await emit("[ERROR] The repository was added but OmniStore could not save its configuration.")
                return False
            await emit(f"[INFO] Added {source} repository '{name}'.")
            return True

    async def remove(self, source: str, name: str, callback: Any = None) -> bool:
        spec = SPECS.get(source)
        say = callback or (lambda _m: None)

        async def emit(message: str) -> None:
            result = say(message)
            if asyncio.iscoroutine(result):
                await result

        name = (name or "").strip()
        if spec is None or not NAME_PATTERN.fullmatch(name) or name.startswith("-"):
            await emit("[ERROR] Invalid repository type or name.")
            return False
        async with self._lock:
            entries = self.list(source)
            if not any(item["name"] == name for item in entries):
                await emit(f"[WARNING] '{name}' is not managed by OmniStore.")
                return False
            if spec.mode == "apply" and shutil.which(spec.binary or ""):
                if not await self._run(spec.remove(name)):
                    await emit(f"[ERROR] {spec.binary} refused to remove '{name}'.")
                    return False
            remaining = [item for item in entries if item["name"] != name]
            if not self._persist(source, remaining):
                await emit("[ERROR] OmniStore could not save its configuration.")
                return False
            await emit(f"[INFO] Removed {source} repository '{name}'.")
            return True
