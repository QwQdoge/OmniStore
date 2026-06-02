import asyncio
import subprocess
import os
from typing import List, Dict, Any, Optional
from core.sources.base import UnifiedSource

class FlatpakSource(UnifiedSource):
    def __init__(self, weight: float = 1.0):
        super().__init__(name="Flatpak", weight=weight)
        self.enabled = os.path.exists("/usr/bin/flatpak")

    async def _get_installed_flatpaks(self) -> set:
        try:
            proc = await asyncio.create_subprocess_exec(
                "flatpak", "list", "--installed", "--columns=application",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            )
            stdout, _ = await proc.communicate()
            output = stdout.decode().strip()
            return {line.strip() for line in output.splitlines() if line.strip()}
        except Exception:
            return set()

    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
        if not self.enabled:
            return []

        try:
            tasks = [
                asyncio.create_subprocess_exec(
                    "flatpak", "search", "--columns=name,application,version,description", query,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.DEVNULL
                ),
                self._get_installed_flatpaks()
            ]

            results = await asyncio.gather(*tasks)
            proc, installed_set = results
            stdout, _ = await proc.communicate()

            if not stdout:
                return []

            lines = stdout.decode().strip().splitlines()
            final_results = []

            for line in lines:
                if "Application ID" in line or "Name" in line:
                    continue

                parts = [p.strip() for p in line.split('\t')]
                if len(parts) < 2:
                    continue

                display_name = parts[0]
                app_id = parts[1]
                version = parts[2] if len(parts) > 2 else "Unknown"
                desc = parts[3] if len(parts) > 3 else f"Flatpak app {app_id}"

                final_results.append({
                    "id": app_id,
                    "name": display_name,
                    "last_version": version,
                    "source": "Flatpak",
                    "description": desc,
                    "installed": app_id in installed_set,
                    "variants": [{
                        "source": "Flatpak",
                        "id": app_id,
                        "version": version,
                        "installed": app_id in installed_set
                    }]
                })
            return final_results
        except Exception:
            return []

    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        app_id = package.get("id") or package.get("name")
        if callback:
            await callback(f"[INFO] Running: flatpak install --user -y flathub {app_id}")

        proc = await asyncio.create_subprocess_exec(
            "flatpak", "install", "--user", "-y", "flathub", app_id,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT
        )

        if proc.stdout:
            while True:
                line = await proc.stdout.readline()
                if not line:
                    break
                if callback:
                    await callback(line.decode().strip())

        await proc.wait()
        return proc.returncode == 0

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        app_id = package.get("id") or package.get("name")
        if callback:
            await callback(f"[INFO] Running: flatpak uninstall --user -y {app_id}")

        proc = await asyncio.create_subprocess_exec(
            "flatpak", "uninstall", "--user", "-y", app_id,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT
        )

        if proc.stdout:
            while True:
                line = await proc.stdout.readline()
                if not line:
                    break
                if callback:
                    await callback(line.decode().strip())

        await proc.wait()
        return proc.returncode == 0

    async def launch(self, package: Dict[str, Any]) -> bool:
        app_id = package.get("id") or package.get("name")
        try:
            subprocess.Popen(["flatpak", "run", app_id], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        except Exception:
            return False

    async def locate(self, package: Dict[str, Any]) -> bool:
        app_id = package.get("id") or package.get("name")
        # For Flatpak, we can open the app info or the export dir
        try:
            # Most user flatpaks are in ~/.local/share/flatpak/app/
            user_path = os.path.expanduser(f"~/.local/share/flatpak/app/{app_id}")
            if os.path.exists(user_path):
                subprocess.Popen(["xdg-open", user_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return True
            system_path = f"/var/lib/flatpak/app/{app_id}"
            if os.path.exists(system_path):
                subprocess.Popen(["xdg-open", system_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return True
        except Exception:
            pass
        return False

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        # Could use flathub API here
        return {"id": package_id, "source": "Flatpak"}

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        return None
