"""Safe, package-owned MeoArch update-channel operations.

The resolved pacman configuration is the only channel state. This module never
edits pacman.conf, never uses pacman -Suu, and obtains the official package
set solely from the installed meo-release catalog.
"""

from __future__ import annotations

import asyncio
import json
import re
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Awaitable, Callable, Iterable
from urllib.parse import urlparse

from core.sources.utils import PrivilegeManager
from core.subprocess_utils import safe_subprocess


CATALOG_PATH = Path("/usr/share/meo-release/package-catalog.json")
KEYRING_PATH = Path("/usr/share/pacman/keyrings/meo.gpg")
TRUSTED_PATH = Path("/usr/share/pacman/keyrings/meo-trusted")
PACMAN_LOCAL_DATABASE = Path("/var/lib/pacman/local")
PACKAGE_NAME = re.compile(r"^[A-Za-z0-9@._+:-]+$")


@dataclass(frozen=True)
class CommandResult:
    returncode: int
    stdout: str


class MeoChannelError(RuntimeError):
    """A safe channel operation could not be completed."""


@dataclass(frozen=True)
class LocalArchive:
    """An exact, signature-verified archive participating in one rollback."""

    name: str
    version: str
    path: Path


def pacman_records(output: str) -> dict[str, str]:
    """Parse the constrained `pacman -Q`/`-Qp --q` name-version output."""
    records: dict[str, str] = {}
    for line in output.splitlines():
        parts = line.split(maxsplit=1)
        if len(parts) != 2 or not PACKAGE_NAME.fullmatch(parts[0]) or not parts[1].strip():
            raise MeoChannelError("pacman returned invalid package metadata")
        if parts[0] in records:
            raise MeoChannelError("pacman returned duplicate package metadata")
        records[parts[0]] = parts[1].strip()
    return records


def package_relation_names(info: str, field: str) -> set[str]:
    """Extract package names from pacman -Qip conflict/replaces fields only."""
    # pacman wraps long relationship lists onto indented continuation lines.
    # Include every continuation so a foreign conflict cannot evade the
    # restricted-transaction guard merely by appearing after the first line.
    expression = re.compile(
        rf"^{re.escape(field)}\s*:\s*(.*(?:\n[ \t]+.*)*)$",
        re.MULTILINE,
    )
    match = expression.search(info)
    if not match:
        raise MeoChannelError(f"pacman package metadata is missing {field}")
    raw = " ".join(line.strip() for line in match.group(1).splitlines()).strip()
    if raw in {"", "None"}:
        return set()
    names: set[str] = set()
    for value in raw.split():
        name = re.split(r"[<>=]", value, maxsplit=1)[0]
        if not PACKAGE_NAME.fullmatch(name):
            raise MeoChannelError(f"pacman package metadata has invalid {field}")
        names.add(name)
    return names


def local_only_pacman_config(
    *,
    root: Path | None = None,
    database: Path | None = None,
    cache: Path | None = None,
    gpg_directory: Path | None = None,
) -> str:
    """Render an options-only config so `pacman -U` cannot use sync repos."""
    lines = [
        "[options]",
        "SigLevel = Required TrustedOnly",
        "LocalFileSigLevel = Required",
    ]
    if root is not None:
        lines.append(f"RootDir = {root}")
    if database is not None:
        lines.append(f"DBPath = {database}")
    if cache is not None:
        lines.append(f"CacheDir = {cache}")
    if gpg_directory is not None:
        lines.append(f"GPGDir = {gpg_directory}")
    return "\n".join(lines) + "\n"


