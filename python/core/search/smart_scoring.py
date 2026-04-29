import re


class SmartScoring:
    def __init__(self, config_manager, habit_tracker=None):
        self.cm = config_manager
        self.habit_tracker = habit_tracker

    def _is_library(self, name, description):
        """识别是否为库文件或开发包"""
        name = name.lower()
        desc = description.lower() if description else ""

        # 常见库文件前缀/后缀
        lib_patterns = [
            r'^lib', r'-devel$', r'-dev$', r'-debug$', r'^python-', r'^perl-',
            r'^ruby-', r'^php-', r'^lua-', r'^js-', r'-library$', r'^node-'
        ]

        # 如果名称匹配库文件模式
        if any(re.search(p, name) for p in lib_patterns):
            return True

        # 如果描述中明确提到是库、头文件或绑定
        desc_keywords = ["library", "bindings", "header files", "development files", "api for"]
        if any(kw in desc for kw in desc_keywords):
            # 排除掉一些可能是桌面软件但描述里含 keywords 的情况 (模糊处理)
            if "desktop" in desc or "client" in desc or "editor" in desc:
                return False
            return True

        return False

    def _calculate_smart_score(self, item, query):
        score = 0
        name = item.get('name', '').lower()
        description = item.get('description', '')
        query = query.lower()

        # --- 维度 1：匹配精准度 (决定性因素) ---
        if name == query:
            score += 5000  # 完全匹配，无条件置顶
        elif name.startswith(query):
            score += 1000  # 前缀匹配
        elif query in name:
            score += 400   # 包含匹配

        # --- 维度 2：安装状态 ---
        if item.get('installed') or item.get('is_installed'):
            if name.startswith(query):
                score += 1000
            else:
                score += 100

        # --- 维度 3：软件优先 (降权库文件) ---
        if self._is_library(name, description):
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
        length_diff = len(name) - len(query)
        if length_diff >= 0:
            score += max(0, 500 - (length_diff * 20))

        if re.search(rf"\b{query}", name):
            score += 500

        return score
