"""Hand desktop applications to the session, independently of backend lifetime."""
import asyncio
import os
from pathlib import Path
import shutil
import subprocess

from core.subprocess_utils import safe_subprocess

_children = []


async def launch_detached(*arguments: str) -> bool:
    if not arguments or not arguments[0]:
        return False
    try:
        _children[:] = [child for child in _children if child.poll() is None]
        options = {"start_new_session": True} if os.name == "posix" else {}
        process = subprocess.Popen(arguments, stdin=subprocess.DEVNULL,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                   **options)
        _children.append(process)
        # Detect immediate launcher failures without waiting for the app to close.
        await asyncio.sleep(0.2)
        return process.poll() in (None, 0)
    except (OSError, ValueError):
        return False


async def native_package_files(package_id: str) -> list[Path]:
    if not package_id or package_id.startswith("-"):
        return []
    try:
        async with safe_subprocess("pacman", "-Qlq", "--", package_id,
                                   stdout=asyncio.subprocess.PIPE,
                                   stderr=asyncio.subprocess.DEVNULL) as process:
            stdout, _ = await process.communicate()
            if process.returncode == 0:
                return [Path(line) for line in stdout.decode(errors="replace").splitlines()]
    except OSError:
        pass
    return []


async def launch_native_package(package_id: str) -> bool:
    files = await native_package_files(package_id)
    desktop_files = sorted(path for path in files
                           if path.suffix == ".desktop" and "applications" in path.parts
                           and path.is_file())
    for path in desktop_files:
        try:
            # The desktop launcher handles Exec field codes, DBus activation and
            # terminal apps. Never interpret a desktop Exec line as shell code.
            from configparser import ConfigParser
            entry = ConfigParser(interpolation=None, strict=False)
            entry.read(path, encoding="utf-8")
            section = entry["Desktop Entry"]
            if section.get("Type") != "Application" or section.getboolean("Hidden", fallback=False):
                continue
            if shutil.which("gio") and await launch_detached("gio", "launch", str(path)):
                return True
        except (OSError, ValueError, KeyError):
            continue
    # Only launch an executable actually owned by the requested package.
    executable = next((path for path in files if path.parent == Path("/usr/bin")
                       and path.name == package_id and os.access(path, os.X_OK)), None)
    return await launch_detached(str(executable)) if executable else False


async def locate_native_package(package_id: str) -> bool:
    files = await native_package_files(package_id)
    target = next((path.parent for path in files if path.suffix == ".desktop"
                   and "applications" in path.parts and path.is_file()), None)
    if target is None:
        target = next((path.parent for path in files if path.is_file()), None)
    return await launch_detached("xdg-open", str(target)) if target else False
