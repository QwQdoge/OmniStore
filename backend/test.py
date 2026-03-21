import asyncio
import json
from core.search.manager import SearchManager

async def test_search():
    # 1. 初始化 Manager (模拟前端传来的配置)
    config = {
        "sources": {"aur": True, "flatpak": True, "appimage": True},
        "priority": {"Native": 100, "Flatpak": 80, "AUR": 60, "AppImage": 40}
    }
    manager = SearchManager(config)

    print("--- 正在测试: 智能排序 (Smart) ---")
    # 2. 调用你刚写好的 search_all
    results = await manager.search_all("vlc", sort_by="smart")

    # 3. 打印结果，检查顺序
    if not results:
        print("未找到结果，请检查网络或本地 pacman/flatpak 是否可用。")
        return

    for i, item in enumerate(results):
        # 只打印前 10 条，方便对齐
        if i < 10:
            print(f"[{item['source']}] {item['name']} - {item['version']}")

    # 4. 验证排序逻辑
    names = [r['name'].lower() for r in results]
    is_sorted = names == sorted(names)
    print(f"\n排序验证: {'通过 (A-Z)' if is_sorted else '失败'}")
    print(f"总计找到: {len(results)} 条结果")

if __name__ == "__main__":
    # 使用 asyncio 运行异步函数
    asyncio.run(test_search())