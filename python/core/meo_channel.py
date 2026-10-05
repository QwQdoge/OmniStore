"""Safe, package-owned MeoArch update-channel operations.

The effective pacman configuration is the only channel state.  This module
never edits pacman.conf, never uses ``pacman -Suu``, and only identifies Meo
packages from the metadata installed by ``meo-release``.
"""

from __future__ import annotations

import asyncio
import json
import os
import re
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Awaitable, Callable, Iterable

from core.sources.utils import PrivilegeManager
from core.subprocess_utils import safe_subprocess


CATALOG_PATH = Path("/usr/share/meo-release/package-catalog.json")
ROLLBACK_HELPER = "/usr/lib/omnistore/meo-stable-rollback.py"
PACKAGE_NAME = re.compile(r"^[A-Za-z0-9@._+:-]+$")
PLAN_HASH = re.compile(r"^[0-9a-f]{64}$")


@dataclass(frozen=True)
class CommandResult:
    returncode: int
    stdout: str


class MeoChannelError(RuntimeError):
    """A safe channel operation could not be completed."""


def channel_from_repositories(repositories: Iterable[str]) -> str:
    """Determine channel from pacman's resolved order, not a preference file."""
    names = [str(name).strip().casefold() for name in repositories if str(name).strip()]
    if "meo-beta" in names:
        if "meo" not in names or names.index("meo-beta") > names.index("meo"):
            return "invalid"
        return "beta"
    return "stable" if "meo" in names else "unconfigured"


def official_packages(catalog: dict[str, Any]) -> tuple[str, ...]:
    packages = catalog.get("packages")
    if isinstance(packages, dict):
        names = tuple(sorted(str(name) for name in packages))
    else:
        # Release generations before the unified catalog shipped this compact
        # list.  Supporting it keeps a channel switch fail-closed but usable
        # across a normal meo-release upgrade; no prefix matching is allowed.
        legacy_names = catalog.get("officialPackages")
        if not isinstance(legacy_names, list):
            raise MeoChannelError("meo-release package catalog is invalid")
        names = tuple(sorted(str(name) for name in legacy_names))
    if not names or len(set(names)) != len(names) or any(not PACKAGE_NAME.fullmatch(name) for name in names):
        raise MeoChannelError("meo-release package catalog is invalid")
    return names


