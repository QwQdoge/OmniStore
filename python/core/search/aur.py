import asyncio
import aiohttp
from aiohttp import ClientTimeout
from .base import SearchSource


class AurSearch(SearchSource):

    def __init__(self, session: aiohttp.ClientSession):
        super().__init__(name="AUR")
        self.api = "https://aur.archlinux.org/rpc/?v=5&type=search&arg="
        self.session = session

    async def _get_installed_aur_packages(self):
        # 获取本地已安装的所有 AUR/外来包名
        try:
            # -Qm 仅列出不在官方数据库中的包（通常就是从 AUR 安装的）
            proc = await asyncio.create_subprocess_exec(
                'pacman', '-Qm',
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, _ = await proc.communicate()
            output = stdout.decode().strip()
            if not output:
                return set()

            # 提取每一行的第一个单词（包名）
            # 输出格式通常是: pkgname version
            return {line.split()[0] for line in output.splitlines() if line.strip()}
        except Exception:
            return set()

    async def search(self, query: str) -> list:
        if not query or len(query) < 2:
            return []

        try:
            # 并发执行：1. 查云端 API, 2. 查本地已安装列表
            tasks = [
                self.session.get(f"{self.api}{query}",
                                 timeout=ClientTimeout(total=8)),
                self._get_installed_aur_packages()
            ]

            responses = await asyncio.gather(*tasks, return_exceptions=True)

            # 处理 API 结果
            resp = responses[0]
            installed_set = responses[1]  # 这是一个包含已安装包名的集合(Set)

            # 确保 installed_set 永远是集合，即使本地 pacman 命令执行失败
            if isinstance(installed_set, Exception):
                print(f"Local package check failed: {installed_set}")
                installed_set = set()

            # 处理 API 响应，提取 AUR 包信息
            if isinstance(resp, Exception):
                print(f"AUR Search API Exception: {resp}")
                return []

            # 确保响应是 aiohttp.ClientResponse 对象
            if not isinstance(resp, aiohttp.ClientResponse):
                print("AUR Search: Invalid response type")
                return []

            data = await resp.json()
            aur_pkgs = data.get("results", [])

            final_results = []
            for pkg in aur_pkgs:
                name = pkg["Name"]
                # 检查这个云端的包名是否在本地已安装集合中
                is_installed = name in installed_set

                # 模拟 pacman 的双行格式化输出
                status = "[installed]" if is_installed else ""
                f"aur/{name} {pkg['Version']} {status}".strip()
                pkg.get("Description", "") or ""

                # 存储为字典，方便后续调用
                final_results.append({
                    "name": name,
                    # 对于搜索，这两个通常一致
                    "last_version": pkg.get("Version", ""),
                    "source": self.name,
                    "description": pkg.get("Description", "") or "",
                    "votes": int(pkg.get("NumVotes", 0)),
                    "installed": is_installed
                })

            return final_results

        except Exception as e:
            print(f"AUR Search Exception: {e}")
            return []
