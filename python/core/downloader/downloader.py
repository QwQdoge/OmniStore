import asyncio
import logging
from typing import Dict, Any, Optional

class InstallExecutor:
    """
    Orchestrates installation, uninstallation, and updates.
    Ensures mutual exclusion (state lock) and robust error isolation.
    """
    def __init__(self, backend):
        self.backend = backend
        self._lock = asyncio.Lock()
        self.is_running = False  # Keep for backward compatibility/UI visibility

    async def install(self, package: Dict[str, Any], callback) -> bool:
        """Execute installation with state lock protection."""
        if self._lock.locked():
            if callback: await callback("[ERROR] Another task is already in progress. Please wait for completion.")
            return False

        async with self._lock:
            # Robust input check
            if not package or not package.get("name"):
                if callback: await callback("[ERROR] Invalid package data provided for installation.")
                return False

            source_name = str(package.get("source", "")).lower()
            if not self.backend.manager or source_name not in self.backend.manager.sources:
                if callback: await callback(f"[ERROR] Installation source '{source_name}' is unavailable or not supported.")
                return False

            source = self.backend.manager.sources[source_name]
            try:
                self.is_running = True
                # Defensive wrapper for source-specific implementation
                success = await source.install(package, callback=callback)
                return bool(success)
            except Exception as e:
                logging.exception(f"InstallExecutor.install fail: {e}")
                if callback: await callback(f"[ERROR] Unexpected failure during installation: {e}")
                return False
            finally:
                # Absolute state reset to prevent permanent lock
                self.is_running = False

    async def uninstall(self, package: Dict[str, Any], callback) -> bool:
        """Execute uninstallation with state lock protection."""
        if self._lock.locked():
            if callback: await callback("[ERROR] System is currently busy with another operation.")
            return False

        async with self._lock:
            if not package or not package.get("name"):
                if callback: await callback("[ERROR] Invalid package data provided for uninstallation.")
                return False

            source_name = str(package.get("source", "")).lower()
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
                if callback: await callback(f"[ERROR] Unexpected failure during uninstallation: {e}")
                return False
            finally:
                # Absolute state reset to prevent permanent lock
                self.is_running = False

    async def update(self, package: Dict[str, Any], callback) -> bool:
        # For simplicity, many sources use install to update
        return await self.install(package, callback)

    def stop(self):
        """Emergency stop: reset state."""
        self.is_running = False
        if self._lock.locked():
            try:
                # Force release if possible, or just log
                # asyncio.Lock doesn't have a direct 'force release' from outside,
                # but we signal components to stop.
                pass
            except: pass
