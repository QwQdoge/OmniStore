import asyncio
from core.subprocess_utils import safe_subprocess
import subprocess
import os
import re
from typing import List, Dict, Any, Optional
from core.sources.base import UnifiedSource

class FlatpakSource(UnifiedSource):
    def __init__(self, weight: float = 1.0):
        super().__init__(name="Flatpak", weight=weight)
        self.enabled = os.path.exists("/usr/bin/flatpak")

    def config_schema(self) -> Dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "remotes": {
                    "type": "array",
                    "description": "Flatpak remotes to add or show.",
                    "items": {
                        "type": "object",
                        "properties": {
                            "name": {"type": "string"},
                            "url": {"type": "string"},
                            "user": {"type": "boolean", "default": True},
                        },
                        "required": ["name", "url"],
                    },
                }
            },
        }

    async def _get_installed_flatpaks(self) -> set:
        try:
            async with safe_subprocess(
                "flatpak", "list", "--installed", "--columns=application",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            ) as proc:
                stdout, _ = await proc.communicate()
                output = stdout.decode().strip()
                return {line.strip() for line in output.splitlines() if line.strip()}
        except Exception:
            return set()

    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None, **kwargs) -> List[Dict[str, Any]]:
        if not self.enabled:
            return []

        try:
            installed_task = kwargs.get("installed_flatpak_task")
            async with safe_subprocess(
                "flatpak", "search", "--columns=name,application,version,description", query,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            ) as proc:
                tasks: List[Any] = [proc.communicate()]
                if installed_task is None:
                    tasks.append(self._get_installed_flatpaks())
                else:
                    tasks.append(installed_task)

                results = await asyncio.gather(*tasks)
                stdout = results[0][0]
                installed_set = results[1]

                if not stdout:
                    return []

                lines = stdout.decode().strip().splitlines()
                final_results = []
                for line in lines:
                    if "Application ID" in line or "Name" in line:
                        continue
                    parts = [p.strip() for p in line.split("\t")]
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

    async def _ensure_flathub(self, callback=None):
        try:
            if callback:
                await callback("[INFO] Ensuring Flathub repository is configured...")
            async with safe_subprocess(
                "flatpak", "remote-add", "--if-not-exists", "--user",
                "flathub", "https://dl.flathub.org/repo/flathub.flatpakrepo",
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL
            ) as proc:
                await proc.wait()
        except Exception:
            pass

    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        callback = self._async_callback(callback)
        try:
            app_id = package.get("id") or package.get("name")
            if not app_id:
                if callback: await callback("[ERROR] Flatpak ID or name missing.")
                return False

            await self._ensure_flathub(callback)
            if callback:
                await callback(f"[INFO] Running: flatpak install --user -y flathub {app_id}")

            async with safe_subprocess(
                "flatpak", "install", "--user", "-y", "flathub", app_id,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT
            ) as proc:

                last_sent_progress = -1
                if proc.stdout:
                    while True:
                        line_bytes = await proc.stdout.readline()
                        if not line_bytes:
                            break
                        line = line_bytes.decode('utf-8', errors='ignore').strip()
                        if not line:
                            continue

                        if callback:
                            await callback(f"[INFO] {line}")

                            # Regex matching for progress percentage
                            # Format: Installing 3/8... 19% or [  19%]
                            summary_match = re.search(r"(\d+)/(\d+).*?(\d+)\s*%", line)
                            list_progress_match = re.search(r"\[\s*(\d+)%\s*\]", line)
                            speed_match = re.search(r"(\d+(\.\d+)?\s*(k|M|G)?B/s)", line)

                            total_prog = None
                            if summary_match:
                                cur, total, sub = map(int, summary_match.groups())
                                total_prog = int(((cur - 1) / total) * 100 + (sub / total))
                            elif list_progress_match:
                                total_prog = int(list_progress_match.group(1))

                            if speed_match:
                                await callback(f"[SPEED] {speed_match.group(1)}")

                            if total_prog is not None and total_prog > last_sent_progress:
                                await callback(f"[PROGRESS] {total_prog}")
                                last_sent_progress = total_prog

                await proc.wait()
                if proc.returncode == 0 and callback:
                    await callback("[PROGRESS] 100")
                return proc.returncode == 0
        except Exception as e:
            if callback: await callback(f"[ERROR] Flatpak installation failed: {e}")
            return False
        finally:
            if 'proc' in locals() and proc and proc.returncode is None:
                try:
                    proc.kill()
                    await proc.wait()
                except:
                    pass

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        callback = self._async_callback(callback)
        try:
            app_id = package.get("id") or package.get("name")
            if not app_id:
                if callback: await callback("[ERROR] Flatpak ID or name missing for uninstall.")
                return False

            if callback:
                await callback(f"[INFO] Running: flatpak uninstall --user -y {app_id}")

            async with safe_subprocess(
                "flatpak", "uninstall", "--user", "-y", app_id,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT
            ) as proc:
                if proc.stdout:
                    while True:
                        line = await proc.stdout.readline()
                        if not line:
                            break
                        if callback:
                            await callback(line.decode().strip())
                await proc.wait()
                return proc.returncode == 0
        except Exception as e:
            if callback: await callback(f"[ERROR] Flatpak uninstallation failed: {e}")
            return False

    async def launch(self, package: Dict[str, Any]) -> bool:
        app_id = package.get("id") or package.get("name")
        if not app_id:
            return False
        try:
            async with safe_subprocess("flatpak", "run", app_id, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL):
                return True
        except Exception:
            return False

    async def locate(self, package: Dict[str, Any]) -> bool:
        app_id = package.get("id") or package.get("name")
        if not app_id:
            return False
        try:
            user_path = os.path.expanduser(f"~/.local/share/flatpak/app/{app_id}")
            if os.path.exists(user_path):
                async with safe_subprocess("xdg-open", user_path, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL):
                    return True
            system_path = f"/var/lib/flatpak/app/{app_id}"
            if os.path.exists(system_path):
                async with safe_subprocess("xdg-open", system_path, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL):
                    return True
        except Exception:
            pass
        return False

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        return {"id": package_id, "source": "Flatpak"}

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        if not self.enabled or not package_id:
            return None
        try:
            async with safe_subprocess(
                "flatpak", "remote-ls", "--updates", "--columns=application,version",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL,
            ) as proc:
                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=20)
                for line in stdout.decode(errors="ignore").splitlines():
                    parts = [p.strip() for p in line.split("\t") if p.strip()]
                    if parts and parts[0] == package_id:
                        return {
                            "name": package_id,
                            "id": package_id,
                            "source": "Flatpak",
                            "current_version": "Installed",
                            "new_version": parts[1] if len(parts) > 1 else "Available",
                        }
        except Exception:
            return None
        return None

    async def list_installed(self) -> List[Dict[str, Any]]:
        """
        ⚡ Bolt: Optimized metadata retrieval by consolidating size information
        into a single subprocess call. Reduces O(N) subprocesses to O(1).
        """
        results: List[Dict[str, Any]] = []
        if not self.enabled:
            return results
        try:
            async with safe_subprocess(
                "flatpak", "list", "--app", "--columns=name,application,version,description,size",
                stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL
            ) as proc:
                stdout, _ = await proc.communicate()
                for line in stdout.decode(errors="ignore").splitlines():
                    parts = [p.strip() for p in line.split("\t")]
                    if len(parts) < 2:
                        continue

                    app_id = parts[1]
                    raw_size = parts[4] if len(parts) > 4 else None

                    # ⚡ Pre-construct size metadata to avoid redundant function calls
                    size_data = {
                        "download_size": None,
                        "installed_size": raw_size,
                        "disk_size": None,
                        "size_confidence": "reported" if raw_size else "unknown",
                        "size_source": "flatpak list",
                    }

                    results.append({
                        "name": parts[0],
                        "id": app_id,
                        "primary_source": "Flatpak",
                        "source": "Flatpak",
                        "managed": True,
                        "installed": True,
                        "version": parts[2] if len(parts) > 2 else "Unknown",
                        "description": parts[3] if len(parts) > 3 else f"Flatpak app {app_id}",
                        **size_data,
                        "variants": [{
                            "source": "Flatpak",
                            "id": app_id,
                            "installed": True,
                            "managed": True,
                            **size_data
                        }],
                    })
        except Exception:
            pass
        return results

    async def get_size(self, package: Dict[str, Any]) -> Dict[str, Any]:
        app_id = package.get("id") or package.get("name")
        if not app_id or not self.enabled:
            return await super().get_size(package)
        try:
            async with safe_subprocess("flatpak", "info", "--show-size", str(app_id), stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                stdout, _ = await proc.communicate()
                raw = stdout.decode(errors="ignore").strip()
                return {
                    "download_size": None,
                    "installed_size": raw or None,
                    "disk_size": None,
                    "size_confidence": "reported" if raw else "unknown",
                    "size_source": "flatpak info --show-size",
                }
        except Exception:
            return await super().get_size(package)
