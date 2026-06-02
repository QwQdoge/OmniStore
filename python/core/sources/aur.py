import asyncio
import aiohttp
import subprocess
import os
from typing import List, Dict, Any, Optional
from core.sources.base import UnifiedSource
from core.sources.utils import PrivilegeManager

class AurSource(UnifiedSource):
    def __init__(self, session: aiohttp.ClientSession, weight: float = 1.0):
        super().__init__(name="AUR", weight=weight)
        self.session = session
        self.api = "https://aur.archlinux.org/rpc/?v=5&type=search&arg="
        self.enabled = os.path.exists("/usr/bin/pacman") # AUR depends on pacman
        self.privilege = PrivilegeManager()

    async def _get_installed_aur_packages(self):
        try:
            proc = await asyncio.create_subprocess_exec(
                'pacman', '-Qm',
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            )
            stdout, _ = await proc.communicate()
            output = stdout.decode().strip()
            if not output:
                return set()
            return {line.split()[0] for line in output.splitlines() if line.strip()}
        except Exception:
            return set()

    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
        if not self.enabled:
            return []

        try:
            tasks = [
                self.session.get(f"{self.api}{query}", timeout=aiohttp.ClientTimeout(total=8)),
                self._get_installed_aur_packages()
            ]

            responses = await asyncio.gather(*tasks, return_exceptions=True)
            resp = responses[0]
            installed_set = responses[1] if not isinstance(responses[1], Exception) else set()

            if isinstance(resp, Exception) or not isinstance(resp, aiohttp.ClientResponse):
                return []

            data = await resp.json()
            aur_pkgs = data.get("results", [])

            final_results = []
            for pkg in aur_pkgs:
                name = pkg["Name"]
                is_installed = name in installed_set
                version = pkg.get("Version", "")

                final_results.append({
                    "name": name,
                    "last_version": version,
                    "source": "AUR",
                    "description": pkg.get("Description", "") or "",
                    "installed": is_installed,
                    "variants": [{
                        "source": "AUR",
                        "version": version,
                        "installed": is_installed
                    }]
                })
            return final_results
        except Exception:
            return []

    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        # Note: yay handles its own sudo, but for manual makepkg we might need it.
        # Also ensure_privileged caches the auth for other operations.
        if not await self.privilege.ensure_privileged(callback):
            return False

        name = package.get("name")
        # Prefer 'yay' for AUR
        helper = "yay" if os.path.exists("/usr/bin/yay") else "makepkg"

        if helper == "yay":
            if callback:
                await callback(f"[INFO] Running: yay -S --noconfirm {name}")
            proc = await asyncio.create_subprocess_exec(
                "yay", "-S", "--noconfirm", name,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT
            )
            if proc.stdout:
                while True:
                    line = await proc.stdout.readline()
                    if not line: break
                    if callback: await callback(line.decode().strip())
            await proc.wait()
            return proc.returncode == 0
        else:
            if callback:
                await callback("[ERROR] No AUR helper (like yay) found. Please install one.")
            return False

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        if not await self.privilege.ensure_privileged(callback):
            return False

        name = package.get("name")
        if callback:
            await callback(f"[INFO] Running: sudo pacman -Rs --noconfirm {name}")
        proc = await asyncio.create_subprocess_exec(
            "sudo", "pacman", "-Rs", "--noconfirm", name,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT
        )
        if proc.stdout:
            while True:
                line = await proc.stdout.readline()
                if not line: break
                if callback: await callback(line.decode().strip())
        await proc.wait()
        return proc.returncode == 0

    async def launch(self, package: Dict[str, Any]) -> bool:
        name = package.get("name")
        try:
            subprocess.Popen([name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        except Exception:
            return False

    async def locate(self, package: Dict[str, Any]) -> bool:
        name = package.get("name")
        try:
            proc = await asyncio.create_subprocess_exec("which", name, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
            stdout, _ = await proc.communicate()
            if proc.returncode == 0:
                binary_dir = os.path.dirname(stdout.decode().strip())
                subprocess.Popen(["xdg-open", binary_dir], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return True
        except Exception: pass
        return False

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        return {"name": package_id, "source": "AUR"}

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        return None
