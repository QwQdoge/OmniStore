from core.downloader.downloader import InstallExecutor
from core.search.searchmanager import SearchManager
from core.config_loader import ConfigManager
from typing import Optional
import json
import sys
import argparse
import aiohttp
import logging
from pathlib import Path
import functools

# 强制让本项目所有的 print 都自带 flush，保证 Flutter 能实时收到
print = functools.partial(print, flush=True)

# 获取当前文件的绝对路径
current_file_path = Path(__file__).resolve()
# 将包含 core 的目录加入 path
sys.path.insert(0, str(current_file_path.parent))

# 路径处理优化
BASE_DIR = Path(__file__).resolve().parent
sys.path.append(str(BASE_DIR))

# Initial minimal logging config
logging.basicConfig(level=logging.ERROR)


if hasattr(sys.stderr, 'reconfigure'):
    sys.stdout.reconfigure(  # type: ignore
        line_buffering=True,
        encoding='utf-8',
        errors='replace'
    )


class OmnistoreBackend:
    def __init__(self):
        self.config = ConfigManager()
        self.manager: SearchManager | None = None
        # self.executor = None  # 线程池将在需要时创建，避免不必要的资源占用
        self.session = None  # aiohttp session 也在需要时创建，确保资源正确释放
        # self.loop = asyncio.get_event_loop() # 事件循环也在需要时获取，避免在某些环境下的兼容性问题
        self.executor = InstallExecutor()
        self.is_action = False

    async def initialize(self, session: aiohttp.ClientSession):
        self.manager = SearchManager(self.config, session)
        if self.manager is None:
            raise RuntimeError(
                "Failed to initialize SearchManager. Check configuration and environment.")

    # --- Unified Callback Handling ---
    async def _flutter_callback(self, msg: str, json_mode: bool = False, level: Optional[str] = None):
        """Unified log exit with level support and auto-detection"""
        # Map common prefixes to levels
        if level is None:
            if msg.startswith("[ERROR]") or msg.startswith("[Error]"): level = "ERROR"
            elif msg.startswith("[INFO]") or msg.startswith("[Status]") or msg.startswith("[Executor]"): level = "INFO"
            elif msg.startswith("[PROGRESS]"): level = "DEBUG"
            elif msg.startswith("[DEBUG]"): level = "DEBUG"
            else: level = "INFO"

        # Normalize prefix and translate [Status] to [INFO]
        if msg.startswith("[Status]"):
            msg = msg.replace("[Status]", "[INFO]", 1)
        elif not msg.startswith("["):
            msg = f"[{level.upper()}] {msg}"
        
        # Replace [Error] with [ERROR] for consistency
        if msg.startswith("[Error]"):
            msg = msg.replace("[Error]", "[ERROR]", 1)

        # Filter based on config level
        config_level = self.config.get("logging.level", "INFO").upper()
        level_map = {"DEBUG": 10, "INFO": 20, "WARNING": 30, "ERROR": 40}
        
        current_level_val = level_map.get(level.upper(), 20)
        config_level_val = level_map.get(config_level, 20)

        if current_level_val < config_level_val:
            return

        if json_mode:
            # ONLY output log objects during actions to avoid breaking Process.run JSON parsing
            if self.is_action:
                output = json.dumps(
                    {"type": "log", "message": msg, "level": level.upper()}, ensure_ascii=False)
                sys.stdout.write(f"{output}\n")
        else:
            print(f"📦 {msg}")

    async def run_search(self, query: str, json_mode: bool = False):
        try:
            # 设置超时，防止某个源（如 AppImage 抓 GitHub）卡死整个进程
            timeout = aiohttp.ClientTimeout(total=30)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                await self.initialize(session)
                results = await self.manager.search_all(query)  # type: ignore

                if not self.manager:
                    raise RuntimeError("SearchManager is not initialized.")

                if results is None:
                    results = []

                if json_mode:
                    self._output_json(results)
                else:
                    self._output_pretty(query, results)

        except Exception as e:
            # 这里的错误处理非常关键，如果是 JSON 模式，必须返回 JSON 格式的错误
            error_msg = f"Backend Error: {str(e)}"
            if json_mode:
                print(json.dumps({"error": error_msg, "results": []}))
            else:
                print(f"[Error] {error_msg}")

    async def run_install(self, name: str, source: str, url: Optional[str] = None, json_mode: bool = False):
        """Installation logic: call our optimized dispatcher"""
        self.is_action = True
        package_data = {"name": name, "source": source, "url": url}

        async def cb(m):
            await self._flutter_callback(m, json_mode)

        await self.executor.install(package_data, callback=cb)

    async def run_uninstall(self, package_name: str, source: str, json_mode: bool = False):
        """Uninstallation logic"""
        self.is_action = True

        async def cb(m):
            await self._flutter_callback(m, json_mode)

        await self.executor.uninstall(package_name, source, callback=cb)

    async def run_list_installed(self, json_mode: bool = False):
        """List all installed AppImage and Flatpak applications"""
        installed_list = []

        # 1. Scan AppImage (based on ~/Applications directory)
        apps_dir = Path.home() / "Applications"
        if apps_dir.exists():
            for f in apps_dir.glob("*.AppImage"):
                installed_list.append({
                    "name": f.stem,
                    "source": "AppImage",
                    "installed": True,
                    "description": f"Local AppImage at {f}",
                    "last_version": "Local",
                    "url": f.as_uri()
                })

        # 2. Scan Flatpak
        try:
            import asyncio
            proc = await asyncio.create_subprocess_exec(
                "flatpak", "list", "--app", "--columns=name,application,version,description",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            )
            stdout, _ = await proc.communicate()
            if stdout:
                lines = stdout.decode().strip().splitlines()
                for line in lines:
                    parts = [p.strip() for p in line.split('\t')]
                    if len(parts) >= 2:
                        installed_list.append({
                            "name": parts[0],
                            "id": parts[1],
                            "source": "Flatpak",
                            "installed": True,
                            "last_version": parts[2] if len(parts) > 2 else "Unknown",
                            "description": parts[3] if len(parts) > 3 else f"Flatpak app {parts[1]}"
                        })
        except Exception as e:
            # Don't use callback here in JSON mode as it breaks the query output
            if not json_mode:
                await self._flutter_callback(f"Failed to scan Flatpaks: {e}", json_mode, level="ERROR")

        if json_mode:
            print(json.dumps(installed_list))
        else:
            for app in installed_list:
                print(f"[{app['source']}] {app['name']}")

    def _output_json(self, results):
        """
        标准化输出格式。
        注意：在 Flutter 侧，建议先判断返回的是 List 还是 Map(含 error)
        """
        output = []
        for item in results:
            # 增加数据清洗，防止 None 值导致 Flutter 解析失败
            output.append({
                "name": str(item.get("name", "Unknown")),
                "description": str(item.get("description", "")),
                "installed": bool(item.get("installed", False) or item.get("is_installed", False)),
                "primary_source": str(item.get("primary_source", "Native")),
                "url": str(item.get("url") or ""), # 提取下载链接
                # 扁平化变体信息，方便前端展示 Chip
                "variants": item.get("variants", []),
                "version": str(item.get("last_version") or item.get("version") or "N/A"),
                "score": int(item.get("score", 0))
            })

        # 确保输出是唯一的，且不带多余的换行
        sys.stdout.write(json.dumps(output, ensure_ascii=False) + '\n')

    def _output_pretty(self, query, results):
        if not results:
            print(f"[INFO] No results found for '{query}'")
            return

        print(f"[INFO] Searching: '{query}' | found {len(results)} results")
        print("=" * 60)
        for i, item in enumerate(results[:15]):
            status = "installed" if (item.get("installed") or item.get(
                "is_installed")) else "not_installed"
            # Extract source names
            sources = [v['source'] for v in item.get('variants', [])]
            source_str = f"({', '.join(sources)})"

            print(f"{i+1:2}. {item['name']:<25} {status:<12} {source_str}")
            desc = item.get('description', 'no_description')
            print(f"    {desc[:55]}..." if len(desc) > 55 else f"     {desc}")
        print("=" * 60)


