import os
import shutil
import sys
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Dict, List, Optional


@dataclass(frozen=True)
class SystemProfile:
    platform: str
    distro_id: str = ""
    distro_like: tuple[str, ...] = ()
    native_manager: str = ""
    immutable: bool = False

    def to_dict(self) -> Dict[str, object]:
        data = asdict(self)
        data["distro_like"] = list(self.distro_like)
        data["recommended_sources"] = recommended_sources(self)
        return data


def _read_os_release() -> Dict[str, str]:
    path = Path("/etc/os-release")
    if not path.exists():
        return {}
    values: Dict[str, str] = {}
    try:
        for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            values[key] = value.strip().strip('"').strip("'")
    except OSError:
        return {}
    return values


def _manager_from_linux_release(distro_id: str, distro_like: tuple[str, ...]) -> str:
    tokens = {distro_id, *distro_like}
    if tokens & {"arch", "manjaro", "endeavouros", "cachyos", "garuda"}:
        return "pacman"
    if tokens & {"debian", "ubuntu", "linuxmint", "pop", "elementary", "zorin"}:
        return "apt"
    if tokens & {"fedora", "rhel", "centos", "rocky", "almalinux", "nobara"}:
        return "dnf"
    if tokens & {"opensuse", "opensuse-leap", "opensuse-tumbleweed", "suse"}:
        return "zypper"
    if tokens & {"alpine"}:
        return "apk"

    # Unknown Linux distributions still get capability-based fallback detection.
    for manager, command in (
        ("pacman", "pacman"),
        ("apt", "apt-get"),
        ("dnf", "dnf"),
        ("zypper", "zypper"),
        ("apk", "apk"),
    ):
        if shutil.which(command):
            return manager
    return ""


def detect_system_profile() -> SystemProfile:
    if sys.platform == "win32":
        return SystemProfile(platform="windows", native_manager="winget" if shutil.which("winget") else "")

    if sys.platform == "darwin":
        return SystemProfile(platform="macos", native_manager="brew" if shutil.which("brew") else "")

    if not sys.platform.startswith("linux"):
        return SystemProfile(platform=sys.platform)

    release = _read_os_release()
    distro_id = release.get("ID", "").lower()
    distro_like = tuple(part.lower() for part in release.get("ID_LIKE", "").split() if part)
    immutable = bool(shutil.which("rpm-ostree")) or Path("/run/ostree-booted").exists()
    native_manager = _manager_from_linux_release(distro_id, distro_like)

    # Fedora Atomic desktops should prefer Flatpak. dnf may be unavailable or
    # unsuitable for host mutation, so do not advertise it as the native source.
    if immutable and native_manager == "dnf":
        native_manager = ""

    return SystemProfile(
        platform="linux",
        distro_id=distro_id,
        distro_like=distro_like,
        native_manager=native_manager,
        immutable=immutable,
    )


def recommended_sources(profile: Optional[SystemProfile] = None) -> List[str]:
    profile = profile or detect_system_profile()
    sources: List[str] = []

    if profile.native_manager:
        sources.append(profile.native_manager)

    if profile.platform == "linux":
        # Flatpak is the common desktop-app layer across distributions. The
        # bootstrap path can install it when absent.
        sources.append("flatpak")
        sources.append("appimage")
        if profile.native_manager == "pacman":
            sources.append("aur")
    elif profile.platform == "windows":
        if shutil.which("winget"):
            sources.append("winget")
    elif profile.platform == "macos":
        if shutil.which("brew"):
            sources.append("brew")

    # Stable de-duplication while preserving preference order.
    return list(dict.fromkeys(sources))


def source_is_relevant(source_id: str, profile: Optional[SystemProfile] = None) -> bool:
    profile = profile or detect_system_profile()
    source_id = source_id.replace("builtin.", "").lower()

    if source_id in {"github", "bitu"}:
        return True
    if profile.platform == "linux" and source_id in {"flatpak", "appimage"}:
        return True
    if profile.platform == "windows":
        return source_id in {"winget", "scoop", "chocolatey"}
    if profile.platform == "macos":
        return source_id == "brew"

    if source_id == "aur":
        return profile.native_manager == "pacman"
    return source_id == profile.native_manager
