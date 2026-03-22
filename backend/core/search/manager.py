import asyncio
import re
import math
from typing import Optional, List, Dict, Any
from .aur_pacman import AurPacmanSource
from .flatpak import FlatpakSource
from .appimage import AppImageSource
from ..status import StatusChecker

class SearchManager:
    def __init__(self, config: Optional[dict] = None):
        # 1. 基础配置加载
        self.config = config or {
            "sources": {"aur": True, "flatpak": True, "appimage": True},
            "priority": {"Native": 100, "Flatpak": 80, "AUR": 60, "AppImage": 40}
        }
        
        self.sources = []
        src_cfg = self.config.get("sources", {})
        
        # 2. 实例化源
        if src_cfg.get("aur"): self.sources.append(AurPacmanSource("AUR/Pacman"))
        if src_cfg.get("flatpak"): self.sources.append(FlatpakSource("Flatpak"))
        
        # 特别注意 AppImage
        if src_cfg.get("appimage"):
            appimg_src = AppImageSource("AppImage")
            self.sources.append(appimg_src)
            
            # --- 关键改动：异步预热缓存 ---
            # 即使还没人搜索，也先让它去下 feed.json
            try:
                loop = asyncio.get_event_loop()
                if loop.is_running():
                    # 只要事件循环在跑，就丢进后台
                    loop.create_task(appimg_src.search("")) 
            except Exception as e:
                print(f"[Manager] Preload trigger failed: {e}")
    
    def merge_duplicates(self, items: List[Dict]) -> List[Dict]:
        """合并同名包的不同来源，形成一个主条目 + 变体列表"""
        seen: Dict[str, Dict] = {} # <-- 注意这里的缩进：必须比 def 进 4 格

        for item in items:
            name = item['name']
            source = item['source']
            
            if name not in seen:
                # 第一次见到这个包，创建主条目
                entry = item.copy()
                entry['variants'] = [{
                    "source": source,
                    "version": item.get('version', 'unknown'),
                    "is_installed": item.get('is_installed', False),
                    "url": item.get('url', '')
                }]
                entry['primary_source'] = source
                seen[name] = entry
            else:
                # 已经存在同名包，把当前来源的信息加进去
                seen[name]['variants'].append({
                    "source": source,
                    "version": item.get('version', 'unknown'),
                    "is_installed": item.get('is_installed', False),
                    "url": item.get('url', '')
                })
                
                # 策略：如果新发现的来源是 Native，则更新权威描述
                if source == "Native":
                    seen[name]['desc'] = item.get('desc', seen[name]['desc'])
                    seen[name]['primary_source'] = "Native"
        return list(seen.values()) # <-- return 必须在函数体内


    def _calculate_smart_score(self, item: Dict, query: str) -> float:
        query = query.lower().strip()
        name = item.get('name', '').lower()
        score = 0.0

        # 1. 名字精准度 (大幅提升奖励)
        if name == query:
            score += 2000  # 绝对保送
        elif name.startswith(query):
            score += 1000  # 前缀匹配 (如输入 google 匹配 google-chrome)
        elif query in name:
            score += 500

        # 2. 流行度加成 (有了 RPC API 的 votes 才有意义)
        votes = item.get('votes', 0)
        if votes > 0:
            # log10(100赞) = 2 -> +200分; log10(1000赞) = 3 -> +300分
            score += math.log10(votes + 1) * 100 

        # 强制转换为字符串，并提供 "Unknown" 作为备选
        current_source = str(item.get('source', 'Unknown'))
        # 确保 priorities 字典包含了所有可能的键
        priorities = self.config.get("priority", {})
        score += priorities.get(current_source, 0)

        return score

    async def search_all(self, query: str, sort_by: str = "smart", filters: Optional[dict] = None) -> List[Dict]:
        if not query: return []

        # 并发执行
        tasks = [src.search(query) for src in self.sources]
        responses = await asyncio.gather(*tasks, return_exceptions=True)
        
        combined = []
        for res in responses:
            if isinstance(res, list):
                combined.extend(res)
            elif isinstance(res, Exception):
                print(f"[SearchManager] Source failed: {res}")

        # --- 阶段 1: 过滤 ---
        if filters:
            if filters.get("only_source"):
                combined = [r for r in combined if r['source'] == filters["only_source"]]
            if filters.get("only_installed"):
                combined = [r for r in combined if r.get('is_installed')]

        # --- 阶段 2: 排序 ---
        if sort_by == "smart":
            combined.sort(key=lambda x: self._calculate_smart_score(x, query), reverse=True)
        elif sort_by == "alpha":
            combined.sort(key=lambda x: x['name'].lower())
        elif sort_by == "source":
            source_order = {"Native": 0, "Flatpak": 1, "AUR": 2, "AppImage": 3}
            combined.sort(key=lambda x: (source_order.get(x['source'], 99), x['name'].lower()))
        elif sort_by == "status":
            combined.sort(key=lambda x: (not x.get('is_installed', False), x['name'].lower()))

        # --- 阶段 3: 合并去重 ---
        # 先合并，减少重复检测安装状态的次数（比如同名软件在不同源都有）
        merged_results = self.merge_duplicates(combined)

        # --- 阶段 4: 并行检测安装状态 (核心修正) ---
        # 提取所有包的检测任务
        check_tasks = [
            StatusChecker.check(item["name"], item["primary_source"]) 
            for item in merged_results
        ]
        
        # 并发执行所有检测，效率最高
        status_list = await asyncio.gather(*check_tasks, return_exceptions=True)

        # 将检测结果写回结果集
        for i in range(len(merged_results)):
            # 如果检测过程中出错了，默认设为 False
            is_inst = status_list[i] if isinstance(status_list[i], bool) else False
            merged_results[i]["is_installed"] = is_inst
            
            # 同时更新 variants 里的状态（可选，为了前端显示更准）
            for variant in merged_results[i].get("variants", []):
                variant["is_installed"] = is_inst

        return merged_results # ✅ 确保 return 在最后