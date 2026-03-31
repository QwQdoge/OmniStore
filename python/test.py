import asyncio
import aiohttp
from pathlib import Path
from core.config_loader import ConfigManager
from core.search.searchmanager import SearchManager

async def test_all_sources():
    cm = ConfigManager()
    
    # --- 强行开启所有源 (覆盖配置文件) ---
    sources = ["pacman", "flatpak", "aur", "appimage"]
    for s in sources:
        cm.set(f"search.sources.{s}", True)
    
    # 设置合理的优先级权重
    cm.set("priority.pacman", 100)
    cm.set("priority.aur", 80)
    cm.set("priority.flatpak", 60)
    cm.set("priority.appimage", 40)

    print("🚀 [全源启动测试] 正在初始化所有引擎...")
    
    async with aiohttp.ClientSession() as session:
        manager = SearchManager(cm, session)
        
        # 验证插件加载情况
        active = [s.name for s in manager._get_active_sources()]
        print(f"📡 活跃插件清单: {active}")

        # 测试案例：选择一个在所有渠道都有的高频软件
        query = "fastfetch"  # 这个软件在 pacman、AUR、flatpak 都有，且通常不安装过，适合测试
        print(f"\n🔍 正在跨源搜索: '{query}' ...")
        
        results = await manager.search_all(query)
        
        print(f"\n--- 📊 综合排序结果 (Top 5) ---")
        if not results:
            print("❌ 搜索失败，请检查网络或插件逻辑。")
            return

        for i, item in enumerate(results[:5]):
            # 提取所有来源及其版本
            variants_info = [f"{v['source']}({v.get('last_version', 'N/A')})" for v in item.get('variants', [])]
            primary = item.get('primary_source', 'Unknown')
            is_inst = "已安装 📥" if item.get('installed') or item.get('is_installed') else "未安装"
            
            print(f"{i+1}. 【{item['name']}】 - {is_inst}")
            print(f"   ⭐ 最佳来源: {primary}")
            print(f"   📦 所有渠道: {', '.join(variants_info)}")
            print(f"   📝 描述: {item.get('description', '')[:60]}...")
            print("-" * 50)

if __name__ == "__main__":
    try:
        asyncio.run(test_all_sources())
    except KeyboardInterrupt:
        pass