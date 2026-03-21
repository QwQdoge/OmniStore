import asyncio
import re
from .base import SearchSource

class FlatpakSource(SearchSource):
    async def search(self, query: str):
        if not self.enabled:
            return []

        # 检查系统是否安装了 flatpak 命令
        try:
            proc = await asyncio.create_subprocess_exec(
                "flatpak", "search", query, "--columns=name,application,version,description",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            )
            stdout, _ = await proc.communicate()
        except FileNotFoundError:
            return [] # 用户没装 flatpak 就不返回结果

        lines = stdout.decode().strip().splitlines()
        results = []

        for line in lines:
            # Flatpak 搜索结果通常以 Tab 或多个空格分隔
            # 格式: Name \t ID \t Version \t Description
            parts = line.split('\t')
            if len(parts) >= 2:
                results.append({
                    "name": parts[1].strip(), # 使用 ID 作为唯一标识更稳
                    "display_name": parts[0].strip(),
                    "desc": parts[3].strip() if len(parts) > 3 else "",
                    "version": parts[2].strip() if len(parts) > 2 else "Unknown",
                    "source": "Flatpak",
                    "is_installed": False # Flatpak 标记安装需要额外查询，建议后期优化
                })
        return results