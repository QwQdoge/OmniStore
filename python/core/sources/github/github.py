import asyncio
import aiohttp
import subprocess
import os
import sys
import re
from pathlib import Path
from typing import List, Dict, Any, Optional
from core.sources.base import UnifiedSource
from ..git_forges.github import GitHubForge
from ..git_forges.matcher import AssetMatcher

class GitHubSource(UnifiedSource):
    def __init__(self, session: aiohttp.ClientSession, config_manager: Any, weight: float = 0.5):
        super().__init__(name="GitHub", weight=weight)
        self.cm = config_manager
        self.forge = GitHubForge(session)
        self.session = session

        # Apply PAT if available
        pat = self.cm.get("github_store.pat")
        if pat:
            self.forge.headers["Authorization"] = f"token {pat}"

    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None, **kwargs) -> List[Dict[str, Any]]:
        if "/" in query and len(query.split("/")) == 2:
            repos = await self._get_repo_as_package(query)
        else:
            # Handle advanced filters in query or via separate dict
            sort = (filters or {}).get("sort", "stars")
            order = (filters or {}).get("order", "desc")
            # GitHub API uses 'page' parameter
            repos = await self.forge.search_repositories(query, sort=sort, order=order)

        results = []
        for repo in repos:
            results.append({
                "name": repo["name"],
                "id": repo["full_name"],
                "description": repo.get("description", ""),
                "source": "GitHub",
                "stars": repo.get("stargazers_count", 0),
                "icon": repo.get("owner", {}).get("avatar_url"),
                "url": repo["html_url"],
                "installed": self._is_installed(repo["full_name"]),
                "variants": [{
                    "source": "GitHub",
                    "id": repo["full_name"],
                    "installed": self._is_installed(repo["full_name"])
                }]
            })
        return results

    async def _get_repo_as_package(self, repo_full_name: str) -> List[Dict[str, Any]]:
        repo_url = f"https://api.github.com/repos/{repo_full_name}"
        try:
            async with self.session.get(repo_url, headers=self.forge.headers) as resp:
                if resp.status != 200: return []
                repo = await resp.json()
                return [{
                    "name": repo["name"],
                    "id": repo["full_name"],
                    "description": repo.get("description", ""),
                    "source": "GitHub",
                    "stars": repo.get("stargazers_count", 0),
                    "icon": repo.get("owner", {}).get("avatar_url"),
                    "url": repo["html_url"],
                    "installed": self._is_installed(repo["full_name"]),
                    "variants": [{
                        "source": "GitHub",
                        "id": repo["full_name"],
                        "installed": self._is_installed(repo["full_name"])
                    }]
                }]
        except Exception:
            return []

    def _is_installed(self, repo_id: str) -> bool:
        # Check if we have a metadata file or the binary in our managed folder
        managed_dir = Path.home() / ".local/share/omnistore/github"
        repo_safe_name = repo_id.replace("/", "_")
        return (managed_dir / repo_safe_name).exists()

    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        repo_id = package.get("id")
        if not repo_id: return False

        if callback: await callback(f"[INFO] Fetching releases for {repo_id}...")

        owner, repo = repo_id.split("/", 1)
        release = await self.forge.get_latest_release(owner, repo)
        if not release:
            if callback: await callback(f"[ERROR] No releases found for {repo_id}")
            return False

        assets_data = release.get("assets", [])

        # Match asset for current platform
        platform = sys.platform
        if platform == "win32": target_platform = "windows"
        elif platform == "darwin": target_platform = "macos"
        else: target_platform = "linux"

        matched_assets = AssetMatcher.filter_assets_for_platform(assets_data, target_platform)
        if not matched_assets:
            if callback: await callback("[ERROR] No compatible asset found for your platform.")
            return False

        # Prefer direct binary types over archives if possible
        matched_assets.sort(key=lambda a: 0 if a.type in ("apk", "deb", "exe", "dmg", "appimage") else 1)

        target_asset = matched_assets[0]
        download_url = target_asset.download_url
        asset_name = target_asset.name

        managed_dir = Path.home() / ".local/share/omnistore/github"
        managed_dir.mkdir(parents=True, exist_ok=True)
        repo_safe_name = repo_id.replace("/", "_")
        install_dir = managed_dir / repo_safe_name
        install_dir.mkdir(parents=True, exist_ok=True)

        dest_path = install_dir / asset_name

        if callback: await callback(f"[INFO] Downloading {asset_name}...")

        try:
            async with self.session.get(download_url) as dl_resp:
                if dl_resp.status == 200:
                    total = int(dl_resp.headers.get('content-length', 0))
                    downloaded = 0
                    with open(dest_path, 'wb') as f:
                        async for chunk in dl_resp.content.iter_chunked(8192):
                            f.write(chunk)
                            downloaded += len(chunk)
                            if total > 0 and callback:
                                await callback(f"[PROGRESS] {int(downloaded/total*100)}")

                    dest_path.chmod(0o755)
                    if callback: await callback(f"[INFO] Installed to {dest_path}")
                    return True
                else:
                    if callback: await callback(f"[ERROR] Download failed: HTTP {dl_resp.status}")
                    return False
        except Exception as e:
            if callback: await callback(f"[ERROR] GitHub installation failed: {e}")
            return False


    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        repo_id = package.get("id")
        repo_safe_name = repo_id.replace("/", "_")
        install_dir = Path.home() / ".local/share/omnistore/github" / repo_safe_name
        if install_dir.exists():
            import shutil
            shutil.rmtree(install_dir)
            if callback: await callback(f"[INFO] Removed {repo_id}")
            return True
        return False

    async def launch(self, package: Dict[str, Any]) -> bool:
        repo_id = package.get("id")
        repo_safe_name = repo_id.replace("/", "_")
        install_dir = Path.home() / ".local/share/omnistore/github" / repo_safe_name
        # Find the executable (usually the biggest file that isn't a zip/tar)
        executables = [f for f in install_dir.iterdir() if f.is_file() and os.access(f, os.X_OK)]
        if executables:
            # Sort by size, assuming the main binary is larger
            executables.sort(key=lambda x: x.stat().st_size, reverse=True)
            subprocess.Popen([str(executables[0])], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        return False

    async def locate(self, package: Dict[str, Any]) -> bool:
        repo_id = package.get("id")
        if not repo_id: return False
        repo_safe_name = repo_id.replace("/", "_")

        # Cross-platform data directory
        if sys.platform == "win32":
            base_dir = Path(os.environ.get("LOCALAPPDATA", os.path.expanduser("~"))) / "OmniStore" / "github"
            open_cmd = "explorer"
        elif sys.platform == "darwin":
            base_dir = Path.home() / "Library" / "Application Support" / "OmniStore" / "github"
            open_cmd = "open"
        else:
            base_dir = Path.home() / ".local" / "share" / "omnistore" / "github"
            open_cmd = "xdg-open"

        install_dir = base_dir / repo_safe_name
        if install_dir.exists():
            subprocess.Popen([open_cmd, str(install_dir)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        return False

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        repo_url = f"https://api.github.com/repos/{package_id}"
        async with self.session.get(repo_url, headers=self.forge.headers) as resp:
            if resp.status == 200:
                repo = await resp.json()
                return {
                    "name": repo["name"],
                    "id": repo["full_name"],
                    "description": repo["description"],
                    "stars": repo["stargazers_count"],
                    "forks": repo["forks_count"],
                    "updated_at": repo["updated_at"],
                    "license": repo.get("license", {}).get("name") if repo.get("license") else None
                }
        return {}

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        return None

    async def get_recommendations(self) -> Dict[str, List[Dict[str, Any]]]:
        # Fetch trending/popular repos from GitHub as recommendations
        search_url = "https://api.github.com/search/repositories?q=stars:>1000&sort=stars&order=desc"
        try:
            async with self.session.get(search_url, headers=self.forge.headers) as resp:
                if resp.status != 200: return {"featured": [], "trending": [], "for_you": []}
                data = await resp.json()
                repos = data.get("items", [])

                featured = []
                for repo in repos[:5]:
                    featured.append({
                        "name": repo["name"],
                        "id": repo["full_name"],
                        "description": repo.get("description", ""),
                        "source": "GitHub",
                        "icon": repo.get("owner", {}).get("avatar_url"),
                        "installed": self._is_installed(repo["full_name"]),
                        "variants": [{"source": "GitHub", "id": repo["full_name"]}]
                    })
                return {"featured": featured, "trending": [], "for_you": []}
        except Exception:
            return {"featured": [], "trending": [], "for_you": []}