async def main():
    parser = argparse.ArgumentParser(
        description="Omnistore: all-in-one software manager for Arch Linux and beyond.\n\n",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Examples:\n  omni -S wechat          # Search for WeChat\n  omni -S telegram --json # Provide data to frontend"
    )

    group = parser.add_mutually_exclusive_group(required=False)
    group.add_argument("-S", "--search", metavar="QUERY",
                       help="Search for software packages")
    group.add_argument("-I", "--install", metavar="PACKAGE",
                       help="Install software packages")
    group.add_argument("-R", "--remove", metavar="PACKAGE",
                       help="Uninstall software packages")
    group.add_argument("-L", "--list-installed", action="store_true",
                       help="List all installed AppImage and Flatpak packages")

    parser.add_argument("--json", action="store_true",
                        help="Output results in JSON format")
    parser.add_argument("--source", choices=["AUR", "Flatpak", "AppImage"],
                        default="AUR", help="Specify the source for installation (default: AUR)")
    parser.add_argument(
        "--url", help="For AppImage, specify the direct download URL")
    parser.add_argument("--version", action="version",
                        version="Omnistore 0.1.0")
    parser.add_argument("--debug", action="store_true",
                        help="Enable debug mode with verbose logging")
    parser.add_argument("--get-config", action="store_true",
                        help="Get the full configuration as JSON")
    parser.add_argument("--set-config", metavar="CONFIG_JSON",
                        help="Set the full configuration using a JSON string")

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)

    args = parser.parse_args()
    backend = OmnistoreBackend()

    if not any([args.search, args.install, args.remove, args.get_config, args.set_config, args.list_installed]):  # 如果没有任何操作指令，显示帮助
        parser.print_help()
        return

    # --- 处理逻辑分发 ---

    if args.get_config:
        config = backend.config.data
        print(json.dumps(config, ensure_ascii=False))

    elif args.set_config:
        try:
            input_data = sys.stdin.read().strip()
            if not input_data:
                input_data = args.set_config

            if not input_data or input_data == "true":
                print(json.dumps({"status": "error", "message": "[ERROR] No configuration data provided"}))
                sys.exit(1)

            # Unified return format
            success = backend.config.save(new_config=json.loads(input_data))
            if success:
                print(json.dumps({"status": "success", "message": "[INFO] Configuration saved successfully"}))
            else:
                print(json.dumps(
                    {"status": "error", "message": "[ERROR] Failed to save configuration"}))
        except Exception as e:
            print(json.dumps({"status": "error", "message": f"[ERROR] {str(e)}"}))
            sys.exit(1)

    elif args.search:
        # 搜索逻辑
        await backend.run_search(args.search, json_mode=args.json)

    elif args.install:
        # 安装逻辑
        await backend.run_install(
            args.install,
            source=args.source,
            url=args.url,
            json_mode=args.json
        )

    elif args.remove:
        # 卸载逻辑
        await backend.run_uninstall(
            args.remove,
            source=args.source,
            json_mode=args.json
        )

    elif args.list_installed:
        # 列出已安装
        await backend.run_list_installed(json_mode=args.json)

if __name__ == "__main__":
    import asyncio
    try:
        # 使用 run 启动异步主函数
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
    except Exception:
        # 调试核心：如果启动失败，至少把错误喷到 stderr
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)
