import aiohttp
from .base import SearchSource
from aiohttp import ClientTimeout

class AurPacmanSource(SearchSource):
    API_URL = "https://aur.archlinux.org/rpc/?v=5&type=search&arg="

    async def search(self, query: str):
        if not self.enabled or not query: return []
        
        async with aiohttp.ClientSession() as session:
            try:
                # 1. 直接请求官方 JSON 接口，比命令行快，且带点赞数
                timeout = ClientTimeout(total=10)
                async with session.get(f"{self.API_URL}{query}", timeout=timeout) as resp:
                    data = await resp.json()
                    results = []
                    for pkg in data.get("results", []):
                        results.append({
                            "name": pkg["Name"],
                            "desc": pkg.get("Description", ""),
                            "version": pkg["Version"],
                            "source": "AUR",
                            "votes": int(pkg.get("NumVotes", 0)), # ✅ 这里的点赞数是排序灵魂
                            "is_installed": False
                        })
                    return results
            except Exception as e:
                print(f"[AUR] RPC Error: {e}")
                return []