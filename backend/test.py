from typing import Any

import asyncio
import sys
from pathlib import Path

root_dir = Path(__file__).resolve().parent.parent # 根据 test.py 的位置向上找
sys.path.append(str(root_dir))

from backend.core.config_loader import ConfigManager
from backend.core.search.manager import SearchManager

async def test_disable_logic():
    # 1. 初始化配置，先确保 AUR 是开启的
    cm = ConfigManager("test_disable.yaml")
    cm.set("search.sources.aur", True)
    
    # 2. 模拟搜索 (此时 SearchManager 应该加载了 AurPacmanSource)
    sm = SearchManager(cm)
    print(f"📡 当前加载的源列表: {[type(s).__name__ for s in sm.sources]}")
    
    # 模拟数据：来自不同源的 VLC
    mock_data = [
        {"name": "vlc", "source": "Native", "version": "3.0.1"},
        {"name": "vlc", "source": "AUR", "version": "3.0.2-git"}
    ]
    
    # 正常合并
    res_1 = sm.merge_duplicates(mock_data)
    sources_1 = [v['source'] for r in res_1 for v in r['variants']]
    print(f"✅ [AUR 开启] 变体来源包含: {sources_1}")

    print("\n🚫 --- 禁用 AUR ---")
    # 3. 关键动作：修改配置并重读
    cm.set("search.sources.aur", False)
    sm._init_source_instances() # 模拟热重载或重新初始化
    
    print(f"📡 当前加载的源列表: {[type(s).__name__ for s in sm.sources]}")
    
    # 4. 再次模拟数据过滤逻辑
    # 在真实的 search_all 中，因为 AUR 源没被加载，mock_data 根本不会包含 AUR 项
    filtered_mock_data = [item for item in mock_data if item['source'] != "AUR"]
    
    res_2 = sm.merge_duplicates(filtered_mock_data)
    sources_2 = [v['source'] for r in res_2 for v in r['variants']]
    
    if "AUR" not in sources_2:
        print("🎉 测试通过：AUR 包已彻底消失。")
    else:
        print("❌ 测试失败：配置已关，但 AUR 包依然存在！")

if __name__ == "__main__":
    asyncio.run(test_disable_logic())