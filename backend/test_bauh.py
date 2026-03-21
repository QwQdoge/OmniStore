import sys
from pathlib import Path
from unittest.mock import MagicMock

# 1. 路径设置
backend_path = Path(__file__).parent.absolute()
sys.path.insert(0, str(backend_path))

# 2. 【核心黑科技：手动字典注入】
# 我们直接把 bauh 可能会找的所有 UI 路径都手动填死
# 这样 Python 就不会去硬盘找文件夹，而是直接从内存拿这个 Mock
mock_names = [
    "bauh.view",
    "bauh.view.util",
    "bauh.view.util.translation",
    "bauh.view.qt",
    "bauh.view.qt.rest",
    "bauh.view.qt.thread",
    "bauh.view.qt.view"
]

for name in mock_names:
    mock_obj = MagicMock()
    # 关键：骗 Python 说这是一个包，允许它有子模块
    mock_obj.__path__ = [] 
    sys.modules[name] = mock_obj

print("🧪 正在执行‘内存级’UI 屏蔽...")

try:
    # 1. 导入必要的 Mock 类
    from unittest.mock import MagicMock
    from bauh.gems.arch.controller import ArchManager
    
    # 2. 初始化
    mock_context = MagicMock()
    manager = ArchManager(context=mock_context)
    
    print("🔍 准备执行搜索...")
    
    # 3. 按照 grep 出来的参数填入
    # words: 搜索词
    # disk_loader: 必须传一个对象，我们直接给它一个 MagicMock
    # limit: -1 表示不限制数量
    res = manager.search(
        words="google-chrome", 
        disk_loader=MagicMock(), 
        limit=10
    )
    
    # 4. 打印结果
    if res:
        # 注意：SearchResult 内部通常有 .installed 和 .new 两个列表
        all_pkgs = (res.installed or []) + (res.new or [])
        print(f"✅ 成功！总共找到 {len(all_pkgs)} 个结果。")
        for pkg in all_pkgs[:3]:
            print(f"📦 软件包: {pkg.name} | 版本: {pkg.version} | 来源: {pkg.get_type()}")

except Exception as e:
    print(f"❌ 运行报错: {e}")
    import traceback
    traceback.print_exc()