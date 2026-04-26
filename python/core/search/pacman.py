import subprocess  # 用于执行系统命令
import re  # 用于处理和解析 pacman 输出的正则表达式
import asyncio  # 用于异步操作
from .base import SearchSource  # 导入基类

# 这个类专门用来搜索 Arch Linux 的软件包，使用系统的 pacman 命令, 只有在只启用了pacman搜索功能时才会被调用


class PacmanSearch(SearchSource):
    def __init__(self, session=None):
        super().__init__(name="Pacman")
        self.session = session
        # 初始化时检查系统环境，确保 pacman 可用
        try:
            subprocess.run(['pacman', '--version'],
                           capture_output=True, check=True)
        except (subprocess.CalledProcessError, FileNotFoundError):
            print(
                "No pacman found. Please ensure you are running this on an Arch-based Linux distribution.")

    # 搜索软件包，返回搜索结果字符串
    async def search(self, query: str) -> list:
        if not query or not isinstance(query, str):
            print("error: query must be a non-empty string")
            return []
        # 这里我使用 subprocess 来调用系统的 pacman 搜索命令
        try:
            result = await asyncio.get_event_loop().run_in_executor(
                None,
                lambda: subprocess.run(
                    ['pacman', '-Ss', query],
                    capture_output=True,
                    text=True,
                    check=False,  # 不抛出异常，交给后续处理
                    timeout=10
                )
            )
            raw_output = result.stdout.strip()  # 获取命令输出并去除多余的空白
            if not raw_output:
                return []

            line = raw_output.splitlines()  # 将输出按行分割
            packages = []
            current_pkg = None

            # i 永远指向标题行，i+1 指向对应的描述行
            for line in raw_output.splitlines():
                if not line.strip():
                    continue

                # 1. 识别标题行：通常以 repo/name 开头
                # 兼容格式：extra/telegram-desktop 5.11.1-1 [installed]
                header_match = re.match(
                    r'^([^\s/]+)/([^\s]+)\s+([^\s]+)(.*)$', line)

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
                        "votes": 0
                    }
                elif current_pkg and line.startswith("    "):
                    # 2. 识别描述行：标题行下方带 4 个空格缩进的行
                    current_pkg["description"] += line.strip() + " "

            # 别忘了最后一个包
            if current_pkg:
                packages.append(current_pkg)

            return packages

        # 处理 pacman 输出，提取有用的信息
        except subprocess.CalledProcessError as e:
            if e.returncode != 1:
                print(f"Pacman error: {e.stderr}")
            return []
        except subprocess.TimeoutExpired:
            print(
                f"Error: Searching for {query} timed out. Please try again later.")
            return []
        except Exception as e:
            print(f"An unexpected error occurred: {str(e)}")
            return []
