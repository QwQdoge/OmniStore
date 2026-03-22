import aiohttp
import asyncio
from .base import SearchSource
from aiohttp import ClientTimeout

class AurPacmanSource(SearchSource):
    API_URL = "https://aur.archlinux.org/rpc/?v=5&type=search&arg="

    async def _search_pacman_local(self, query: str):
        """调用本地 pacman -Ss 搜索官方库 (Native)"""
        try:
            # 使用 check_output 快速获取本地数据库结果
            proc = await asyncio.create_subprocess_exec(
                'pacman', '-Ss', query,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, _ = await proc.communicate()
            output = stdout.decode().strip()
            
            results = []
            if not output: return []
            
            # 解析 pacman -Ss 的输出 (每两行一个包)
            lines = output.split('\n')
            for i in range(0, len(lines), 2):
                if i+1 >= len(lines): break
                # 格式: core/linux 6.8.1.arch1-1 [installed]
                header = lines[i].split()
                if not header: continue
                
                name = header[0].split('/')[-1] # 去掉仓库名前缀 (core/)
                results.append({
                    "name": name,
                    "desc": lines[i+1].strip(),
                    "version": header[1],
                    "source": "Native", # 官方库标记为 Native
                    "votes": 99999,      # 官方库默认给最高优先级权重
                    "is_installed": "[installed]" in lines[i]
                })
            return results
        except Exception as e:
            print(f"[Pacman] Local Error: {e}")
            return []

    async def _search_aur_rpc(self, session, query: str):
        """请求 AUR 官方 API"""
        try:
            timeout = ClientTimeout(total=5)
            async with session.get(f"{self.API_URL}{query}", timeout=timeout) as resp:
                data = await resp.json()
                return [{
                    "name": pkg["Name"],
                    "desc": pkg.get("Description", ""),
                    "version": pkg["Version"],
                    "source": "AUR",
                    "votes": int(pkg.get("NumVotes", 0)),
                    "is_installed": False
                } for pkg in data.get("results", [])]
        except Exception as e:
            print(f"[AUR] RPC Error: {e}")
            return []

    async def search(self, query: str):
        if not query: return []
        
        # 并发执行：本地 Pacman + 远程 AUR
        async with aiohttp.ClientSession() as session:
            # 这里可以根据 self.config 动态决定是否跑某个任务
            tasks = [
                self._search_pacman_local(query),
                self._search_aur_rpc(session, query)
            ]
            
            all_res = await asyncio.gather(*tasks)
            # 合并结果列表
            return [item for sublist in all_res for item in sublist]