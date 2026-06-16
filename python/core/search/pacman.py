import re  # 用于处理和解析 pacman 输出的正则表达式
import asyncio  # 用于异步操作
import shutil
from .base import SearchSource  # 导入基类
from core.subprocess_utils import safe_subprocess

# 这个类专门用来搜索 Arch Linux 的软件包，使用系统的 pacman 命令, 只有在只启用了pacman搜索功能时才会被调用

# Pre-compiled regex for pacman package header to improve parsing performance
_PKG_HEADER_RE = re.compile(r'^([^\s/]+)/([^\s]+)\s+([^\s]+)(.*)$')


class PacmanSearch(SearchSource):
    def __init__(self, session=None):
        super().__init__(name="Pacman")
        self.session = session
        # 初始化时检查系统环境，确保 pacman 可用
        if shutil.which("pacman") is None:
            print("No pacman found. Please ensure you are running this on an Arch-based Linux distribution.")

    # 搜索软件包，返回搜索结果字符串
    async def search(self, query: str) -> list:
        if not query or not isinstance(query, str):
            print("error: query must be a non-empty string")
            return []
        # 这里我使用 safe_subprocess 来调用系统的 pacman 搜索命令
        try:
            async with safe_subprocess(
                "pacman", "-Ss", query,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            ) as proc:
                stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=10)
                if proc.returncode != 0 and proc.returncode != 1:
                    if stderr:
                        print(f"Pacman error: {stderr.decode().strip()}")
                    return []

                raw_output = stdout.decode().strip()
                if not raw_output:
                    return []

            packages = []
            packages = []
            current_pkg = None

            # i 永远指向标题行，i+1 指向对应的描述行
            for line in raw_output.splitlines():
                if not line.strip():
                    continue

                # 1. 识别标题行：通常以 repo/name 开头
                # 兼容格式：extra/telegram-desktop 5.11.1-1 [installed]
                header_match = _PKG_HEADER_RE.match(line)

                if header_match:
                    # 如果之前存过包，先推入列表
                    if current_pkg:
                        packages.append(current_pkg)

                    repo, name, version, extra = header_match.groups()
                    current_pkg = {
                        "name": name,
                        "repo": repo,
                        "last_version": version,
                        "source": "Pacman",
                        "description": "",
                        "installed": "[installed]" in extra,
                        "votes": 0,
                        "download_size": "",
                        "installed_size": ""
                    }
                elif current_pkg and line.startswith("    "):
                    desc = current_pkg["description"]
                    if isinstance(desc, str):
                        current_pkg["description"] = desc + line.strip() + " "

            # 别忘了最后一个包
            if current_pkg:
                packages.append(current_pkg)

            return packages

        except asyncio.TimeoutError:
            print(f"Error: Searching for {query} timed out. Please try again later.")
            return []
        except Exception as e:
            print(f"An unexpected error occurred: {str(e)}")
            return []
