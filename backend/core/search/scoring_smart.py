import re
import math

def calculate_package_score(item, query):
    query = query.lower().strip()
    name = item.get('name', '').lower()
    desc = item.get('desc', '').lower()
    source = item.get('source', 'Unknown')
    
    score = 0.0

    # --- 维度 1: 名称匹配 (权重最高: 0-1000) ---
    if name == query:
        score += 1000  # 完全相等
    elif name.startswith(query):
        score += 800   # 前缀匹配 (如输入 'fast' 匹配 'fastfetch')
    elif query in name:
        score += 500   # 包含匹配
        # 如果关键词是一个独立的单词 (如 'google chrome' 搜 'chrome')
        if re.search(rf'\b{re.escape(query)}\b', name):
            score += 100

    # --- 维度 2: 描述匹配 (权重中等: 0-200) ---
    if query in desc:
        score += 100
        # 单词边界检查
        if re.search(rf'\b{re.escape(query)}\b', desc):
            score += 50

    # --- 维度 3: 流行度/下载量 (权重辅助: 0-300) ---
    # AUR 使用点赞数 (Votes)，其他源如果没有数据，可以给个基准分
    votes = int(item.get('votes', 0))
    if votes > 0:
        # 使用对数缩放，防止 5000 赞的包永远压死 50 赞的新包
        # log2(5000) ≈ 12.2, * 20 ≈ 245分
        score += math.log2(votes + 1) * 20
    
    # --- 维度 4: 来源可信度 (手动偏置) ---
    source_weights = {
        "Native": 200,   # 官方仓库最稳，排最前
        "Flatpak": 100,
        "AUR": 50,       # AUR 虽然全，但质量参差不齐
        "AppImage": 20
    }
    score += source_weights.get(source, 0)

    # --- 维度 5: 惩罚项 ---
    # 如果名字里包含 '-git' 或 '-bin'，通常是开发版或预编译版，权重略微调低
    if name.endswith('-git') or name.endswith('-bin'):
        score -= 30

    return score