class MeoOnlyLocalRollback:
    """Future Beta-to-Stable downgrade executor with no sync fallback.

    Exact Stable archives and detached signatures are fetched from the catalog's
    repository base, verified with the installed Meo keyring, exercised in a
    cloned pacman database rooted under a temporary directory, then committed
    as the same local archive set after user confirmation/authorization.
    """

    def __init__(
        self,
        command: Callable[..., Awaitable[CommandResult]],
        *,
        keyring_path: Path = KEYRING_PATH,
        trusted_path: Path = TRUSTED_PATH,
        local_database: Path = PACMAN_LOCAL_DATABASE,
    ) -> None:
        self._command = command
        self.keyring_path = keyring_path
        self.trusted_path = trusted_path
        self.local_database = local_database

    async def _result(self, *arguments: str, environment: dict[str, str] | None = None) -> CommandResult:
        result = await self._command(*arguments, environment=environment)
        if result.returncode != 0:
            raise MeoChannelError(f"restricted local rollback command failed: {arguments[0]}")
        return result

    async def _stable_archive_url(self, package: str, version: str, base_url: str) -> str:
        result = await self._result("pacman", "-Sp", "--nodeps", "--print-format", "%l", f"meo/{package}={version}")
        urls = [line.strip() for line in result.stdout.splitlines() if line.strip()]
        if len(urls) != 1:
            raise MeoChannelError(f"Stable archive resolution was not exact for {package}")
        url = urls[0]
        if not url.startswith(base_url.rstrip("/") + "/") or urlparse(url).scheme != "https":
            raise MeoChannelError(f"Stable archive URL is outside the official Meo repository: {package}")
        return url

    async def _remote_version(self, package: str) -> str:
        result = await self._result("pacman", "-Si", f"meo/{package}")
        match = re.search(r"^Version\s*:\s*(\S+)", result.stdout, re.MULTILINE)
        if not match:
            raise MeoChannelError(f"could not read Stable version for {package}")
        return match.group(1)

    async def _download_archive(
        self,
        *,
        package: str,
        version: str,
        base_url: str,
        directory: Path,
    ) -> tuple[LocalArchive, str]:
        url = await self._stable_archive_url(package, version, base_url)
        filename = Path(urlparse(url).path).name
        if not filename.endswith(".pkg.tar.zst"):
            raise MeoChannelError(f"Stable archive URL is not an Arch package: {package}")
        archive = directory / filename
        signature = archive.with_name(archive.name + ".sig")
        await self._result("curl", "--fail", "--location", "--silent", "--show-error", "--output", str(archive), url)
        await self._result("curl", "--fail", "--location", "--silent", "--show-error", "--output", str(signature), url + ".sig")
        await self._result("gpgv", "--keyring", str(self.keyring_path), str(signature), str(archive))
        metadata = pacman_records((await self._result("pacman", "-Qp", "--q", str(archive))).stdout)
        if metadata != {package: version}:
            raise MeoChannelError(f"Stable archive metadata does not match the reviewed candidate: {package}")
        info = (await self._result("pacman", "-Qip", str(archive))).stdout
        return LocalArchive(package, version, archive), info

    @staticmethod
    def _validate_relations(info: str, official: set[str]) -> None:
        for field in ("Conflicts With", "Replaces"):
            foreign = package_relation_names(info, field) - official
            if foreign:
                raise MeoChannelError(f"restricted rollback rejects {field} outside the official catalog")

    async def execute(
        self,
        *,
        downgrades: list[dict[str, str]],
        catalog: dict[str, Any],
        environment: dict[str, str],
    ) -> dict[str, Any]:
        official = set(official_packages(catalog))
        base_url = catalog.get("repositoryBaseUrl")
        if not isinstance(base_url, str) or not base_url.startswith("https://"):
            raise MeoChannelError("meo-release package catalog has no HTTPS repository base URL")
        expected = {entry.get("name"): entry.get("stable") for entry in downgrades}
        if (not expected or len(expected) != len(downgrades)
                or any(not isinstance(name, str) or not isinstance(version, str)
                       for name, version in expected.items()) or set(expected) - official):
            raise MeoChannelError("Stable rollback preview is not an official exact package set")
        # The channel selector participates in the same archive transaction.
        if "meo-channel-stable" in expected:
            raise MeoChannelError("Stable rollback preview cannot replace the channel selector")
        expected["meo-channel-stable"] = await self._remote_version("meo-channel-stable")
        with tempfile.TemporaryDirectory(prefix="omnistore-meo-rollback-") as temporary:
            work = Path(temporary)
            archives: list[LocalArchive] = []
            for package, version in sorted(expected.items()):
                archive, info = await self._download_archive(
                    package=package,
                    version=version,
                    base_url=base_url,
                    directory=work,
                )
                self._validate_relations(info, official)
                archives.append(archive)
            changed = await self._verify_in_isolation(archives, official, work)
            real_config = work / "pacman-local-only.conf"
            real_config.write_text(local_only_pacman_config(), encoding="utf-8")
            # No [repo] sections: pacman -U cannot resolve a missing dependency
            # through Arch or a third-party repository.
            await self._result(
                "sudo", "-A", "pacman", "--config", str(real_config), "-U", "--noconfirm",
                *(str(archive.path) for archive in archives), environment=environment,
            )
            return {"status": "success", "archives": [archive.name for archive in archives], "changed": sorted(changed)}

    async def _verify_in_isolation(self, archives: list[LocalArchive], official: set[str], work: Path) -> set[str]:
        if not self.local_database.is_dir() or not self.keyring_path.is_file() or not self.trusted_path.is_file():
            raise MeoChannelError("local pacman state is unavailable for restricted rollback verification")
        root = work / "root"
        database = work / "database"
        cache = work / "cache"
        gpg = work / "gnupg"
        root.mkdir()
        cache.mkdir()
        shutil.copytree(self.local_database, database)
        gpg.parent.mkdir(parents=True)
        await self._result("pacman-key", "--gpgdir", str(gpg), "--init")
        await self._result("pacman-key", "--gpgdir", str(gpg), "--add", str(self.keyring_path))
        await self._result("pacman-key", "--gpgdir", str(gpg), "--import-trustdb", str(self.trusted_path))
        config = work / "pacman-isolated.conf"
        config.write_text(
            local_only_pacman_config(root=root, database=database, cache=cache, gpg_directory=gpg),
            encoding="utf-8",
        )
        before = pacman_records((await self._result("pacman", "--dbpath", str(database), "-Q")).stdout)
        await self._result(
            "pacman", "--root", str(root), "--dbpath", str(database), "--config", str(config),
            "-U", "--noconfirm", *(str(archive.path) for archive in archives),
        )
        after = pacman_records((await self._result("pacman", "--dbpath", str(database), "-Q")).stdout)
        changed = {name for name in set(before) | set(after) if before.get(name) != after.get(name)}
        if not changed or not changed <= official:
            raise MeoChannelError("isolated rollback would affect a package outside the official catalog")
        return changed


