import asyncio
import os
import shutil
import tempfile
from typing import Dict, List, Optional

from core.platform_profile import detect_system_profile, recommended_sources
from core.sources.utils import PrivilegeManager
from core.subprocess_utils import safe_subprocess


_MANAGER_COMMANDS = {
    "pacman": "pacman",
    "apt": "apt-get",
    "dnf": "dnf",
    "zypper": "zypper",
    "apk": "apk",
    "winget": "winget",
    "brew": "brew",
}


class EnvManager:
    def __init__(self):
        self.profile = detect_system_profile()
        # Kept for older callers while the UI/backend migrate to system_profile.
        self.is_arch = self.profile.native_manager == "pacman"
        self.privilege = PrivilegeManager()
        self._apt_updated = False

    async def check_env(self) -> Dict:
        """Return cross-platform capability status for first-run setup."""
        recommended = recommended_sources(self.profile)
        manager = self.profile.native_manager
        manager_command = _MANAGER_COMMANDS.get(manager, "")
        manager_available = bool(manager_command and self._has_cmd(manager_command))

        if self.profile.platform == "linux":
            system_message = self.profile.distro_id or "Linux"
            if self.profile.immutable:
                system_message += " (immutable/atomic)"
            system_status = "ok"
        elif self.profile.platform in {"windows", "macos"}:
            system_message = self.profile.platform.title()
            system_status = "ok"
        else:
            system_message = f"Platform {self.profile.platform} has limited support"
            system_status = "warning"

        status: Dict[str, Dict] = {
            "system": {
                "status": system_status,
                "message": f"Detected {system_message}",
                "platform": self.profile.platform,
                "distro_id": self.profile.distro_id,
                "distro_like": list(self.profile.distro_like),
                "immutable": self.profile.immutable,
                "native_manager": manager,
                "recommended_sources": recommended,
            },
            "native_package_manager": {
                "status": "ok" if manager_available else "warning",
                "message": (
                    f"Native package manager detected: {manager}"
                    if manager_available
                    else "No supported native package manager detected"
                ),
            },
        }

        if self.profile.platform == "linux":
            has_flatpak = self._has_cmd("flatpak")
            status["flatpak"] = {
                "status": "ok" if has_flatpak else "warning",
                "message": "Flatpak is installed" if has_flatpak else "Flatpak is not installed",
            }
            has_flathub = await self._has_flatpak_remote("flathub") if has_flatpak else False
            status["flathub"] = {
                "status": "ok" if has_flathub else "warning",
                "message": "Flathub remote is configured" if has_flathub else "Flathub remote is not configured",
            }

            if manager == "pacman":
                helper = self._aur_helper()
                status["aur_helper"] = {
                    "status": "ok" if helper else "warning",
                    "message": f"AUR helper detected: {helper}" if helper else "No AUR helper detected (yay/paru)",
                }
                status["build_tools"] = {
                    "status": "ok" if self._has_cmd("makepkg") and self._has_cmd("git") else "warning",
                    "message": (
                        "AUR build tools are available"
                        if self._has_cmd("makepkg") and self._has_cmd("git")
                        else "AUR build tools are incomplete"
                    ),
                }

        return status

    def _has_cmd(self, cmd: str) -> bool:
        return shutil.which(cmd) is not None

    def _aur_helper(self) -> Optional[str]:
        for helper in ("yay", "paru"):
            if self._has_cmd(helper):
                return helper
        return None

    async def _has_flatpak_remote(self, name: str) -> bool:
        if not self._has_cmd("flatpak"):
            return False
        try:
            async with safe_subprocess(
                "flatpak",
                "remotes",
                "--columns=name",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL,
            ) as proc:
                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10)
                if proc.returncode != 0:
                    return False
                return name in {line.strip() for line in stdout.decode("utf-8", errors="replace").splitlines()}
        except Exception:
            return False

    async def bootstrap(self, callback=None):
        """Prepare a clean machine for OmniStore's recommended source set.

        Linux bootstrap installs Flatpak using the distribution's native package
        manager, adds Flathub per-user, and on Arch-based systems prepares an AUR
        helper when neither yay nor paru exists. Immutable Fedora-style systems
        are never mutated through dnf/rpm-ostree here.
        """
        if self.profile.platform != "linux":
            if callback:
                await callback("[INFO] No automatic system bootstrap is required on this platform.")
            return True

        if self.profile.immutable:
            if not self._has_cmd("flatpak"):
                if callback:
                    await callback("[ERROR] Immutable Linux host detected without Flatpak. Host mutation is intentionally disabled.")
                return False
            return await self._ensure_flathub(callback)

        manager = self.profile.native_manager
        if not manager or not self._has_cmd(_MANAGER_COMMANDS.get(manager, "")):
            if callback:
                await callback("[ERROR] No supported native package manager is available for bootstrap.")
            return False

        # Flatpak is the common application layer across supported Linux distros.
        if not self._has_cmd("flatpak"):
            if callback:
                await callback(f"[INFO] Installing Flatpak with {manager}...")
            if not await self._install_native_packages(["flatpak"], callback):
                if callback:
                    await callback("[ERROR] Failed to install Flatpak.")
                return False

        if not await self._ensure_flathub(callback):
            return False

        # Arch gets the optional AUR layer as part of the recommended clean-install
        # setup. yay-bin avoids adding a Go toolchain just to bootstrap the helper.
        if manager == "pacman" and not self._aur_helper():
            if callback:
                await callback("[INFO] Preparing AUR support (git, base-devel, yay)...")
            if not await self._install_native_packages(["git", "base-devel"], callback):
                if callback:
                    await callback("[ERROR] Failed to install AUR build prerequisites.")
                return False
            if not await self._install_yay(callback):
                return False

        if callback:
            await callback("[INFO] Environment bootstrap completed successfully.")
        return True

    async def _ensure_privileged(self, callback=None) -> bool:
        if hasattr(os, "geteuid") and os.geteuid() == 0:
            return True
        if not self._has_cmd("sudo"):
            if callback:
                await callback("[ERROR] sudo is required for host package installation.")
            return False
        return await self.privilege.ensure_privileged(callback)

    async def _run_host_command(self, command: List[str], callback=None, timeout: int = 1800) -> bool:
        final_command = list(command)
        if not (hasattr(os, "geteuid") and os.geteuid() == 0):
            if not await self._ensure_privileged(callback):
                return False
            final_command = ["sudo", "-n", *final_command]

        try:
            async with safe_subprocess(
                *final_command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
            ) as proc:
                if proc.stdout:
                    while True:
                        raw = await proc.stdout.readline()
                        if not raw:
                            break
                        line = raw.decode("utf-8", errors="replace").strip()
                        if line and callback:
                            await callback(f"[INFO] {line}")
                await asyncio.wait_for(proc.wait(), timeout=timeout)
                return proc.returncode == 0
        except asyncio.TimeoutError:
            if callback:
                await callback("[ERROR] System package-manager command timed out.")
            return False
        except Exception as exc:
            if callback:
                await callback(f"[ERROR] System package-manager command failed: {exc}")
            return False

    async def _install_native_packages(self, packages: List[str], callback=None) -> bool:
        manager = self.profile.native_manager
        if manager == "pacman":
            return await self._run_host_command(
                ["pacman", "-S", "--noconfirm", "--needed", *packages], callback
            )

        if manager == "apt":
            if not self._apt_updated:
                if callback:
                    await callback("[INFO] Refreshing APT package metadata...")
                if not await self._run_host_command(["apt-get", "update"], callback, timeout=900):
                    return False
                self._apt_updated = True
            return await self._run_host_command(["apt-get", "install", "-y", *packages], callback)

        if manager == "dnf":
            return await self._run_host_command(["dnf", "install", "-y", *packages], callback)

        if manager == "zypper":
            return await self._run_host_command(
                ["zypper", "--non-interactive", "install", *packages], callback
            )

        if manager == "apk":
            return await self._run_host_command(["apk", "add", *packages], callback)

        return False

    async def _ensure_flathub(self, callback=None) -> bool:
        if not self._has_cmd("flatpak"):
            return False
        if await self._has_flatpak_remote("flathub"):
            return True
        if callback:
            await callback("[INFO] Adding Flathub remote for the current user...")
        try:
            async with safe_subprocess(
                "flatpak",
                "remote-add",
                "--user",
                "--if-not-exists",
                "flathub",
                "https://dl.flathub.org/repo/flathub.flatpakrepo",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
            ) as proc:
                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=60)
                if proc.returncode == 0:
                    return True
                if callback:
                    message = stdout.decode("utf-8", errors="replace").strip()
                    await callback(f"[ERROR] Failed to add Flathub: {message}")
                return False
        except Exception as exc:
            if callback:
                await callback(f"[ERROR] Failed to configure Flathub: {exc}")
            return False

    async def _install_yay(self, callback=None) -> bool:
        tmpdir = tempfile.mkdtemp(prefix="omnistore-yay-")
        try:
            if callback:
                await callback("[INFO] Downloading yay-bin from AUR...")
            async with safe_subprocess(
                "git",
                "clone",
                "--depth",
                "1",
                "https://aur.archlinux.org/yay-bin.git",
                tmpdir,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
            ) as clone:
                stdout, _ = await asyncio.wait_for(clone.communicate(), timeout=120)
                if clone.returncode != 0:
                    if callback:
                        await callback(
                            f"[ERROR] Failed to clone yay-bin: {stdout.decode('utf-8', errors='replace').strip()}"
                        )
                    return False

            # makepkg itself must stay unprivileged. Its pacman step can reuse the
            # sudo credentials validated by _install_native_packages above.
            if callback:
                await callback("[INFO] Building and installing yay-bin...")
            async with safe_subprocess(
                "makepkg",
                "-si",
                "--noconfirm",
                cwd=tmpdir,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
            ) as makepkg:
                if makepkg.stdout:
                    while True:
                        raw = await makepkg.stdout.readline()
                        if not raw:
                            break
                        line = raw.decode("utf-8", errors="replace").strip()
                        if line and callback:
                            await callback(f"[INFO] {line}")
                await asyncio.wait_for(makepkg.wait(), timeout=1800)
                if makepkg.returncode != 0:
                    if callback:
                        await callback("[ERROR] yay-bin build/install failed.")
                    return False
            return self._has_cmd("yay")
        except Exception as exc:
            if callback:
                await callback(f"[ERROR] Yay installation failed: {exc}")
            return False
        finally:
            shutil.rmtree(tmpdir, ignore_errors=True)
