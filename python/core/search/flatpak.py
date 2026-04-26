import asyncio
from .base import SearchSource


class FlatpakSearch(SearchSource):
    def __init__(self, session=None):
        super().__init__(name="Flatpak")
        self.session = session

    async def _get_installed_flatpaks(self) -> set:
        """异步获取本地已安装的 Flatpak 应用 ID 集合"""
        try:
            proc = await asyncio.create_subprocess_exec(
                "flatpak", "list", "--installed", "--columns=application",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            )
            stdout, _ = await proc.communicate()
            output = stdout.decode().strip()
            return {line.strip() for line in output.splitlines() if line.strip()}
        except Exception:
            return set()

    async def search(self, query: str) -> list:
        if not self.enabled or not query or len(query) < 2:
            return []

        try:
            # 并发执行
            tasks = [
                asyncio.create_subprocess_exec(
                    "flatpak", "search", "--columns=name,application,version,description", query,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.DEVNULL
                ),
                self._get_installed_flatpaks()
            ]

            # 使用 wait_for 防止命令挂起（虽然 flatpak 通常很快）
            results = await asyncio.gather(*tasks)
            proc, installed_set = results
            stdout, _ = await proc.communicate()

            if not stdout:
                return []

            lines = stdout.decode().strip().splitlines()
            final_results = []

            for line in lines:
                # 某些版本的 flatpak 可能会带表头，跳过它
                if "Application ID" in line or "Name" in line:
                    continue

                parts = [p.strip() for p in line.split('\t')]
                if len(parts) < 2:
                    continue

                # 字段映射优化
                display_name = parts[0]  # 更加用户友好的名称
                app_id = parts[1]
                version = parts[2] if len(parts) > 2 else "Unknown"
                desc = parts[3] if len(parts) > 3 else f"Flatpak app {app_id}"

                final_results.append({
                    "id": app_id,           # 增加 ID 字段方便后续安装操作
                    "name": display_name,    # UI 显示名称
                    "last_version": version,
                    "source": self.name,
                    "description": desc,
                    "votes": 0,
                    "installed": app_id in installed_set
                })

            return final_results

        except Exception:
            # 这里的 Exception 捕获很关键，防止没装 flatpak 导致整个后台崩掉
            return []
