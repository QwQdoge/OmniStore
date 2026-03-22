import re
import math

def calculate_package_score(self, item, query):
    # 保持原有的名称匹配逻辑 (这部分建议保留，因为它是搜索质量的基石)
    query = query.lower().strip()
    name = item.get('name', '').lower()
    desc = item.get('desc', '').lower()
    source = item.get('source', 'Unknown')
    
    score = 0.0

    # --- 维度 1: 名称匹配 (保持不变) ---
    if name == query:
        score += 2000  # 提高权重，确保搜什么出什么
    elif name.startswith(query):
        score += 1000
    elif query in name:
        score += 500

    # --- 维度 2: 描述匹配 (保持不变) ---
    if query in desc:
        score += 100

    # --- 维度 3: 流行度 (保持不变) ---
    votes = int(item.get('votes', 0))
    if votes > 0:
        score += math.log2(votes + 1) * 20
    
    # --- 维度 4: 来源可信度 (核心修改：对接 YAML) ---
    # 1. 建立内部名到配置名映射
    src_map = {"Native": "native", "AUR": "aur", "Flatpak": "flatpak", "AppImage": "appimage"}
    cfg_key = src_map.get(source, "native")
    
    # 2. 从 self.config 读取用户设置的权重
    # 注意：这里的 self.config 应该是在 SearchManager 初始化时加载好的
    priorities = self.config.get("priority", {})
    user_weight = float(priorities.get(cfg_key, 0))
    
    # 3. 将用户权重加入总分
    score += user_weight

    # --- 维度 5: 惩罚项 ---
    if name.endswith('-git') or name.endswith('-bin'):
        score -= 50  # 稍微加大惩罚，让稳定版更靠前

    return score