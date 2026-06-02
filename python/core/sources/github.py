import asyncio
import aiohttp
import subprocess
import os
import sys
import re
from pathlib import Path
from typing import List, Dict, Any, Optional
from core.sources.base import UnifiedSource

class GitHubSource(UnifiedSource):
    def __init__(self, session: aiohttp.ClientSession, weight: float = 0.5):
        super().__init__(name="GitHub", weight=weight)
        self.session = session
        self.headers = {
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "Omnistore/0.1"
        }
        # Optionally load token from config for higher rate limits
        token = os.environ.get("GITHUB_TOKEN")
        if token:
            self.headers["Authorization"] = f"token {token}"

    async def search(self, query: str) -> List[Dict[str, Any]]:
        # Handle direct repo search (e.g. user/repo) or keyword search
        if "/" in query and len(query.split("/")) == 2:
            return await self._get_repo_as_package(query)

        search_url = f"https://api.github.com/search/repositories?q={query}&sort=stars&order=desc"
        try:
            async with self.session.get(search_url, headers=self.headers) as resp:
                if resp.status != 200: return []
                data = await resp.json()
                repos = data.get("items", [])[:10] # Limit to top 10

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
        except Exception:
            return []

    async def _get_repo_as_package(self, repo_full_name: str) -> List[Dict[str, Any]]:
        repo_url = f"https://api.github.com/repos/{repo_full_name}"
        try:
            async with self.session.get(repo_url, headers=self.headers) as resp:
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

        release_url = f"https://api.github.com/repos/{repo_id}/releases/latest"
        try:
            async with self.session.get(release_url, headers=self.headers) as resp:
                if resp.status != 200:
                    if callback: await callback(f"[ERROR] No releases found for {repo_id}")
                    return False
                release = await resp.json()
                assets = release.get("assets", [])

                # Match asset for current platform
                target_asset = self._match_asset(assets)
                if not target_asset:
                    if callback: await callback("[ERROR] No compatible asset found for your platform.")
                    return False

                download_url = target_asset["browser_download_url"]
                asset_name = target_asset["name"]

                managed_dir = Path.home() / ".local/share/omnistore/github"
                managed_dir.mkdir(parents=True, exist_ok=True)
                repo_safe_name = repo_id.replace("/", "_")
                install_dir = managed_dir / repo_safe_name
                install_dir.mkdir(parents=True, exist_ok=True)

                dest_path = install_dir / asset_name

                if callback: await callback(f"[INFO] Downloading {asset_name}...")

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

    def _match_asset(self, assets: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
        platform = sys.platform
        machine = os.uname().machine.lower() if hasattr(os, 'uname') else "x86_64"

        patterns = []
        if platform == "linux":
            patterns = [r"\.AppImage$", r"\.deb$", r"\.rpm$", r"linux.*x86_64", r"linux.*amd64"]
        elif platform == "win32":
            patterns = [r"\.exe$", r"\.msi$", r"win64", r"x64"]
        elif platform == "darwin":
            patterns = [r"\.dmg$", r"\.pkg$", r"macos", r"darwin"]

        for pattern in patterns:
            for asset in assets:
                name = asset["name"].lower()
                if re.search(pattern, name, re.IGNORECASE):
                    # Also check for architecture if possible
                    if "arm64" in name or "aarch64" in name:
                        if "arm64" in machine or "aarch64" in machine: return asset
                        else: continue
                    return asset
        return assets[0] if assets else None

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
        repo_safe_name = repo_id.replace("/", "_")
        install_dir = Path.home() / ".local/share/omnistore/github" / repo_safe_name
        if install_dir.exists():
            subprocess.Popen(["xdg-open", str(install_dir)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        return False

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        repo_url = f"https://api.github.com/repos/{package_id}"
        async with self.session.get(repo_url, headers=self.headers) as resp:
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
            async with self.session.get(search_url, headers=self.headers) as resp:
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
