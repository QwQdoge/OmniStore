import re


class SmartScoring:
    def __init__(self, config_manager):
        self.cm = config_manager

    def _calculate_smart_score(self, item, query):
        score = 0
        name = item.get('name', '').lower()
        query = query.lower()

        # --- 维度 1：匹配精准度 (决定性因素) ---
        if name == query:
            score += 5000  # 完全匹配，无条件置顶
        elif name.startswith(query):
            score += 1000  # 前缀匹配 (搜 tele 匹配 telegram)，这是最强的意图信号
        elif query in name:
            score += 400   # 包含匹配

        # --- 维度 2：安装状态 (修正逻辑) ---
        if item.get('installed') or item.get('is_installed'):
            # 批判性改进：只有当前缀匹配或者完全匹配时，安装状态才给巨额加分
            # 如果只是包含匹配，安装状态只给小额加分，防止底层库“劫持”搜索结果
            if name.startswith(query):
                score += 1000
            else:
                score += 100  # 比如 spandsp 只会拿到这 100 分

        # --- 维度 3：来源优先级 ---
        priority_map = self.cm.get("priority", {})
        source_key = item.get('source', '').lower()
        score += priority_map.get(source_key, 50)

        # 名字越短且匹配度越高，分数越高
        length_diff = len(name) - len(query)
        if length_diff >= 0:
            score += max(0, 500 - (length_diff * 20))  # 名字多出一个字符扣20分

        if re.search(rf"\b{query}", name):  # 匹配单词开头，如 net-tools
            score += 500
        elif query in name:
            score += 200

        return score
