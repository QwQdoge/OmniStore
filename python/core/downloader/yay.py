import asyncio
import os
import signal
import re
from typing import List, Dict, Optional, TYPE_CHECKING, Any

if TYPE_CHECKING:
    from core.downloader.downloader import InstallExecutor

class YayDownloader:
    def __init__(self, executor: Any):
        self.current_process = None
        self._current_task = None # 持有当前运行的任务
        self.executor = executor


    async def _run_command(self, cmd: List[str], env: Optional[Dict[str, str]] = None, callback=None):
        """
        详细执行逻辑：负责运行 yay/pacman 命令并实时回传日志与进度
        """
        # 1. 准备环境变量
        final_env = os.environ.copy()
        final_env.update({
            "FORCE_COLOR": "1",        # 保持 yay 的彩色输出（如果需要解析颜色字符可去掉）
            "LC_ALL": "en_US.UTF-8",   # 统一为英文，确保正则匹配 (\d+)% 稳定
            "SUDO_USER": os.getlogin() # 核心：告知 sudo 谁在调用它
        })
        if env: 
            final_env.update(env)

        try:
            # 2. 启动异步子进程
            # 将 stderr 合并到 stdout (STDOUT)，这样我们只需要监听一个流
            self.current_process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
                env=final_env,
                stdin=asyncio.subprocess.DEVNULL # 绝对禁止后台交互
            )

            # 3. 实时读取输出流
            if self.current_process.stdout:
                while True:
                    # 采用 read(1024) 块读取，防止长文本导致的行缓冲区溢出
                    line_bytes = await self.current_process.stdout.read(1024)
                    if not line_bytes: 
                        break
                    
                    # 解码输出（处理可能的乱码）
                    raw_msg = line_bytes.decode('utf-8', errors='replace')
                    
                    # 按行拆分处理
                    for part in raw_msg.splitlines(keepends=True):
                        msg = part.strip('\n\r ')
                        if not msg: continue

                        if callback:
                            # --- 进度解析逻辑 ---
                            # 匹配 yay 输出中的 [ 25%] 或 25% 构建进度
                            progress_match = re.search(r"(\d+)%", msg)
                            if progress_match:
                                # 发送特殊格式给 Flutter：[PROGRESS] 25
                                await callback(f"[PROGRESS] {progress_match.group(1)}")
                            
                            # --- 状态识别逻辑 ---
                            if "Installing" in msg or "正在安装" in msg:
                                await callback(f"[Status] Installing dependencies...")
                            
                            # --- 原始日志回传 ---
                            await callback(f"[Log] {msg}")
                            
                        # 本地控制台调试打印
                        print(f"\r[Process] {msg[:80]}...", end="", flush=True)
                        if '\n' in part: print() 

            # 4. 等待进程结束
            return_code = await self.current_process.wait()
            
            if return_code == 0:
                res = "Success"
            else:
                # 如果返回码是 1 或 127，通常是权限或命令错误
                res = f"Failed with exit code: {return_code}"
                
            if callback: 
                await callback(res)
            return return_code == 0

        except Exception as e:
            error_msg = f"Runtime Error during command execution: {str(e)}"
            if callback: 
                await callback(error_msg)
            return False
            
        finally:
            self.current_process = None


    async def install(self, package_name: str, callback=None):

        """安装逻辑"""
        # 注意：这里不需要再加任何特权参数，sudo 会自动读取缓存
        cmd = ["yay", "-S", "--noconfirm", "--needed", package_name]
        return await self._run_command(cmd, callback=callback)

    async def uninstall(self, package_name: str, callback=None):
        """卸载逻辑"""

        if callback: await callback(f"[Status] Uninstalling {package_name}...")
        cmd = ["yay", "-Rs", "--noconfirm", package_name]
        return await self._run_command(cmd, callback=callback)

    def stop(self):
        """安全停止"""
        if self.current_process:
            try:
                # 杀死进程组（包括所有子进程）
                self.current_process.terminate()
                return "Process terminated."
            except Exception as e:
                return f"Stop failed: {e}"
        return "No process running."