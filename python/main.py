import asyncio
import json
import sys
import argparse
import aiohttp
import logging
from pathlib import Path

# 路径处理优化
BASE_DIR = Path(__file__).resolve().parent
sys.path.append(str(BASE_DIR))

# 屏蔽其他库可能产生的杂乱日志，防止污染 JSON 输出
logging.basicConfig(level=logging.ERROR)

from core.config_loader import ConfigManager
from core.search.searchmanager import SearchManager

class OmnistoreBackend:
    def __init__(self):
        self.config = ConfigManager()
        self.manager: SearchManager | None = None
        # self.executor = None  # 线程池将在需要时创建，避免不必要的资源占用
        self.session = None  # aiohttp session 也在需要时创建，确保资源正确释放
        # self.loop = asyncio.get_event_loop() # 事件循环也在需要时获取，避免在某些环境下的兼容性问题

    async def initialize(self, session: aiohttp.ClientSession):
        self.manager = SearchManager(self.config, session)
        if self.manager is None:
            raise RuntimeError("Failed to initialize SearchManager. Check configuration and environment.")

    async def run_search(self, query: str, json_mode: bool = False):
        try:
            # 设置超时，防止某个源（如 AppImage 抓 GitHub）卡死整个进程
            timeout = aiohttp.ClientTimeout(total=15)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                await self.initialize(session)
                results = await self.manager.search_all(query) # type: ignore
                
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
                print(f"💥 运行出错: {error_msg}")

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
                # 扁平化变体信息，方便前端展示 Chip
                "variants": item.get("variants", []),
                "version": str(item.get("last_version") or item.get("version") or "N/A"),
                "score": int(item.get("score", 0))
            })
        
        # 确保输出是唯一的，且不带多余的换行
        sys.stdout.write(json.dumps(output, ensure_ascii=False) + '\n')

    def _output_pretty(self, query, results):
        if not results:
            print(f"Couldn't find results for '{query}'")
            return
            
        print(f"Searching: '{query}' | finded {len(results)} results")
        print("=" * 60)
        for i, item in enumerate(results[:15]):
            status = "installed" if (item.get("installed") or item.get("is_installed")) else "not_installed"
            # 提取来源名称
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
    
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("-S", "--search", metavar="QUERY", help="Search for software packages")
    group.add_argument("-I", "--install", metavar="PACKAGE", help="Install software packages")
    
    parser.add_argument("--json", action="store_true", help="Output results in JSON format")

    # If no arguments provided, print help and exit
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)

    args = parser.parse_args()
    backend = OmnistoreBackend()
    
    if args.search:
        await backend.run_search(args.search, json_mode=args.json)
    elif args.install:
        # Installation logic can be integrated here in the future
        if args.json:
            print(json.dumps({"status": "error", "message": "Installation not implemented yet"}))
        else:
            print(f"🛠️  Preparing to install: {args.install} (Feature under development...)")

if __name__ == "__main__":
    # 处理 Linux 下的信号，防止 Ctrl+C 报一堆 traceback
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)