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
PACKAGE_NAME = re.compile(r"^[A-Za-z0-9@._+:-]+$")


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
    if not isinstance(packages, dict):
        raise MeoChannelError("meo-release package catalog is invalid")
    names = tuple(sorted(str(name) for name in packages))
    if not names or any(not PACKAGE_NAME.fullmatch(name) for name in names):
        raise MeoChannelError("meo-release package catalog contains invalid package names")
    return names


class MeoChannelManager:
    def __init__(
        self,
        *,
        catalog_path: Path = CATALOG_PATH,
        privilege_manager: PrivilegeManager | None = None,
        runner: Callable[[tuple[str, ...], dict[str, str] | None], Awaitable[CommandResult]] | None = None,
    ) -> None:
        self.catalog_path = catalog_path
        self.privilege = privilege_manager or PrivilegeManager()
        self._runner = runner or self._run

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
        """List installed official Meo packages which are newer than Stable.

        Querying the sync database occurs only after the stable channel package
        is selected in a separate transaction by ``switch_to_stable``.
        """
        packages = self._catalog_packages()
        candidates: list[dict[str, str]] = []
        for package in packages:
            installed = await self._command("pacman", "-Q", package)
            if installed.returncode != 0:
                continue
            remote = await self._command("pacman", "-Si", package)
            if remote.returncode != 0:
                raise MeoChannelError(f"Stable metadata has no candidate for {package}")
            installed_version = installed.stdout.strip().split(maxsplit=1)[-1]
            available_match = re.search(r"^Version\s*:\s*(\S+)", remote.stdout, re.MULTILINE)
            if not available_match:
                raise MeoChannelError(f"could not read the Stable version for {package}")
            available_version = available_match.group(1)
            comparison = await self._command("vercmp", installed_version, available_version)
            if comparison.returncode != 0 or comparison.stdout.strip() not in {"-1", "0", "1"}:
                raise MeoChannelError("vercmp could not compare installed and Stable versions")
            if comparison.stdout.strip() == "1":
                candidates.append({"name": package, "installed": installed_version, "stable": available_version})
        return {"status": "success", "channel": "stable", "downgrades": candidates}

    async def switch_to_stable(self, *, confirm_downgrades: bool = False) -> dict[str, Any]:
        """Safely select Stable and return/confirm Meo-only rollback work.

        The first transaction changes only the channel package.  If stable is
        behind, the caller must show the preview and repeat with confirmation.
        Actual local package rollback is intentionally withheld until a signed
        download-and-resolver implementation is available; accepting generic
        ``-Suu`` here would allow Arch packages to be downgraded.
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
        preview = await self.stable_preview()
        if preview["downgrades"] and not confirm_downgrades:
            preview["status"] = "confirmation_required"
            return preview
        if preview["downgrades"]:
            raise MeoChannelError(
                "Meo-only signed downgrade execution is not available yet; Stable was configured, "
                "but no packages were downgraded. Refusing pacman -Suu protects Arch packages."
            )
        return await self.status()
