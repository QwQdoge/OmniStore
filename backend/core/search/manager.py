import asyncio
import re
import math
from typing import Optional, List, Dict, Any
from pathlib import Path

from backend.core.search.appimage import AppImageSource
from backend.core.search.aur_pacman import AurPacmanSource
from backend.core.search.flatpak import FlatpakSource
from backend.core.status import StatusChecker

# 导入你刚才写的 ConfigManager
# from .config_manager import ConfigManager 

class SearchManager:
    def __init__(self, config_manager: Any):
        # 1. 直接注入 ConfigManager 实例，保持真理来源唯一
        self.cm = config_manager
        self.sources = []
        self._init_source_instances()

    def _init_source_instances(self):
        """根据 ConfigManager 的实时状态初始化源"""
        # 使用 cm.get 快捷获取
        sources_cfg = self.cm.get("search.sources", {})
        
        # 清空现有源（方便热重载）
        self.sources = []

        if sources_cfg.get("pacman") or sources_cfg.get("aur"):
            self.sources.append(AurPacmanSource("AUR/Pacman"))
        if sources_cfg.get("flatpak"):
            self.sources.append(FlatpakSource("Flatpak"))
        if sources_cfg.get("appimage"):
            appimg_src = AppImageSource("AppImage")
            self.sources.append(appimg_src)
            asyncio.create_task(appimg_src.search(""))

    def _calculate_smart_score(self, item: Dict, query: str) -> float:
        query = query.lower().strip()
        name = item.get('name', '').lower()
        score = 0.0

        # 1. 基础匹配分数
        if name == query: score += 2000
        elif name.startswith(query): score += 1000
        elif query in name: score += 500

        # 2. 流行度
        votes = int(item.get('votes', 0))
        if votes > 0:
            score += math.log10(votes + 1) * 100 

        # 3. 动态权重 (完美对接 YAML)
        src_map = {"Native": "pacman", "AUR": "aur", "Flatpak": "flatpak", "AppImage": "appimage"}
        source_val = item.get('source', 'Unknown') 
        cfg_key = src_map.get(source_val, "pacman")
        priority_weight = self.cm.get(f"priority.{cfg_key}", 0)
        
        # 直接从 ConfigManager 获取权重
        priority_weight = self.cm.get(f"priority.{cfg_key}", 0)
        score += float(priority_weight)

        return score
    
    def merge_duplicates(self, items: List[Dict]) -> List[Dict]:
        """合并同名包，并根据权重决定谁是 '主显示条目'"""
        seen: Dict[str, Dict] = {}
        src_map = {"Native": "pacman", "AUR": "aur", "Flatpak": "flatpak", "AppImage": "appimage"}

        for item in items:
            name = item.get('name', 'unknown').lower()
            source = item.get('source', 'Unknown')
            current_prio = float(self.cm.get(f"priority.{src_map.get(source, '')}", 0))
            
            if name not in seen:
                # --- 1. 初始化 (确保所有封面字段都有值) ---
                entry = item.copy()
                entry['variants'] = [{
                    "source": source,
                    "version": item.get('version', 'unknown'),
                    "is_installed": item.get('is_installed', False),
                    "description": item.get('desc', '')
                }]
                entry['primary_source'] = source
                entry['version'] = item.get('version', 'unknown') # 👈 确保这里有初始值
                entry['desc'] = item.get('desc', '')             # 👈 确保这里有初始值
                entry['_top_prio'] = current_prio
                seen[name] = entry
            else:
                # --- 2. 追加变体 ---
                seen[name]['variants'].append({
                    "source": source,
                    "version": item.get('version', 'unknown'),
                    "is_installed": item.get('is_installed', False),
                    "description": item.get('desc', '')
                })
                
                # --- 3. 动态竞争 (安全访问) ---
                if current_prio > seen[name].get('_top_prio', 0):
                    seen[name]['_top_prio'] = current_prio
                    seen[name]['primary_source'] = source
                    # 使用 .get() 并提供现有的值作为默认，防止 KeyError
                    seen[name]['desc'] = item.get('desc', seen[name].get('desc', ''))
                    seen[name]['version'] = item.get('version', seen[name].get('version', 'unknown'))

        return list(seen.values())

    async def search_all(self, query: str, sort_by: str = "smart") -> List[Dict]:
        if not query: return []
        
        # 搜索前刷新一次源列表，以防用户刚才在设置里关掉了某个源
        self._init_source_instances()

        tasks = [src.search(query) for src in self.sources]
        responses = await asyncio.gather(*tasks, return_exceptions=True)
        
        combined = []
        for res in responses:
            if isinstance(res, list): combined.extend(res)

        # 排序
        if sort_by == "smart":
            combined.sort(key=lambda x: self._calculate_smart_score(x, query), reverse=True)
        
        merged_results = self.merge_duplicates(combined)

        # 限制数量
        max_res = self.cm.get("search.max_results", 100)
        results = merged_results[:max_res]

        # 状态检测
        check_tasks = [
            StatusChecker.check(item["name"], item["primary_source"]) 
            for item in results
        ]
        status_list = await asyncio.gather(*check_tasks, return_exceptions=True)

        for i, item in enumerate(results):
            is_inst = status_list[i] if isinstance(status_list[i], bool) else False
            item["is_installed"] = is_inst
            for v in item.get("variants", []):
                v["is_installed"] = is_inst

        return results