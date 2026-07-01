import os
import logging
from typing import List, Dict, Any, Optional

def get_directory_size(path: str) -> int:
    """Calculates the total size of a directory in bytes."""
    total = 0
    try:
        for root, _, files in os.walk(path):
            for filename in files:
                try:
                    total += os.path.getsize(os.path.join(root, filename))
                except OSError:
                    pass
    except OSError:
        return 0
    return total

def format_bytes(size: Optional[int]) -> Optional[str]:
    """Formats bytes into human-readable string."""
    if not size:
        return None
    units = ["B", "KB", "MB", "GB", "TB"]
    value = float(size)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            return f"{value:.1f} {unit}" if unit != "B" else f"{int(value)} B"
        value /= 1024
    return f"{size} B"

async def scan_windows_unmanaged_installed(manager: Any = None) -> List[Dict[str, Any]]:
    """
    Murphy-proof: Scans Windows Registry for installed applications not managed by OmniStore.
    This logic is isolated for platform-specific safety.
    """
    import sys
    if sys.platform != "win32":
        return []

    try:
        import winreg
    except ImportError:
        return []

    roots = [
        (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
        (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"),
        (winreg.HKEY_CURRENT_USER, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
    ]

    managed_ids = set()
    if manager:
        for source in manager.sources.values():
            if source.name.lower() == "winget":
                try:
                    managed_ids = await source._get_installed_ids()
                except Exception:
                    managed_ids = set()
                break

    results: List[Dict[str, Any]] = []
    for root, path in roots:
        try:
            with winreg.OpenKey(root, path) as key:
                for index in range(winreg.QueryInfoKey(key)[0]):
                    try:
                        sub_name = winreg.EnumKey(key, index)
                        with winreg.OpenKey(key, sub_name) as subkey:
                            app = _read_windows_uninstall_entry(winreg, subkey, sub_name)
                            if not app:
                                continue
                            norm_id = str(app.get("id", "")).strip().lower().replace(" ", "")
                            if norm_id in managed_ids:
                                continue
                            results.append(app)
                    except OSError:
                        continue
        except OSError:
            continue
    return results

def _read_windows_uninstall_entry(winreg, key, fallback_id: str) -> Optional[Dict[str, Any]]:
    """Helper to read an individual registry entry."""
    def read(name, default=None):
        try:
            return winreg.QueryValueEx(key, name)[0]
        except OSError:
            return default

    display_name = read("DisplayName")
    if not display_name:
        return None

    system_component = read("SystemComponent", 0)
    if system_component == 1:
        return None

    estimated_kb = read("EstimatedSize")
    disk_size = int(estimated_kb) * 1024 if isinstance(estimated_kb, int) and estimated_kb > 0 else None
    install_location = read("InstallLocation") or ""

    if not disk_size and install_location and os.path.isdir(install_location):
        disk_size = get_directory_size(install_location)

    size_text = format_bytes(disk_size) if disk_size else None
    publisher = read("Publisher") or ""
    version = read("DisplayVersion") or "Unknown"
    uninstall_string = read("UninstallString")

    return {
        "name": str(display_name),
        "id": fallback_id,
        "primary_source": "UnmanagedWindows",
        "source": "UnmanagedWindows",
        "managed": False,
        "installed": True,
        "version": str(version),
        "developer": str(publisher),
        "description": "Windows installed application",
        "install_location": install_location,
        "uninstall_string": uninstall_string,
        "installed_size": size_text,
        "disk_size": disk_size,
        "size_confidence": "reported" if estimated_kb else ("estimated" if disk_size else "unknown"),
        "size_source": "Windows registry" if estimated_kb else ("filesystem scan" if disk_size else "unknown"),
        "variants": [{
            "source": "UnmanagedWindows",
            "id": fallback_id,
            "installed": True,
            "managed": False,
            "installed_size": size_text,
            "disk_size": disk_size,
            "size_confidence": "reported" if estimated_kb else ("estimated" if disk_size else "unknown"),
            "size_source": "Windows registry" if estimated_kb else ("filesystem scan" if disk_size else "unknown"),
        }],
    }
