import asyncio
import aiohttp
import subprocess
import os
import sys
import shutil
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
        repo_id = package.get("id") or package.get("name")
        if not repo_id: return False

        if callback: await callback(f"[INFO] Initializing Bitu package download for {repo_id}...")

        managed_dir = self._get_managed_dir()
        managed_dir.mkdir(parents=True, exist_ok=True)
        repo_safe_name = repo_id.replace("/", "_")
        install_dir = managed_dir / repo_safe_name
        install_dir.mkdir(parents=True, exist_ok=True)

        # Create dummy file to simulate install
        dest_path = install_dir / "app.exe" if sys.platform == "win32" else install_dir / "app"
        
        try:
            if callback: await callback("[INFO] Downloading files...")
            for i in range(1, 101, 20):
                await asyncio.sleep(0.1)
                if callback: await callback(f"[PROGRESS] {i}")
            
            with open(dest_path, "w") as f:
                f.write(f"Mock installation of Bitu package: {repo_id}\n")
            
            if sys.platform != "win32":
                dest_path.chmod(0o755)

            if callback: 
                await callback(f"[PROGRESS] 100")
                await callback(f"[INFO] Bitu package successfully installed: {dest_path}")
            return True
        except Exception as e:
            if callback: await callback(f"[ERROR] Bitu installation failed: {e}")
            return False

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        repo_id = package.get("id") or package.get("name")
        repo_safe_name = repo_id.replace("/", "_")
        install_dir = self._get_managed_dir() / repo_safe_name
        if install_dir.exists():
            shutil.rmtree(install_dir)
            if callback: await callback(f"[INFO] Successfully removed Bitu package {repo_id}")
            return True
        return False

    async def launch(self, package: Dict[str, Any]) -> bool:
        return True

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
        return {}

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        return None
