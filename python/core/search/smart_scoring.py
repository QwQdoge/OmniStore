def _calculate_smart_score(self, item, query):
    score = 0
    name = item.get('name', '').lower()
    query = query.lower()
    
    # --- 维度 1：匹配精准度 (决定性因素) ---
    if name == query:
        score += 2000  # 完全匹配，无条件置顶
    elif name.startswith(query):
        score += 1000  # 前缀匹配 (搜 tele 匹配 telegram)，这是最强的意图信号
    elif query in name:
        score += 200   # 包含匹配

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

    return score