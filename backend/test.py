from typing import Any

import asyncio
import sys
from pathlib import Path

root_dir = Path(__file__).resolve().parent.parent # 根据 test.py 的位置向上找
sys.path.append(str(root_dir))

from backend.core.search.manager import SearchManager
from backend.core.config_loader import ConfigManager

async def test_weight_logic():
    # 1. 初始化管理器
    cm = ConfigManager("test_config.yaml")
    sm = SearchManager(cm)

    # 模拟一些搜索原始数据（跳过实际的网络请求，直接测试排序逻辑）
    mock_results = [
        {"name": "vlc", "source": "Native", "votes": 0, "desc": "Official VLC"},
        {"name": "vlc", "source": "AUR", "votes": 100, "desc": "AUR VLC version"},
        {"name": "vlc", "source": "Flatpak", "votes": 0, "desc": "Flatpak VLC"}
    ]

    print("--- 场景 1: 默认权重 (Native: 100, AUR: 80) ---")
    cm.set("priority.pacman", 100)
    cm.set("priority.aur", 80)
    
    # 模拟排序与合并
    processed_1 = sm.merge_duplicates(mock_results)
    # 按分数手动排序模拟 search_all 内部逻辑
    processed_1.sort(key=lambda x: sm._calculate_smart_score(x, "vlc"), reverse=True)
    
    print(f"排名第一的来源: {processed_1[0]['primary_source']}")
    print(f"封面描述: {processed_1[0]['desc']}")

    print("\n--- 场景 2: 用户更改权重 (AUR 调至 999) ---")
    # 模拟用户在前端点击了修改
    cm.set("priority.aur", 999)
    cm.set("priority.pacman", 100)
    
    # 再次处理
    processed_2 = sm.merge_duplicates(mock_results)
    processed_2.sort(key=lambda x: sm._calculate_smart_score(x, "vlc"), reverse=True)
    
    print(f"排名第一的来源: {processed_2[0]['primary_source']}")
    print(f"封面描述: {processed_2[0]['desc']}")

    # 验证文件是否真的写入了
    import yaml
    with open(cm.config_path, 'r') as f:
        disk_cfg = yaml.safe_load(f)
        print(f"\n磁盘文件中的 AUR 权重: {disk_cfg['priority']['aur']}")

if __name__ == "__main__":
    asyncio.run(test_weight_logic())