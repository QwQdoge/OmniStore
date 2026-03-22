import asyncio
import os
import aiohttp
from typing import Dict, Optional, List

class InstallExecutor:
    async def install(self, package: dict, callback=None):
        """安装逻辑：整合了 AUR, Flatpak, AppImage"""
        source = package.get("source")
        name = package.get("name")
        
        if not name or not isinstance(name, str):
            msg = "❌ 错误: 软件包名称缺失"
            if callback: await callback(msg)
            print(msg)
            return

        start_msg = f"[Executor] Starting install for {name} via {source}..."
        if callback: await callback(start_msg)
        print(start_msg)
        
        # 准备基础环境变量
        env = os.environ.copy()
        env["PACMAN_AUTH"] = "pkexec"
        
        if source == "AUR":
            cmd = ["yay", "-S", name, "--noconfirm", "--answerdiff", "N", "--answerclean", "N", "--needed"]
            await self._run_command(cmd, env=env, callback=callback)
        
        elif source == "Flatpak":
            # 预检仓库
            add_remote = ["flatpak", "remote-add", "--user", "--if-not-exists", "flathub", "https://dl.flathub.org/repo/flathub.flatpakrepo"]
            await self._run_command(add_remote, callback=callback)
            # 执行安装
            cmd = ["flatpak", "install", "--user", "-y", "--noninteractive", "flathub", name]
            await self._run_command(cmd, callback=callback)
            
        elif source == "AppImage":
            url = package.get("url")
            if isinstance(url, str) and url:
                await self._download_appimage(name, url, callback=callback)
            else:
                msg = f"❌ {name} 链接无效"
                if callback: await callback(msg)
                print(msg)

    async def _run_command(self, cmd: List[str], env: Optional[Dict[str, str]] = None, callback=None):
        """执行系统命令，支持实时日志回调"""
        # 1. 预热权限
        if "yay" in cmd or "pacman" in cmd:
            if callback: await callback("[Status] Requesting privilege...")
            proc_auth = await asyncio.create_subprocess_exec("pkexec", "true")
            await proc_auth.wait()

        # 2. 准备环境变量
        final_env = os.environ.copy()
        if env:
            final_env.update(env)

        # 3. 启动进程
        process = None
        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
                env=final_env
            )
            
            # 4. 实时读取输出
            if process.stdout:
                while True:
                    line = await process.stdout.readline()
                    if not line: break
                    msg = line.decode().strip()
                    if msg:
                        if callback: await callback(f"[Log] {msg}")
                        print(f"[Log] {msg}")
            
            await process.wait()
            
            # 5. 结果处理
            pkg_label = cmd[2] if len(cmd) > 2 else cmd[0]
            if process.returncode == 0:
                res = f"✅ {pkg_label} 执行成功"
            else:
                res = f"❌ {pkg_label} 失败，返回码: {process.returncode}"
            
            if callback: await callback(res)
            print(res)

        except Exception as e:
            err = f"❌ 运行异常: {e}"
            if callback: await callback(err)
            print(err)

    async def _download_appimage(self, name: str, url: str, callback=None):
        """下载并授权 AppImage"""
        target_dir = os.path.expanduser("~/Applications")
        os.makedirs(target_dir, exist_ok=True) 
        file_path = os.path.join(target_dir, f"{name}.AppImage")
        
        if callback: await callback(f"[Log] Downloading AppImage from {url}...")
        
        try:
            async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=600)) as session:
                async with session.get(url) as resp:
                    if resp.status == 200:
                        with open(file_path, "wb") as f:
                            while True:
                                chunk = await resp.content.read(16384)
                                if not chunk: break
                                f.write(chunk)
                        os.chmod(file_path, 0o755)
                        msg = f"✅ AppImage 已保存: {file_path}"
                    else:
                        msg = f"❌ 下载失败: HTTP {resp.status}"
                    
                    if callback: await callback(msg)
                    print(msg)
        except Exception as e:
            err = f"❌ AppImage 异常: {e}"
            if callback: await callback(err)
            print(err)

    async def uninstall(self, package: dict, callback=None):
        """卸载逻辑"""
        source = package.get("source")
        name = package.get("name")
        if not name: return

        if source == "AUR":
            env = os.environ.copy()
            env["PACMAN_AUTH"] = "pkexec"
            await self._run_command(["yay", "-Rs", "--noconfirm", name], env=env, callback=callback)
        elif source == "Flatpak":
            await self._run_command(["flatpak", "uninstall", "--user", "-y", name], callback=callback)
        elif source == "AppImage":
            file_path = os.path.expanduser(f"~/Applications/{name}.AppImage")
            if os.path.exists(file_path):
                os.remove(file_path)
                msg = f"✅ 已删除 {file_path}"
            else:
                msg = f"⚠️ 文件不存在"
            if callback: await callback(msg)