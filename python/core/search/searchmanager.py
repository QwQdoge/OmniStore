import asyncio
from typing import List, Dict, Any

from core.search.base import SearchSource
from .smart_scoring import SmartScoring
from .pacman import PacmanSearch
from .aur import AurSearch
from .flatpak import FlatpakSearch
from .appimage import AppImageSearch
import shutil
import aiohttp
import re
import sys


class SearchManager:
    def __init__(self, config_manager: Any, session: aiohttp.ClientSession):
        self.cm = config_manager
        self.smart_scoring = SmartScoring(config_manager)
        # session 主要用于 AUR 搜索，其他源如果需要网络请求也可以复用这个 session
        self.session = session
        self.source_instances = {}
        # 根据环境和配置动态加载搜索源实例，确保只有启用且环境支持的源才会被初始化
        self._setup_sources()
        self.executor = None  # 线程池将在需要时创建，避免不必要的资源占用
        self.config = config_manager.current_config  # 直接使用当前配置，避免重复访问 cm.get()

    def _setup_sources(self):
        self.source_instances = {}
        # 只有环境支持才加载
        if shutil.which("pacman"):
            self.source_instances["pacman"] = PacmanSearch("Native")
        if shutil.which("flatpak"):
            self.source_instances["flatpak"] = FlatpakSearch("Flatpak")
        # AppImage 不需要外部命令，直接加载
        self.source_instances["appimage"] = AppImageSearch(self.session)
        # AUR 搜索需要 aiohttp 支持，且用户必须启用
        if self.cm.get("search.sources.aur", False):
            self.source_instances["aur"] = AurSearch(self.session)

    def _get_active_sources(self) -> List[SearchSource]:
        active = []
        for key, instance in self.source_instances.items():
            # 统一查找 search.sources.pacman 这种布尔值
            path = f"search.sources.{key}"
            if self.cm.get(path, False):  # 默认不开启，除非配置里写了 true
                active.append(instance)
            else:
                print(f"Search source '{key}' is disabled in config.")

        if not active:
            print("Warning: No search sources are enabled in config.")

        return active

    async def search_all(self, query: str) -> List[Dict]:
        if not query or len(query) < 2:
            return []

        active_sources = self._get_active_sources()

        # 并发搜索
        tasks = [src.search(query) for src in active_sources]
        
        # 使用 asyncio.wait_for 给整个搜索加一个总超时，防止无限等待
        try:
            responses = await asyncio.wait_for(asyncio.gather(*tasks, return_exceptions=True), timeout=15)
        except asyncio.TimeoutError:
            sys.stderr.write("[SearchManager] Global search timeout\n")
            return []
        except Exception as e:
            sys.stderr.write(f"[SearchManager] Global search crash: {e}\n")
            return []

        combined = []
        for i, res in enumerate(responses):
            source_name = active_sources[i].name if i < len(
                active_sources) else f"Source_{i}"
            if isinstance(res, list):
                combined.extend(res)
            elif isinstance(res, Exception):
                # ❌ 不要 print，改用 stderr，确保 stdout 只有干净的 JSON
                sys.stderr.write(
                    f"[SearchManager] Source '{source_name}' failed: {res}\n")

        # 1. 初始排序：在合并前先按智能分排一次
        combined.sort(key=lambda x: self.smart_scoring._calculate_smart_score(
            x, query), reverse=True)

        # 2. 合并同名包
        merged = self.merge_duplicates(combined)

        # 3. 截断结果，提升 Flutter 端渲染性能
        max_res = self.cm.get("search.max_results", 50)
        return merged[:max_res]

    def _normalize_app_name(self, name: str) -> str:
        """
        极致归一化：将各种包名后缀统一，实现真正的跨源合并。
        """
        # 1. 统一转小写，去掉空格
        n = name.lower().strip()
        # 2. 移除版本号或架构信息（如果有）
        n = n.split()[0]
        # 3. 移除常见的 Linux 包名后缀 (关键：让 telegram-desktop-bin 变成 telegram)
        # 我们要移除 -bin, -git, -desktop, -appimage, -a 等干扰项
        n = re.sub(
            r'-(bin|git|appimage|desktop|flatpak|stable|edge|preview|a|cli|dev|electron)$', '', n)
        # 4. 移除中间的连字符，处理 TelegramDesktop 这种写法
        n = n.replace("-", "").replace("_", "")
        return n

    def merge_duplicates(self, items: List[Dict]) -> List[Dict]:
        seen: Dict[str, Dict] = {}

        for item in items:
            raw_name = item.get('name', 'unknown')
            norm_key = self._normalize_app_name(raw_name)

            source = item.get('source', 'Unknown')
            is_installed = item.get('installed', False)
            version = item.get('last_version', 'Unknown')

            # 准备变体数据
            variant = {
                "source": source,
                "version": version,
                "installed": is_installed,
                "description": item.get('description', ''),
            }

            if norm_key not in seen:
                # 第一次初始化条目
                entry = item.copy()
                entry['primary_source'] = source
                entry['is_installed'] = is_installed
                entry['variants'] = [variant]
                # 记录已有的来源类型，防止重复
                entry['_source_types'] = {source}
                seen[norm_key] = entry
            else:
                # 核心改进：检查该来源是否已在 variants 中，防止出现 [AUR, AUR]
                if source not in seen[norm_key]['_source_types']:
                    seen[norm_key]['variants'].append(variant)
                    seen[norm_key]['_source_types'].add(source)

                # 更新全局安装状态
                if is_installed:
                    seen[norm_key]['is_installed'] = True

                # 优先级抢占：如果新来源是 Native 或 Flatpak，通常它们的名字和描述更官方
                if source in ["Native", "Flatpak"] and seen[norm_key]['primary_source'] == "AUR":
                    seen[norm_key]['name'] = raw_name
                    seen[norm_key]['primary_source'] = source
                    seen[norm_key]['description'] = item.get(
                        'description', seen[norm_key]['description'])

        # 清理掉用于内部逻辑的辅助字段
        for entry in seen.values():
            entry.pop('_source_types', None)

        return list(seen.values())
