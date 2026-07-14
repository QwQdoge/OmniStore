import re
from functools import lru_cache

# Pre-compiled regex for library detection to avoid redundant compilation during search
_LIB_RE = re.compile(r'^lib|-(devel|dev|debug|library)$|^python-|^perl-|^ruby-|^php-|^lua-|^js-|^node-')
_DESC_KEYWORDS = ["library", "bindings", "header files", "development files", "api for"]
# ⚡ Bolt: Pre-compiled regex for faster description keyword matching in hot search loops
_DESC_LIB_RE = re.compile(r'|'.join(_DESC_KEYWORDS))


class SmartScoring:
    def __init__(self, config_manager, habit_tracker=None):
        self.cm = config_manager
        self.habit_tracker = habit_tracker
        self._query_re_cache = {}

    @staticmethod
    @lru_cache(maxsize=1024)
    def _is_library(name_lower: str, truncated_desc: str):
        """识别是否为库文件或开发包"""
        # 1. Check name pattern using pre-compiled regex (Fast)
        if _LIB_RE.search(name_lower):
            return True

        # 2. Check description keywords
        if truncated_desc:
            # ⚡ Bolt: Truncation is now handled by the caller to optimize cache key size.
            if _DESC_LIB_RE.search(truncated_desc):
                # 排除掉一些可能是桌面软件但描述里含 keywords 的情况 (模糊处理)
                if "desktop" in truncated_desc or "client" in truncated_desc or "editor" in truncated_desc:
                    return False
                return True

        return False

    def _calculate_smart_score(self, item, query_lower, priority_map=None, query_re=None,
                               name_lower=None, desc_lower=None, truncated_desc=None,
                               source_habit_weight=None, source_prio_score=None):
        """
        Calculates a ranking score for a search result.
        Optimized with optional pre-calculated values to avoid redundant lookups in hot loops.
        """
        score = 0
        if name_lower is None:
            name_lower = item.get('name', '').lower()
        if truncated_desc is None:
            if desc_lower is not None:
                truncated_desc = desc_lower[:200]
            else:
                description = item.get('description', '')
                truncated_desc = description[:200].lower() if description else ""

        # --- 维度 1：匹配精准度 (决定性因素) ---
        if name_lower == query_lower:
            score += 5000  # 完全匹配，无条件置顶
        elif name_lower.startswith(query_lower):
            score += 1000  # 前缀匹配
        elif query_lower in name_lower:
            score += 400   # 包含匹配

        # --- 维度 2：安装状态 ---
        if item.get('installed') or item.get('is_installed'):
            if name_lower.startswith(query_lower):
                score += 1000
            else:
                score += 100

        # --- 维度 3：软件优先 (降权库文件) ---
        if self._is_library(name_lower, truncated_desc):
            score -= 2000  # 大幅降权库文件
        else:
            score += 500   # 鼓励普通软件

        # --- 维度 4：来源优先级与用户偏好 ---
        # ⚡ Bolt: Use pre-calculated priority and habit weights to avoid string operations and O(N) dict lookups
        if source_habit_weight is not None:
            score += source_habit_weight * 10
        elif self.habit_tracker:
            source_raw = item.get('source', '')
            score += self.habit_tracker.get_source_weight(source_raw) * 10

        if source_prio_score is not None:
            score += source_prio_score
        else:
            if priority_map is None:
                priority_map = self.cm.get("priority", {})

            source_raw = item.get('source', '')
            source_key = source_raw.lower()
            # 兼容配置中的 key 名
            if source_key == "native": cfg_key = "pacman"
            else: cfg_key = source_key

            score += priority_map.get(cfg_key, 50)

        # --- 维度 5：细节微调 ---
        length_diff = len(name_lower) - len(query_lower)
        if length_diff >= 0:
            score += max(0, 500 - (length_diff * 20))

        # Optimization: use pre-compiled query_re if provided
        if query_re:
            if query_re.search(name_lower):
                score += 500
        else:
            if query_lower not in self._query_re_cache:
                self._query_re_cache[query_lower] = re.compile(rf"\b{re.escape(query_lower)}")
            if self._query_re_cache[query_lower].search(name_lower):
                score += 500

        return score
