import asyncio
import os
from typing import Dict, Any, Optional

class InstallExecutor:
    def __init__(self, backend):
        self.backend = backend
        self.is_running = False

    async def install(self, package: Dict[str, Any], callback) -> bool:
        if self.is_running:
            if callback: await callback("[ERROR] Another task is already in progress.")
            return False

        source_name = package.get("source", "").lower()
        if source_name not in self.backend.manager.sources:
            if callback: await callback(f"[ERROR] Source {source_name} not found.")
            return False

        source = self.backend.manager.sources[source_name]
        try:
            self.is_running = True
            return await source.install(package, callback=callback)
        finally:
            self.is_running = False

    async def uninstall(self, package: Dict[str, Any], callback) -> bool:
        if self.is_running:
            if callback: await callback("[ERROR] System is busy.")
            return False

        source_name = package.get("source", "").lower()
        if source_name not in self.backend.manager.sources:
            if callback: await callback(f"[ERROR] Source {source_name} not found.")
            return False

        source = self.backend.manager.sources[source_name]
        try:
            self.is_running = True
            return await source.uninstall(package, callback=callback)
        finally:
            self.is_running = False

    async def update(self, package: Dict[str, Any], callback) -> bool:
        # For simplicity, many sources use install to update
        return await self.install(package, callback)

    def stop(self):
        # Emergency stop logic (pkill or signal)
        self.is_running = False
