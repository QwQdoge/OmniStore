import re

# Pre-compiled regex for library detection to avoid redundant compilation during search
_LIB_RE = re.compile(r'^lib|-(devel|dev|debug|library)$|^python-|^perl-|^ruby-|^php-|^lua-|^js-|^node-')
_DESC_KEYWORDS = ["library", "bindings", "header files", "development files", "api for"]


class SmartScoring:
    def __init__(self, config_manager, habit_tracker=None):
        self.cm = config_manager
        self.habit_tracker = habit_tracker
        self._query_re_cache = {}

    def _is_library(self, name_lower: str, desc_lower: str):
        """识别是否为库文件或开发包"""
        # 1. Check name pattern using pre-compiled regex (Fast)
        if _LIB_RE.search(name_lower):
            return True

        # 2. Check description keywords
        if desc_lower:
            if any(kw in desc_lower for kw in _DESC_KEYWORDS):
                # 排除掉一些可能是桌面软件但描述里含 keywords 的情况 (模糊处理)
                if "desktop" in desc_lower or "client" in desc_lower or "editor" in desc_lower:
                    return False
                return True

        return False

    def _calculate_smart_score(self, item, query_lower):
        score = 0
        name_lower = item.get('name', '').lower()
        description = item.get('description', '')
        desc_lower = description.lower() if description else ""

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
        if self._is_library(name_lower, desc_lower):
            score -= 2000  # 大幅降权库文件
        else:
            score += 500   # 鼓励普通软件

        # --- 维度 4：来源优先级与用户偏好 ---
        priority_map = self.cm.get("priority", {})
        source_key = item.get('source', '').lower()
        # 兼容配置中的 key 名
        if source_key == "native": cfg_key = "pacman"
        else: cfg_key = source_key

        score += priority_map.get(cfg_key, 50)

        # 加入用户偏好权重
        if self.habit_tracker:
            user_pref_score = self.habit_tracker.get_source_weight(item.get('source', ''))
            score += user_pref_score * 10  # 放大用户习惯的影响

        # --- 维度 5：细节微调 ---
        length_diff = len(name_lower) - len(query_lower)
        if length_diff >= 0:
            score += max(0, 500 - (length_diff * 20))

        # Optimization: Cache the query regex to avoid recompilation for every item in the result list
        if query_lower not in self._query_re_cache:
            self._query_re_cache[query_lower] = re.compile(rf"\b{re.escape(query_lower)}")

        if self._query_re_cache[query_lower].search(name_lower):
            score += 500

        return score