def channel_from_repositories(repositories: Iterable[str]) -> str:
    """Determine the channel from pacman's resolved order, not a preference."""
    names = [str(name).strip().casefold() for name in repositories if str(name).strip()]
    if "meo-beta" in names:
        if "meo" not in names or names.index("meo-beta") > names.index("meo"):
            return "invalid"
        return "beta"
    return "stable" if "meo" in names else "unconfigured"


def official_packages(catalog: dict[str, Any]) -> tuple[str, ...]:
    """Return the complete installed catalog universe, never a name prefix."""
    if catalog.get("schemaVersion") != 2:
        raise MeoChannelError("meo-release package catalog has an unsupported schema")
    packages = catalog.get("officialPackages")
    if not isinstance(packages, list):
        raise MeoChannelError("meo-release package catalog is missing officialPackages")
    names = tuple(sorted(str(name) for name in packages))
    if not names or len(set(names)) != len(names) or any(not PACKAGE_NAME.fullmatch(name) for name in names):
        raise MeoChannelError("meo-release package catalog contains invalid official package names")
    return names


def channel_availability(catalog: dict[str, Any], channel: str) -> tuple[bool, str]:
    availability = catalog.get("channelAvailability")
    if channel not in {"stable", "beta"} or not isinstance(availability, dict):
        raise MeoChannelError("meo-release channel availability metadata is invalid")
    state = availability.get(channel)
    if not isinstance(state, dict) or not isinstance(state.get("coreTrainAvailable"), bool):
        raise MeoChannelError("meo-release channel availability metadata is incomplete")
    message = state.get("message")
    if not isinstance(message, str) or not message:
        raise MeoChannelError("meo-release channel availability has no user-safe message")
    return state["coreTrainAvailable"], message


