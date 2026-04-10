import os
import aiohttp
import asyncio
from pathlib import Path
from aiohttp import ClientSession

class AppImageDownloader:
    def __init__(self, executor):
        self.executor = executor
        # 统一路径管理
        self.apps_dir = Path.home() / "Applications"
        self.desktop_dir = Path.home() / ".local/share/applications"
        self.current_download_task = None
        self.timeout = aiohttp.ClientTimeout(total=5)

        


    async def install(self, package_data: dict, callback=None):
        name = package_data.get("name")
        url = package_data.get("url")
        dest_path = self.apps_dir / f"{name}.AppImage"
        self.apps_dir.mkdir(parents=True, exist_ok=True)

        if not url or not name:
            if callback: await callback("❌ Invalid package data")
            return
        
        # 1. 获取文件总大小 (用于计算百分比)
        total_size = 0
        try:
            # 继承系统代理获取 Header
            timeout = self.timeout
            async with aiohttp.ClientSession(trust_env=True) as session:
                async with session.head(url, allow_redirects=True, timeout=timeout) as resp:
                    if resp.status == 200:
                        total_size = int(resp.headers.get('content-length', 0))
        except:
            pass # 获取不到也没关系，后面会处理

        # 2. 启动 wget (完全静默模式，只管下载)
        cmd = ["wget", "-q", "-O", str(dest_path), str(url)]
        
        process = None
        try:
            # 继承环境变量（代理等）
            process = await asyncio.create_subprocess_exec(
                *cmd, 
                env=os.environ.copy()
            )

            last_percent = -1
            # 3. 核心：每 1 秒检查一次磁盘文件大小
            while process.returncode is None:
                if dest_path.exists():
                    current_size = dest_path.stat().st_size
                    
                    if total_size > 0:
                        percent = int((current_size / total_size) * 100)
                        if percent > last_percent and percent < 100:
                            if callback: await callback(f"[PROGRESS] {percent}")
                            last_percent = percent
                    else:
                        # 如果拿不到总大小，就传当前下载了多少 MB (可选)
                        if callback: await callback(f"[LOG] Downloaded: {current_size // 1024 // 1024}MB")

                # 检查进程是否已结束
                if process.returncode is not None:
                    break
                
                await asyncio.sleep(1) # 1秒轮询一次，性能损耗极低

            # 等待进程彻底结束
            ret_code = await process.wait()

            if ret_code == 0:
                dest_path.chmod(0o755)
                self._create_desktop_entry(name, dest_path)
                if callback: await callback("[PROGRESS] 100")
            else:
                if callback: await callback(f"❌ 下载失败 (Code: {ret_code})")

        except Exception as e:
            if callback: await callback(f"💥 异常: {e}")
        finally:
            # 确保杀掉进程
            if process and process.returncode is None:
                try:
                    process.kill()
                    await process.wait()
                except:
                    pass


    async def uninstall(self, package_data: dict, callback=None):
        """
        标准卸载接口
        package_data 格式: {"name": "WeChat"}
        """
        name = package_data.get("name")
        if not name: return

        file_path = self.apps_dir / f"{name}.AppImage"
        desktop_file = self.desktop_dir / f"{name.lower()}.desktop"

        try:
            # 1. 删除主程序
            if file_path.exists():
                file_path.unlink()
                if callback: await callback(f"[Log] Removed binary: {file_path}")
            
            # 2. 删除菜单入口
            if desktop_file.exists():
                desktop_file.unlink()
                if callback: await callback(f"[Log] Removed menu entry: {desktop_file}")

            res = f"Success: {name} uninstalled"
            if callback: await callback(res)
            print(res)

        except Exception as e:
            err = f"💥 Uninstall Error: {e}"
            if callback: await callback(err)
            print(err)

    def _create_desktop_entry(self, name: str, exec_path: Path):
        """生成 .desktop 文件，让程序出现在系统菜单里"""
        desktop_file = self.desktop_dir / f"{name.lower()}.desktop"
        content = f"""[Desktop Entry]
Version=1.0
Type=Application
Name={name}
Comment=Installed via Omnistore
Exec="{exec_path}" %U
Icon={name.lower()}  # 只要 icons 目录下有同名图片，系统会自动识别
Terminal=false
Categories=Utility;Application;
"""
        with open(desktop_file, "w") as f:
            f.write(content)

    def stop(self):
        """停止当前下载任务（如果需要实现）"""
        # ToDo:AppImage 的下载由 aiohttp 处理，若要强杀需要管理 session和 task，但目前我们不实现这个功能
        pass