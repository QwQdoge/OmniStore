import asyncio
import logging
import re
import shutil
from typing import Dict, List

from core.platform_profile import detect_system_profile
from core.subprocess_utils import safe_subprocess


class UpdateManager:
    def __init__(self, config=None):
        self.config = config
        self.profile = detect_system_profile()

    def _source_enabled(self, source_id: str, default: bool = True) -> bool:
        if not self.config:
            return default
        return bool(self.config.get(f"search.sources.{source_id}", default))

    async def check_all_updates(self) -> List[Dict]:
        tasks = []
        manager = self.profile.native_manager
        include_aur = True
        if self.config:
            include_aur = self.config.get("updates.include_aur_in_update_all", True)

        if manager == "pacman" and self._source_enabled("pacman") and shutil.which("pacman"):
            tasks.append(self.check_pacman_updates())
        elif manager == "apt" and self._source_enabled("apt") and shutil.which("apt"):
            tasks.append(self.check_apt_updates())
        elif manager == "dnf" and self._source_enabled("dnf") and shutil.which("dnf"):
            tasks.append(self.check_dnf_updates())
        elif manager == "zypper" and self._source_enabled("zypper") and shutil.which("zypper"):
            tasks.append(self.check_zypper_updates())
        elif manager == "apk" and self._source_enabled("apk") and shutil.which("apk"):
            tasks.append(self.check_apk_updates())

        if (
            manager == "pacman"
            and include_aur
            and self._source_enabled("aur")
            and (shutil.which("yay") or shutil.which("paru"))
        ):
            tasks.append(self.check_aur_updates())

        if self._source_enabled("flatpak") and shutil.which("flatpak"):
            tasks.append(self.check_flatpak_updates())

        results = await asyncio.gather(*tasks, return_exceptions=True)

        combined: List[Dict] = []
        for res in results:
            if isinstance(res, list):
                combined.extend(res)
            elif isinstance(res, Exception):
                logging.getLogger("omnistore").warning("Update check failed: %s", res)

        return combined

    async def _capture(self, cmd: List[str], timeout: int = 45) -> tuple[int, str]:
        try:
            async with safe_subprocess(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL,
            ) as proc:
                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=timeout)
                return proc.returncode or 0, (stdout or b"").decode("utf-8", errors="replace")
        except asyncio.TimeoutError:
            return 124, ""
        except Exception:
            return 127, ""

    async def check_pacman_updates(self) -> List[Dict]:
        """Check native Arch updates without mutating package databases."""
        command = ["checkupdates"] if shutil.which("checkupdates") else ["pacman", "-Qu"]
        return await self._run_arrow_updates(command, "Pacman")

    async def check_aur_updates(self) -> List[Dict]:
        helper = "yay" if shutil.which("yay") else "paru" if shutil.which("paru") else ""
        if not helper:
            return []
        return await self._run_arrow_updates([helper, "-Qua"], "AUR")

    async def _run_arrow_updates(self, cmd: List[str], source: str) -> List[Dict]:
        code, output = await self._capture(cmd)
        # pacman/checkupdates may use a non-zero code for "no updates" in some
        # environments, so parse stdout whenever present.
        if not output.strip():
            return []

        updates = []
        for line in output.splitlines():
            match = re.match(r"^([^\s]+)\s+([^\s]+)\s+->\s+([^\s]+)", line.strip())
            if not match:
                continue
            name, old_ver, new_ver = match.groups()
            updates.append({
                "name": name,
                "source": source,
                "current_version": old_ver,
                "new_version": new_ver,
                "description": f"Update available from {source}",
            })
        return updates

    async def check_apt_updates(self) -> List[Dict]:
        """Parse `apt list --upgradable` without changing package state."""
        code, output = await self._capture(["apt", "list", "--upgradable"], timeout=60)
        if code not in (0, 100) and not output.strip():
            return []

        updates: List[Dict] = []
        pattern = re.compile(
            r"^(?P<name>[^/\s]+)/\S+\s+(?P<new>\S+)\s+\S+\s+\[upgradable from: (?P<old>[^\]]+)\]"
        )
        for raw in output.splitlines():
            line = raw.strip()
            if not line or line.lower().startswith("listing"):
                continue
            match = pattern.match(line)
            if not match:
                continue
            updates.append({
                "name": match.group("name"),
                "source": "APT",
                "current_version": match.group("old"),
                "new_version": match.group("new"),
                "description": "Update available from APT",
            })
        return updates

    async def check_dnf_updates(self) -> List[Dict]:
        """Check Fedora/RHEL updates; DNF returns 100 when updates exist."""
        code, output = await self._capture(["dnf", "check-upgrade", "--quiet"], timeout=90)
        if code not in (0, 100):
            return []

        updates: List[Dict] = []
        for raw in output.splitlines():
            line = raw.strip()
            if not line or line.startswith(("Last metadata", "Obsoleting", "Security:")):
                continue
            parts = line.split()
            if len(parts) < 2 or "." not in parts[0]:
                continue
            name_arch, new_version = parts[0], parts[1]
            name = name_arch.rsplit(".", 1)[0]
            current_version = await self._rpm_installed_version(name)
            updates.append({
                "name": name,
                "source": "DNF",
                "current_version": current_version,
                "new_version": new_version,
                "description": "Update available from DNF",
            })
        return updates

    async def _rpm_installed_version(self, package: str) -> str | None:
        if not shutil.which("rpm"):
            return None
        code, output = await self._capture(
            ["rpm", "-q", "--qf", "%{VERSION}-%{RELEASE}", package], timeout=10
        )
        return output.strip() if code == 0 and output.strip() else None

    async def check_zypper_updates(self) -> List[Dict]:
        code, output = await self._capture(
            ["zypper", "--non-interactive", "list-updates"], timeout=90
        )
        if code != 0 and not output.strip():
            return []

        updates: List[Dict] = []
        for raw in output.splitlines():
            line = raw.strip()
            if "|" not in line or line.startswith(("S |", "--+", "Loading", "Reading")):
                continue
            columns = [part.strip() for part in line.split("|")]
            # Typical columns: v | Repository | Name | Current Version | Available Version | Arch
            if len(columns) < 5:
                continue
            name = columns[2]
            current_version = columns[3]
            new_version = columns[4]
            if not name or not new_version:
                continue
            updates.append({
                "name": name,
                "source": "Zypper",
                "current_version": current_version or None,
                "new_version": new_version,
                "description": "Update available from Zypper",
            })
        return updates

    async def check_apk_updates(self) -> List[Dict]:
        """Check Alpine updates using apk's comparison output."""
        code, output = await self._capture(["apk", "version", "-l", "<"], timeout=45)
        if code != 0 and not output.strip():
            return []

        updates: List[Dict] = []
        # Example: package-1.0-r0 < 1.1-r0
        pattern = re.compile(r"^(?P<installed>.+)\s+<\s+(?P<new>\S+)$")
        for raw in output.splitlines():
            match = pattern.match(raw.strip())
            if not match:
                continue
            installed = match.group("installed")
            # Alpine package names may contain hyphens, so resolve the package
            # name from `apk info -e` candidates when possible. Falling back to
            # the installed token is still preferable to dropping the update.
            name = await self._apk_package_name(installed)
            updates.append({
                "name": name,
                "source": "APK",
                "current_version": installed[len(name) + 1 :] if installed.startswith(f"{name}-") else None,
                "new_version": match.group("new"),
                "description": "Update available from APK",
            })
        return updates

    async def _apk_package_name(self, installed_token: str) -> str:
        if not shutil.which("apk"):
            return installed_token
        # `apk info -W` is path-oriented, so derive the longest installed name
        # prefix from the local package list instead.
        code, output = await self._capture(["apk", "info"], timeout=20)
        if code == 0:
            matches = [
                name.strip()
                for name in output.splitlines()
                if name.strip() and installed_token.startswith(f"{name.strip()}-")
            ]
            if matches:
                return max(matches, key=len)
        return installed_token.rsplit("-", 2)[0] if "-" in installed_token else installed_token

    async def check_flatpak_updates(self) -> List[Dict]:
        if not shutil.which("flatpak"):
            return []

        code, output = await self._capture(
            ["flatpak", "list", "--updates", "--columns=name,application,version,new-version"],
            timeout=60,
        )
        if code != 0 or not output.strip():
            return []

        updates = []
        for line in output.splitlines():
            parts = [p.strip() for p in line.split("\t")]
            if len(parts) >= 4:
                updates.append({
                    "name": parts[0],
                    "id": parts[1],
                    "source": "Flatpak",
                    "current_version": parts[2] or None,
                    "new_version": parts[3] or parts[2] or "Unknown",
                    "description": f"Flatpak update: {parts[1]}",
                })
        return updates
