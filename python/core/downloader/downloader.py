import asyncio
import logging
import os
import shutil
import contextlib
from typing import Dict, Any, Optional, Callable, Awaitable
from core.sources.utils import PrivilegeManager

class InstallExecutor:
    """
    Orchestrates installation, uninstallation, and updates.
    Ensures mutual exclusion (state lock), robust error isolation, and
    proper subprocess lifecycle management to prevent zombie processes.
    """
    @staticmethod
    @contextlib.asynccontextmanager
    async def safe_subprocess(*args, **kwargs):
        """Murphy-proof subprocess wrapper that guarantees absolute cleanup and reaping."""
        proc = None
        try:
            proc = await asyncio.create_subprocess_exec(*args, **kwargs)
            yield proc
        finally:
            if proc:
                try:
                    if proc.returncode is None:
                        # Attempt graceful termination (SIGTERM)
                        proc.terminate()
                        try:
                            await asyncio.wait_for(proc.wait(), timeout=3)
                        except asyncio.TimeoutError:
                            # Escalation: Force kill (SIGKILL)
                            proc.kill()
                            await proc.wait()
                except Exception as e:
                    logging.error(f"Murphy-proof Error Reaping Subprocess: {e}")

    def __init__(self, backend):
        self.backend = backend
        self._lock = asyncio.Lock()
        self.is_running = False
        self.privilege_manager = PrivilegeManager()

    async def _ensure_privileged(self, callback) -> bool:
        """Centralized privilege escalation check."""
        return await self.privilege_manager.ensure_privileged(callback)

    async def install(self, package: Dict[str, Any], callback: Optional[Callable[[str], Awaitable[None]]]) -> bool:
        """Execute installation with state lock protection and fail-safe checks."""
        if self._lock.locked():
            if callback: await callback("[ERROR] Another system task is already in progress. Concurrent operations are blocked to prevent database corruption.")
            return False

        async with self._lock:
            # 1. Parameter Validation
            if not package or not isinstance(package.get("name"), str) or not package["name"].strip():
                if callback: await callback("[ERROR] Invalid package data. Installation aborted.")
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
                # We wrap the source call in a timeout-aware pattern if appropriate,
                # though most install tasks are long-running and managed internally by sources.
                success = await source.install(package, callback=callback)
                return bool(success)
            except asyncio.CancelledError:
                if callback: await callback("[INFO] Installation was cancelled by user.")
                return False
            except Exception as e:
                logging.exception(f"InstallExecutor.install failed: {e}")
                if callback: await callback(f"[ERROR] Unexpected fatal error during installation: {str(e)}")
                return False
            finally:
                self.is_running = False

    async def uninstall(self, package: Dict[str, Any], callback: Optional[Callable[[str], Awaitable[None]]]) -> bool:
        """Execute uninstallation with state lock protection."""
        if self._lock.locked():
            if callback: await callback("[ERROR] System is busy. Please wait for the current task to finish.")
            return False

        async with self._lock:
            if not package or not package.get("name"):
                if callback: await callback("[ERROR] Package name missing for uninstallation.")
                return False

            source_name = str(package.get("source", "Native")).lower()
            if source_name == "native":
                source_name = "pacman"
            if not self.backend.manager or source_name not in self.backend.manager.sources:
                if callback: await callback(f"[ERROR] Uninstallation source '{source_name}' not found.")
                return False

            source = self.backend.manager.sources[source_name]
            try:
                self.is_running = True
                success = await source.uninstall(package, callback=callback)
                return bool(success)
            except Exception as e:
                logging.exception(f"InstallExecutor.uninstall fail: {e}")
                if callback: await callback(f"[ERROR] Uninstallation failed due to an internal error: {e}")
                return False
            finally:
                self.is_running = False

    async def update(self, package: Dict[str, Any], callback: Optional[Callable[[str], Awaitable[None]]]) -> bool:
        """Update logic (often proxies to install)."""
        return await self.install(package, callback)

    def _check_environment(self, source_name: str) -> bool:
        """Verify that the required system tools exist and are executable for the given source."""
        def is_exe(name):
            path = shutil.which(name)
            if path is None:
                logging.warning(f"Murphy-proof Check: Binary '{name}' not found in PATH.")
                return False
            if not os.access(path, os.X_OK):
                logging.warning(f"Murphy-proof Check: Binary '{path}' found but not executable.")
                return False
            return True

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
        # Note: Actual process termination is handled by the signal handlers in main.py
        # and the specific source implementations which should check is_running.