class MeoChannelManager:
    def __init__(
        self,
        *,
        catalog_path: Path = CATALOG_PATH,
        privilege_manager: PrivilegeManager | None = None,
        runner: Callable[[tuple[str, ...], dict[str, str] | None], Awaitable[CommandResult]] | None = None,
        rollback_runner: Callable[[dict[str, Any], dict[str, str]], Awaitable[CommandResult]] | None = None,
        rollback_helper: str = ROLLBACK_HELPER,
    ) -> None:
        self.catalog_path = catalog_path
        self.privilege = privilege_manager or PrivilegeManager()
        self._runner = runner or self._run
        self._rollback_runner = rollback_runner or self._run_rollback_helper
        self._rollback_helper = rollback_helper

    async def _run(self, arguments: tuple[str, ...], environment: dict[str, str] | None = None) -> CommandResult:
        async with safe_subprocess(
            *arguments,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
            env=environment,
        ) as process:
            stdout, _ = await asyncio.wait_for(process.communicate(), timeout=180)
            return CommandResult(process.returncode or 0, stdout.decode("utf-8", errors="replace"))

    async def _command(self, *arguments: str, environment: dict[str, str] | None = None) -> CommandResult:
        return await self._runner(tuple(arguments), environment)

    async def _run_rollback_helper(self, request: dict[str, Any], environment: dict[str, str]) -> CommandResult:
        """Call the package-owned root helper with a closed JSON protocol."""
        encoded = json.dumps(request, separators=(",", ":")).encode("utf-8")
        async with safe_subprocess(
            "sudo", "-A", self._rollback_helper,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
            env=environment,
        ) as process:
            stdout, _ = await asyncio.wait_for(process.communicate(encoded), timeout=1800)
            return CommandResult(process.returncode or 0, stdout.decode("utf-8", errors="replace"))

    async def _rollback(self, operation: str, environment: dict[str, str], plan_hash: str | None = None) -> dict[str, Any]:
        request: dict[str, Any] = {"version": 1, "operation": operation}
        if plan_hash is not None:
            if not PLAN_HASH.fullmatch(plan_hash):
                raise MeoChannelError("the confirmed Stable rollback plan is invalid")
            request["planHash"] = plan_hash
        result = await self._rollback_runner(request, environment)
        try:
            payload = json.loads(result.stdout)
        except json.JSONDecodeError as error:
            raise MeoChannelError("the Stable rollback helper returned invalid data") from error
        if not isinstance(payload, dict) or result.returncode != 0:
            raise MeoChannelError(str(payload.get("error", "the Stable rollback helper failed"))
                                  if isinstance(payload, dict) else "the Stable rollback helper failed")
        return payload

    async def repositories(self) -> list[str]:
        result = await self._command("pacman-conf", "--repo-list")
        if result.returncode != 0:
            raise MeoChannelError("pacman-conf could not resolve the active repositories")
        repositories = [line.strip().casefold() for line in result.stdout.splitlines() if line.strip()]
        if any(not re.fullmatch(r"[a-z0-9@._+-]+", name) for name in repositories):
            raise MeoChannelError("pacman-conf returned an invalid repository name")
        return repositories

    async def status(self) -> dict[str, Any]:
        repositories = await self.repositories()
        return {"status": "success", "channel": channel_from_repositories(repositories), "repositories": repositories}

    def _catalog_packages(self) -> tuple[str, ...]:
        try:
            catalog = json.loads(self.catalog_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise MeoChannelError("meo-release package metadata is unavailable") from error
        return official_packages(catalog)

    async def _authorized_environment(self) -> dict[str, str]:
        if not await self.privilege.ensure_privileged():
            raise MeoChannelError("administrator authorization was not granted")
        return await self.privilege.subprocess_environment()

    async def switch_to_beta(self) -> dict[str, Any]:
        """Install the package-owned beta configuration, then perform a normal upgrade."""
        environment = await self._authorized_environment()
        install = await self._command(
            "sudo", "-A", "pacman", "-S", "--needed", "--noconfirm", "meo-channel-beta",
            environment=environment,
        )
        if install.returncode != 0:
            raise MeoChannelError("could not install the Meo Beta channel package")
        upgrade = await self._command("sudo", "-A", "pacman", "-Syyu", "--noconfirm", environment=environment)
        if upgrade.returncode != 0:
            raise MeoChannelError("the normal system upgrade after enabling Beta failed")
        return await self.status()

    async def stable_preview(self) -> dict[str, Any]:
        """Prepare a signed, Meo-only rollback preview through the root helper."""
        environment = await self._authorized_environment()
        return await self._rollback("preview", environment)

    async def switch_to_stable(
        self,
        *,
        confirm_downgrades: bool = False,
        confirmed_plan_hash: str | None = None,
    ) -> dict[str, Any]:
        """Safely select Stable and return/confirm Meo-only rollback work.

        The first transaction changes only the channel package.  If stable is
        behind, the caller must show the preview and repeat with confirmation.
        The root helper validates the signed Stable candidates and commits one
        local-package transaction only when the user confirms its plan hash.
        """
        environment = await self._authorized_environment()
        install = await self._command(
            "sudo", "-A", "pacman", "-S", "--needed", "--noconfirm", "meo-channel-stable",
            environment=environment,
        )
        if install.returncode != 0:
            raise MeoChannelError("could not install the Meo Stable channel package")
        refresh = await self._command("sudo", "-A", "pacman", "-Syy", environment=environment)
        if refresh.returncode != 0:
            raise MeoChannelError("could not refresh Stable repository metadata")
        preview = await self._rollback("preview", environment)
        if preview["downgrades"] and not confirm_downgrades:
            preview["status"] = "confirmation_required"
            return preview
        if preview["downgrades"]:
            if confirmed_plan_hash is None:
                raise MeoChannelError("Stable rollback confirmation requires the reviewed plan hash")
            return await self._rollback("commit", environment, confirmed_plan_hash)
        return await self.status()
