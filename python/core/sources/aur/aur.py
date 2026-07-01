import asyncio
from core.subprocess_utils import safe_subprocess
import aiohttp
import subprocess
import os
import re
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
            async with safe_subprocess(
                'pacman', '-Qmq',
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            ) as proc:
                stdout, _ = await proc.communicate()
                output = stdout.decode().strip()
                if not output:
                    return set()
                return {line.split()[0] for line in output.splitlines() if line.strip()}
        except Exception:
            return set()

    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None, **kwargs) -> List[Dict[str, Any]]:
        if not self.enabled:
            return []

        try:
            installed_task = kwargs.get("installed_aur_task")

            tasks: List[Any] = [
                self.session.get(f"{self.api}{query}", timeout=aiohttp.ClientTimeout(total=8))
            ]
            if installed_task is None:
                tasks.append(self._get_installed_aur_packages())
            else:
                tasks.append(installed_task)

            responses = await asyncio.gather(*tasks, return_exceptions=True)
            resp = responses[0]

            installed_set = responses[1] if len(responses) > 1 and not isinstance(responses[1], Exception) else set()

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
        try:
            if not await self.privilege.ensure_privileged(callback):
                return False

            name = package.get("name")
            if not name:
                if callback: await callback("[ERROR] AUR package name missing.")
                return False

            helper = "yay" if os.path.exists("/usr/bin/yay") else "makepkg"

            if helper == "yay":
                if callback:
                    await callback(f"[INFO] Running: yay -S --noconfirm {name}")
                async with safe_subprocess(
                    "yay", "-S", "--noconfirm", name,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.STDOUT
                ) as proc:
                    last_sent_progress = -1
                    if proc.stdout:
                        while True:
                            line_bytes = await proc.stdout.readline()
                            if not line_bytes: break
                            line = line_bytes.decode('utf-8', errors='ignore').strip()
                            if not line: continue

                            if callback:
                                await callback(f"[INFO] {line}")

                                # Parse yay/pacman download progress & speed
                                progress_match = re.search(r"(\d+)%", line)
                                speed_match = re.search(r"(\d+(\.\d+)?\s*(k|M|G)?i?B/s)", line)

                                if progress_match:
                                    percent = int(progress_match.group(1))
                                    if percent > last_sent_progress:
                                        await callback(f"[PROGRESS] {percent}")
                                        last_sent_progress = percent
                                if speed_match:
                                    await callback(f"[SPEED] {speed_match.group(1)}")

                    await proc.wait()
                    if proc.returncode == 0 and callback:
                        await callback("[PROGRESS] 100")
                    return proc.returncode == 0
            else:
                if callback:
                    await callback("[ERROR] No AUR helper (like yay) found. Please install one.")
                return False
        except Exception as e:
            if callback: await callback(f"[ERROR] AUR installation failed: {e}")
            return False


    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        try:
            if not await self.privilege.ensure_privileged(callback):
                return False

            name = package.get("name")
            if not name:
                if callback: await callback("[ERROR] AUR package name missing for uninstall.")
                return False

            if callback:
                await callback(f"[INFO] Running: sudo pacman -Rs --noconfirm {name}")
            async with safe_subprocess(
                "sudo", "pacman", "-Rs", "--noconfirm", name,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT
            ) as proc:

                last_sent_progress = -1
                if proc.stdout:
                    while True:
                        line_bytes = await proc.stdout.readline()
                        if not line_bytes: break
                        line = line_bytes.decode('utf-8', errors='ignore').strip()
                        if not line: continue

                        if callback:
                            await callback(f"[INFO] {line}")

                            # Parse pacman progress
                            progress_match = re.search(r"(\d+)%", line)
                            if progress_match:
                                percent = int(progress_match.group(1))
                                if percent > last_sent_progress:
                                    await callback(f"[PROGRESS] {percent}")
                                    last_sent_progress = percent

                await proc.wait()
                if proc.returncode == 0 and callback:
                    await callback("[PROGRESS] 100")
                return proc.returncode == 0
        except Exception as e:
            if callback:
                await callback(f"[ERROR] AUR uninstall failed: {e}")
            return False

    async def launch(self, package: Dict[str, Any]) -> bool:
        name = package.get("name")
        if not name:
            return False
        try:
            async with safe_subprocess(name, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) as proc:
                # We don't wait for completion here as we want to just fire and forget the app
                return True
        except Exception:
            return False

    async def locate(self, package: Dict[str, Any]) -> bool:
        name = package.get("name")
        if not name:
            return False
        try:
            async with safe_subprocess("which", name, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                stdout, _ = await proc.communicate()
                if proc.returncode == 0:
                    binary_dir = os.path.dirname(stdout.decode().strip())
                    async with safe_subprocess("xdg-open", binary_dir, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL):
                        return True
        except Exception: pass
        return False

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        return {"name": package_id, "source": "AUR"}

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        return None

    async def list_installed(self) -> List[Dict[str, Any]]:
        installed = await self._get_installed_aur_packages()
        results: List[Dict[str, Any]] = []
        for name in sorted(installed):
            size = await self.get_size({"name": name, "id": name})
            results.append({
                "name": name,
                "id": name,
                "primary_source": "AUR",
                "source": "AUR",
                "managed": True,
                "installed": True,
                "description": "AUR package",
                "version": "Local",
                **size,
                "variants": [{"source": "AUR", "id": name, "installed": True, "managed": True, **size}],
            })
        return results

    async def get_size(self, package: Dict[str, Any]) -> Dict[str, Any]:
        name = package.get("id") or package.get("name")
        helper = "yay" if os.path.exists("/usr/bin/yay") else ("paru" if os.path.exists("/usr/bin/paru") else "")
        if not name or not helper:
            return await super().get_size(package)
        try:
            async with safe_subprocess(helper, "-Qi", str(name), stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL, env={**os.environ, "LC_ALL": "C"}) as proc:
                stdout, _ = await proc.communicate()
                info = stdout.decode(errors="ignore")
                installed_size = None
                for line in info.splitlines():
                    if line.startswith("Installed Size"):
                        installed_size = line.split(":", 1)[1].strip()
                        break
                return {
                    "download_size": None,
                    "installed_size": installed_size,
                    "disk_size": None,
                    "size_confidence": "reported" if installed_size else "unknown",
                    "size_source": f"{helper} -Qi",
                }
        except Exception:
            return await super().get_size(package)
