import asyncio
import os
import re
from typing import List, Optional

class FlatpakDownloader:
    def __init__(self, executor):
        self.executor = executor
        self.flathub_url = "https://dl.flathub.org/repo/flathub.flatpakrepo"

    async def install(self, app_id: str, callback=None):
        # 1. 检查仓库 (不发送进度，或者只发送一个固定的低进度)
        if callback: await callback("[Status] Checking Flathub repository...")
        add_repo_cmd = ["script", "-q", "/dev/null", "-c", f"flatpak install -y --user flathub {app_id}"]
        # 🌟 增加 is_install=False 避免触发 100%
        await self._run_flatpak_command(add_repo_cmd, callback=callback, is_install=False)

        # 2. 执行安装 (这是大头，开启进度解析)
        if callback: await callback(f"[Status] Preparing to install {app_id}...")
        install_cmd = ["flatpak", "install", "--user", "-y", "--noninteractive", "flathub", app_id]
        # 🌟 增加 is_install=True
        await self._run_flatpak_command(install_cmd, callback=callback, is_install=True)

    async def _run_flatpak_command(self, cmd: List[str], callback=None, is_install=False):
        try:
            # 🌟 伪装环境变量，让 Flatpak 以为自己在 80 列宽的终端里
            env = {
                **os.environ, 
                "LC_ALL": "C", 
                "TERM": "xterm-256color", # 伪装终端类型
                "COLUMNS": "100",          # 强制指定宽度，方便正则定位
                "PYTHONUNBUFFERED": "1"
            }

            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
                env=env
            )

            last_sent_progress = -1

            if process.stdout:
                while True:
                    # 调小读取块，保证实时性
                    chunk = await process.stdout.read(1024)
                    if not chunk: break
                    if not is_install: continue

                    raw_data = chunk.decode('utf-8', errors='ignore')
                    
                    # Flatpak 在非 TTY 下可能把进度条拆得很散
                    # 我们不仅找 "Installing X/Y"，还要找那种孤立的百分比
                    
                    # 1. 尝试匹配汇总行：Installing 3/8... 19%
                    summary_match = re.search(r"(\d+)/(\d+).*?(\d+)\s*%", raw_data)
                    
                    # 2. 尝试匹配任务列表里的进度：[  19%]
                    # 因为非终端下，它可能会输出类似 [  19%] 这样的纯文本
                    list_progress_match = re.search(r"\[\s*(\d+)%\s*\]", raw_data)

                    total_prog = None

                    if summary_match:
                        cur, total, sub = map(int, summary_match.groups())
                        total_prog = int(((cur - 1) / total) * 100 + (sub / total))
                    elif list_progress_match:
                        # 如果抓不到汇总，至少抓到当前包的百分比
                        total_prog = int(list_progress_match.group(1))

                    if total_prog is not None and total_prog > last_sent_progress:
                        if callback: await callback(f"[PROGRESS] {total_prog}")
                        last_sent_progress = total_prog

            await process.wait()
            if is_install and process.returncode == 0:
                if callback: await callback("[PROGRESS] 100")

        except Exception as e:
            if callback: await callback(f"Error: {e}")
            

    async def uninstall(self, app_id: str, callback=None):
        """卸载并清理残留"""
        if callback: await callback(f"[Status] Uninstalling {app_id}...")
        
        # --delete-data 可以选择性开启，通常为了品牌体验不建议默认删数据
        cmd = ["flatpak", "uninstall", "--user", "-y", app_id]
        await self._run_flatpak_command(cmd, callback=callback)
        
        # 卸载后的灵魂操作：清理不再需要的 Runtime（类似无用依赖）
        if callback: await callback("[Status] Clean useless runtimes...")
        unused_cmd = ["flatpak", "uninstall", "--unused", "-y"]
        await self._run_flatpak_command(unused_cmd, callback=callback)

    async def stop(self):
        """Flatpak 的安装过程通常不需要特殊的停止逻辑，因为它是单个命令执行，但如果需要，可以实现取消当前任务的功能"""
        pass