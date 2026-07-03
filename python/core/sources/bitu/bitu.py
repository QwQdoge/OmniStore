import asyncio
import aiohttp
import subprocess
import os
import sys
import shutil
import zipfile
from urllib.parse import urlparse
from urllib.request import url2pathname
from pathlib import Path
from typing import List, Dict, Any, Optional
from core.sources.base import UnifiedSource

class BituSource(UnifiedSource):
    def __init__(self, session: aiohttp.ClientSession, config_manager: Any, weight: float = 0.5):
        super().__init__(name="Bitu", weight=weight)
        self.cm = config_manager
        self.session = session
        self.api_base = "https://api.bitbucket.org/2.0"
        self.headers = {"User-Agent": "Omnistore/0.1"}

    def _get_managed_dir(self) -> Path:
        if sys.platform == "win32":
            return Path(os.environ.get("LOCALAPPDATA", os.path.expanduser("~"))) / "OmniStore" / "bitu"
        elif sys.platform == "darwin":
            return Path.home() / "Library" / "Application Support" / "OmniStore" / "bitu"
        else:
            return Path.home() / ".local" / "share" / "omnistore" / "bitu"

    def _is_installed(self, repo_id: str) -> bool:
        repo_safe_name = repo_id.replace("/", "_")
        return (self._get_managed_dir() / repo_safe_name).exists()

    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None, **kwargs) -> List[Dict[str, Any]]:
        # Query Bitbucket repositories search endpoint
        url = f"{self.api_base}/repositories?q=name~\"{query}\""
        try:
            async with self.session.get(url, headers=self.headers, timeout=aiohttp.ClientTimeout(total=10)) as resp:
                if resp.status != 200:
                    return []
                data = await resp.json()
                repos = data.get("values", [])
        except Exception:
            repos = []

        results = []
        for repo in repos:
            full_name = repo.get("full_name") or f"{repo.get('workspace', {}).get('slug')}/{repo.get('slug')}"
            is_inst = self._is_installed(full_name)
            
            results.append({
                "name": repo.get("name"),
                "id": full_name,
                "description": repo.get("description", ""),
                "source": "Bitu",
                "stars": 0, # Bitbucket API v2 does not expose stars directly on this endpoint
                "icon": repo.get("links", {}).get("avatar", {}).get("href"),
                "url": repo.get("links", {}).get("html", {}).get("href"),
                "installed": is_inst,
                "variants": [{
                    "source": "Bitu",
                    "id": full_name,
                    "installed": is_inst
                }]
            })
        return results

    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        callback = self._async_callback(callback)
        repo_id = package.get("id") or package.get("name")
        if not repo_id: return False

        if callback: await callback(f"[INFO] Initializing Bitu package download for {repo_id}...")

        managed_dir = self._get_managed_dir()
        managed_dir.mkdir(parents=True, exist_ok=True)
        repo_safe_name = repo_id.replace("/", "_")
        install_dir = managed_dir / repo_safe_name
        install_dir.mkdir(parents=True, exist_ok=True)

        archive_url = package.get("download_url") or package.get("url") or f"https://bitbucket.org/{repo_id}/get/HEAD.zip"
        if "bitbucket.org" in archive_url and not archive_url.endswith(".zip"):
            archive_url = f"https://bitbucket.org/{repo_id}/get/HEAD.zip"
        archive_path = install_dir / "source.zip"

        try:
            if callback: await callback(f"[INFO] Downloading repository archive: {archive_url}")
            parsed = urlparse(archive_url)
            if parsed.scheme == "file":
                shutil.copy2(Path(url2pathname(parsed.path)), archive_path)
                if callback:
                    await callback("[PROGRESS] 80")
            elif parsed.scheme == "" and Path(archive_url).exists():
                shutil.copy2(Path(archive_url), archive_path)
                if callback:
                    await callback("[PROGRESS] 80")
            else:
                async with self.session.get(archive_url, headers=self.headers) as resp:
                    if resp.status != 200:
                        if callback: await callback(f"[ERROR] Bitbucket archive download failed: HTTP {resp.status}")
                        return False
                    total = int(resp.headers.get("content-length", 0))
                    downloaded = 0
                    with open(archive_path, "wb") as f:
                        async for chunk in resp.content.iter_chunked(8192):
                            f.write(chunk)
                            downloaded += len(chunk)
                            if callback and total:
                                await callback(f"[PROGRESS] {min(99, int(downloaded / total * 80))}")

            if callback: await callback("[INFO] Extracting repository archive...")
            with zipfile.ZipFile(archive_path) as archive:
                archive.extractall(install_dir)
            archive_path.unlink(missing_ok=True)

            if callback: 
                await callback(f"[PROGRESS] 100")
                await callback(f"[INFO] Bitu package successfully installed: {install_dir}")
            return True
        except Exception as e:
            try:
                archive_path.unlink(missing_ok=True)
            except Exception:
                pass
            if callback: await callback(f"[ERROR] Bitu installation failed: {e}")
            return False

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        callback = self._async_callback(callback)
        repo_id = package.get("id") or package.get("name")
        repo_safe_name = repo_id.replace("/", "_")
        install_dir = self._get_managed_dir() / repo_safe_name
        if install_dir.exists():
            shutil.rmtree(install_dir)
            if callback: await callback(f"[INFO] Successfully removed Bitu package {repo_id}")
            return True
        return False

    async def launch(self, package: Dict[str, Any]) -> bool:
        repo_id = package.get("id") or package.get("name")
        if not repo_id:
            return False
        install_dir = self._get_managed_dir() / str(repo_id).replace("/", "_")
        if not install_dir.exists():
            return False
        candidates = [p for p in install_dir.rglob("*") if p.is_file()]
        executable = next((p for p in candidates if p.suffix.lower() in {".exe", ".appimage", ".app"}), None)
        executable = executable or next((p for p in candidates if os.access(p, os.X_OK)), None)
        target = executable or install_dir
        open_cmd = "explorer" if sys.platform == "win32" and target.is_dir() else ("open" if sys.platform == "darwin" and target.is_dir() else "xdg-open" if target.is_dir() else str(target))
        try:
            from core.subprocess_utils import safe_subprocess
            if target.is_dir():
                async with safe_subprocess(open_cmd, str(target), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL):
                    return True
            async with safe_subprocess(str(target), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL):
                return True
        except Exception:
            return False

    async def locate(self, package: Dict[str, Any]) -> bool:
        repo_id = package.get("id") or package.get("name")
        if not repo_id: return False
        repo_safe_name = repo_id.replace("/", "_")
        install_dir = self._get_managed_dir() / repo_safe_name
        
        if install_dir.exists():
            open_cmd = "explorer" if sys.platform == "win32" else ("open" if sys.platform == "darwin" else "xdg-open")
            from core.subprocess_utils import safe_subprocess
            async with safe_subprocess(open_cmd, str(install_dir), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL):
                return True
        return False

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        url = f"{self.api_base}/repositories/{package_id}"
        try:
            async with self.session.get(url, headers=self.headers) as resp:
                if resp.status == 200:
                    repo = await resp.json()
                    full_name = repo.get("full_name") or f"{repo.get('workspace', {}).get('slug')}/{repo.get('slug')}"
                    return {
                        "name": repo.get("name"),
                        "id": full_name,
                        "description": repo.get("description", ""),
                        "updated_at": repo.get("updated_on"),
                        "license": repo.get("license")
                    }
        except Exception:
            pass
        return {
            "name": package_id.split("/")[-1],
            "id": package_id,
            "description": f"Bitu repository {package_id}",
            "source": "Bitu",
            "primary_source": "Bitu",
            "variants": [{"source": "Bitu", "id": package_id, "installed": self._is_installed(package_id)}],
        }

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        return None

    async def list_installed(self) -> List[Dict[str, Any]]:
        managed_dir = self._get_managed_dir()
        if not managed_dir.exists():
            return []
        results: List[Dict[str, Any]] = []
        for install_dir in sorted(p for p in managed_dir.iterdir() if p.is_dir()):
            repo_id = install_dir.name.replace("_", "/")
            size = await self.get_size({"id": repo_id})
            results.append({
                "name": repo_id.split("/")[-1],
                "id": repo_id,
                "primary_source": "Bitu",
                "source": "Bitu",
                "managed": True,
                "installed": True,
                "description": f"Bitu package {repo_id}",
                "version": "Local",
                **size,
                "variants": [{"source": "Bitu", "id": repo_id, "installed": True, "managed": True, **size}],
            })
        return results

    async def get_size(self, package: Dict[str, Any]) -> Dict[str, Any]:
        repo_id = package.get("id") or package.get("name")
        if not repo_id:
            return await super().get_size(package)
        install_dir = self._get_managed_dir() / str(repo_id).replace("/", "_")
        total = self._directory_size(install_dir)
        return {
            "download_size": package.get("download_size"),
            "installed_size": self._format_bytes(total) if total else None,
            "disk_size": total or None,
            "size_confidence": "estimated" if total else "unknown",
            "size_source": "filesystem scan",
        }

    def _directory_size(self, path: Path) -> int:
        if not path.exists():
            return 0
        total = 0
        for file_path in path.rglob("*"):
            try:
                if file_path.is_file():
                    total += file_path.stat().st_size
            except OSError:
                pass
        return total

    def _format_bytes(self, size: int) -> str:
        units = ["B", "KB", "MB", "GB", "TB"]
        value = float(size)
        for unit in units:
            if value < 1024 or unit == units[-1]:
                return f"{value:.1f} {unit}" if unit != "B" else f"{int(value)} B"
            value /= 1024
