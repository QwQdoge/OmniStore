import asyncio
import logging
import os
import shutil
import contextlib
import re
from typing import Dict, Any, Optional, Callable, Awaitable
from core.subprocess_utils import safe_subprocess
from core.sources.utils import PrivilegeManager

class InstallExecutor:
    """
    Orchestrates installation, uninstallation, and updates.
    Ensures mutual exclusion (state lock), robust error isolation, and
    proper subprocess lifecycle management to prevent zombie processes.
    """
    def __init__(self, backend):
        self.backend = backend
        self._global_lock = asyncio.Lock()
        # Murphy-proof: Granular per-package locks to prevent concurrent operations on the same app
        self._package_locks: Dict[str, asyncio.Lock] = {}
        self._package_lock_cleanup_task = None
        self.is_running = False
        self.privilege_manager = PrivilegeManager()
        # Start background cleanup for locks
        try:
            loop = asyncio.get_running_loop()
            self._package_lock_cleanup_task = loop.create_task(self._periodic_lock_cleanup())
        except RuntimeError:
            pass

    async def _periodic_lock_cleanup(self):
        """Murphy-proof: Periodically purge unused package locks to prevent slow memory growth."""
        while True:
            try:
                await asyncio.sleep(600)  # Every 10 minutes
                # Use a copy of keys to avoid 'dict changed size during iteration'
                for name in list(self._package_locks.keys()):
                    lock = self._package_locks.get(name)
                    if lock and not lock.locked():
                        # Minor optimization: only remove if it seems idle
                        # (there's a tiny race here, but _get_package_lock will just recreate it)
                        self._package_locks.pop(name, None)
            except asyncio.CancelledError:
                break
            except Exception:
                await asyncio.sleep(60)

    def _get_package_lock(self, pkg_name: str) -> asyncio.Lock:
        if pkg_name not in self._package_locks:
            self._package_locks[pkg_name] = asyncio.Lock()
        return self._package_locks[pkg_name]

    async def _ensure_privileged(self, callback) -> bool:
        """Centralized privilege escalation check."""
        return await self.privilege_manager.ensure_privileged(callback)

    async def install(self, package: Dict[str, Any], callback: Optional[Callable[[str], Awaitable[None]]]) -> bool:
        """Execute installation with state lock protection and fail-safe checks."""
        # 1. Parameter Validation & Sanitization (Pre-lock)
        pkg_name = package.get("name")
        if not package or not isinstance(pkg_name, str) or not pkg_name.strip():
            if callback: await callback("[ERROR] Invalid package data (missing name). Installation aborted.")
            return False

        # Boundary Defense: Prevent shell injection or malformed paths
        # Murphy-proof: include + and @ which are valid in package names (e.g., g++, @vue/cli)
        if not re.match(r'^[a-zA-Z0-9._/+@-]+$', pkg_name.strip()):
            if callback: await callback(f"[ERROR] Security: Package name '{pkg_name}' contains illegal characters.")
            return False

        # Murphy-proof: Acquire granular package lock first
        pkg_lock = self._get_package_lock(pkg_name.strip())
        async with pkg_lock:
            # Murphy-proof: Use a timeout for global lock acquisition to prevent permanent "Busy" state
            try:
                # We use the global lock to ensure we don't run two heavy operations (like two pacman instances) at once.
                # However, we only wait 5s to avoid UI feeling stuck if there's a minor contention.
                await asyncio.wait_for(self._global_lock.acquire(), timeout=5.0)
            except asyncio.TimeoutError:
                if callback: await callback(f"[ERROR] System is busy with another task. Please wait for it to complete.")
                return False

            try:
                url = package.get("url")
                if url:
                    # Murphy-proof URL validation
                    if not re.match(r'^[a-zA-Z0-9._/:\-?=&%+#]+$', url.strip()):
                        if callback: await callback("[ERROR] Security: URL contains illegal characters.")
                        return False
                    if any(c in url for c in ";|`$()<>\\"):
                        if callback: await callback("[ERROR] Security: Shell metacharacters detected in URL.")
                        return False

                # 2. Environment & Dependency Check
                source_name = str(package.get("source", "Native")).lower()
                if source_name == "native":
                    source_name = "pacman"
                if not self._check_environment(source_name):
                    if callback: await callback(f"[ERROR] Environment check failed for '{source_name}'. Ensure required tools (pacman/flatpak/yay) are installed.")
                    return False

                if not self.backend.manager or source_name not in self.backend.manager.sources:
                    if callback: await callback(f"[ERROR] Installation source '{source_name}' is currently unavailable.")
                    return False

                source = self.backend.manager.sources[source_name]

                try:
                    self.is_running = True
                    # 3. Execution with Strict Isolation
                    # Murphy-proof: Standard timeout for the entire installation process (60 minutes)
                    # This prevents zombie tasks from hanging the backend indefinitely.
                    success = await asyncio.wait_for(source.install(package, callback=callback), timeout=3600)
                    return bool(success)
                except asyncio.TimeoutError:
                    if callback: await callback("[ERROR] Installation timed out after 60 minutes. Task terminated for safety.")
                    return False
                except asyncio.CancelledError:
                    if callback: await callback("[INFO] Installation was cancelled by user.")
                    return False
                except Exception as e:
                    logging.exception(f"InstallExecutor.install failed: {e}")
                    if callback: await callback(f"[ERROR] Unexpected fatal error during installation: {str(e)}")
                    return False
                finally:
                    self.is_running = False
            finally:
                self._global_lock.release()

    async def uninstall(self, package: Dict[str, Any], callback: Optional[Callable[[str], Awaitable[None]]]) -> bool:
        """Execute uninstallation with state lock protection."""
        pkg_name = package.get("name")
        if not package or not pkg_name:
            if callback: await callback("[ERROR] Package name missing for uninstallation.")
            return False

        # Sanitization
        if not re.match(r'^[a-zA-Z0-9._/+@-]+$', pkg_name.strip()):
             if callback: await callback(f"[ERROR] Security: Package name '{pkg_name}' contains illegal characters.")
             return False

        pkg_lock = self._get_package_lock(pkg_name.strip())
        async with pkg_lock:
            try:
                await asyncio.wait_for(self._global_lock.acquire(), timeout=5.0)
            except asyncio.TimeoutError:
                if callback: await callback("[ERROR] System is busy. Please wait for the current task to finish.")
                return False

            try:
                source_name = str(package.get("source", "Native")).lower()
                if source_name == "native":
                    source_name = "pacman"
                if not self.backend.manager or source_name not in self.backend.manager.sources:
                    if callback: await callback(f"[ERROR] Uninstallation source '{source_name}' not found.")
                    return False

                source = self.backend.manager.sources[source_name]
                try:
                    self.is_running = True
                    success = await asyncio.wait_for(source.uninstall(package, callback=callback), timeout=1800)
                    return bool(success)
                except asyncio.TimeoutError:
                    if callback: await callback("[ERROR] Uninstallation timed out after 30 minutes.")
                    return False
                except Exception as e:
                    logging.exception(f"InstallExecutor.uninstall fail: {e}")
                    if callback: await callback(f"[ERROR] Uninstallation failed due to an internal error: {e}")
                    return False
                finally:
                    self.is_running = False
            finally:
                self._global_lock.release()

    async def update(self, package: Dict[str, Any], callback: Optional[Callable[[str], Awaitable[None]]]) -> bool:
        """Update logic (often proxies to install)."""
        return await self.install(package, callback)

    def _check_environment(self, source_name: str) -> bool:
        """Verify that the required system tools exist and are executable for the given source."""
        import sys
        is_linux = sys.platform.startswith("linux")

        def is_exe(name):
            path = shutil.which(name)
            if path is None:
                logging.warning(f"Murphy-proof Check: Binary '{name}' not found in PATH.")
                return False
            if not os.access(path, os.X_OK):
                logging.warning(f"Murphy-proof Check: Binary '{path}' found but not executable.")
                return False
            return True

        # Foolproof: Block Linux-specific sources on other platforms
        if not is_linux and source_name in ("native", "pacman", "aur", "flatpak"):
            logging.error(f"Foolproof: Source '{source_name}' is Linux-only. Current platform: {sys.platform}")
            return False

        # Murphy-proof: Check for sudo if on Linux, as most installs need it
        if is_linux and not is_exe("sudo"):
             logging.error("Murphy-proof: 'sudo' not found. Privileged operations will fail.")
             return False

        if source_name in ("native", "pacman"):
            return is_exe("pacman")
        elif source_name == "flatpak":
            return is_exe("flatpak")
        elif source_name == "aur":
            # AUR is special: try yay first, then paru
            return is_exe("yay") or is_exe("paru")
        elif source_name == "appimage":
            # For AppImage, we need at least basic fuse/mount tools or just check if we can run things
            return True

        return True

    def stop(self):
        """Emergency stop sequence."""
        self.is_running = False
        if self._package_lock_cleanup_task:
            self._package_lock_cleanup_task.cancel()
        # Note: Actual process termination is handled by the signal handlers in main.py
        # and the specific source implementations which should check is_running.