class MeoChannelManager:
    def __init__(
        self,
        *,
        catalog_path: Path = CATALOG_PATH,
        privilege_manager: PrivilegeManager | None = None,
        runner: Callable[[tuple[str, ...], dict[str, str] | None], Awaitable[CommandResult]] | None = None,
        rollback_executor: MeoOnlyLocalRollback | None = None,
    ) -> None:
        self.catalog_path = catalog_path
        self.privilege = privilege_manager or PrivilegeManager()
        self._runner = runner or self._run
        self.rollback_executor = rollback_executor or MeoOnlyLocalRollback(self._command)

    async def _run(
        self,
        arguments: tuple[str, ...],
        environment: dict[str, str] | None = None,
    ) -> CommandResult:
        async with safe_subprocess(
            *arguments,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
            env=environment,
        ) as process:
            stdout, _ = await asyncio.wait_for(process.communicate(), timeout=180)
            return CommandResult(process.returncode or 0, stdout.decode("utf-8", errors="replace"))

    async def _command(
        self,
        *arguments: str,
        environment: dict[str, str] | None = None,
    ) -> CommandResult:
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
        return {
            "status": "success",
            "channel": channel_from_repositories(repositories),
            "repositories": repositories,
        }

    def _catalog(self) -> dict[str, Any]:
        try:
            catalog = json.loads(self.catalog_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise MeoChannelError("meo-release package metadata is unavailable") from error
        if not isinstance(catalog, dict):
            raise MeoChannelError("meo-release package catalog is invalid")
        return catalog

    def _catalog_packages(self) -> tuple[str, ...]:
        return official_packages(self._catalog())

    async def _authorized_environment(self) -> dict[str, str]:
        if not await self.privilege.ensure_privileged():
            raise MeoChannelError("administrator authorization was not granted")
        return await self.privilege.subprocess_environment()

    async def switch_to_beta(self) -> dict[str, Any]:
        """Install the package-owned beta selector, then do a normal upgrade."""
        environment = await self._authorized_environment()
        install = await self._command(
            "sudo",
            "-A",
            "pacman",
            "-S",
            "--needed",
            "--noconfirm",
            "meo-channel-beta",
            environment=environment,
        )
        if install.returncode != 0:
            raise MeoChannelError("could not install the Meo Beta channel package")
        upgrade = await self._command(
            "sudo",
            "-A",
            "pacman",
            "-Syyu",
            "--noconfirm",
            environment=environment,
        )
        if upgrade.returncode != 0:
            raise MeoChannelError("the normal system upgrade after enabling Beta failed")
        status = await self.status()
        if status["channel"] != "beta":
            raise MeoChannelError("Beta channel package did not resolve meo-beta before meo")
        return status

    def _stable_is_available(self) -> tuple[bool, str]:
        return channel_availability(self._catalog(), "stable")

    async def stable_preview(self) -> dict[str, Any]:
        """Read exact [meo] candidates without changing the channel."""
        available, message = self._stable_is_available()
        if not available:
            return {"status": "stable_unavailable", "channel": "stable", "message": message, "downgrades": []}
        packages = self._catalog_packages()
        candidates: list[dict[str, str]] = []
        for package in packages:
            installed = await self._command("pacman", "-Q", package)
            if installed.returncode != 0:
                continue
            # Generic pacman -Si would resolve the beta overlay first; naming
            # meo/package is necessary to inspect a real Stable candidate.
            remote = await self._command("pacman", "-Si", f"meo/{package}")
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
        """Fail before mutation when no Stable core train exists.

        A future downgrade is verified as a no-sync local archive transaction
        before authorization permits that same archive set on the real system.
        This method never changes channel configuration before it has a complete
        safe preview.
        """
        preview = await self.stable_preview()
        if preview["status"] == "stable_unavailable":
            try:
                current = await self.status()
            except MeoChannelError:
                current = {"channel": "unconfigured", "repositories": []}
            return {**preview, "currentChannel": current["channel"], "repositories": current["repositories"]}
        if preview["downgrades"]:
            if not confirm_downgrades:
                preview["status"] = "confirmation_required"
                return preview
            environment = await self._authorized_environment()
            await self.rollback_executor.execute(
                downgrades=preview["downgrades"],
                catalog=self._catalog(),
                environment=environment,
            )
            status = await self.status()
            if status["channel"] != "stable":
                raise MeoChannelError("restricted Stable rollback did not remove the beta overlay")
            return status
        environment = await self._authorized_environment()
        install = await self._command(
            "sudo",
            "-A",
            "pacman",
            "-S",
            "--needed",
            "--noconfirm",
            "meo-channel-stable",
            environment=environment,
        )
        if install.returncode != 0:
            raise MeoChannelError("could not install the Meo Stable channel package")
        refresh = await self._command("sudo", "-A", "pacman", "-Syy", environment=environment)
        if refresh.returncode != 0:
            raise MeoChannelError("could not refresh Stable repository metadata")
        status = await self.status()
        if status["channel"] != "stable":
            raise MeoChannelError("Stable channel package did not remove the beta overlay")
        return status
