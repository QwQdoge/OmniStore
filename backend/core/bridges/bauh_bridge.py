import sys
import warnings
from pathlib import Path
from unittest.mock import MagicMock

# 1. 静音红字警告
warnings.filterwarnings("ignore", category=SyntaxWarning)

# 2. 内存级 UI 屏蔽
mock_names = [
    "bauh.view", "bauh.view.util", "bauh.view.util.translation",
    "bauh.view.qt", "bauh.view.qt.rest", "bauh.view.qt.thread"
]
for name in mock_names:
    m = MagicMock()
    m.__path__ = []
    sys.modules[name] = m

class OmniBridge:
    def __init__(self):
        # 1. 初始化所有你想要的 Gems (插件)
        from bauh.gems.arch.controller import ArchManager
        from bauh.gems.flatpak.controller import FlatpakManager # 如果你拷了 flatpak 文件夹
        
        context = MagicMock()
        # 把所有管理器塞进一个列表
        self.managers = [
            ArchManager(context=context),
            # FlatpakManager(context=context) # 以后想加就取消注释
        ]

    def search_all(self, query: str):
        all_results = []
        for manager in self.managers:
            # 每个 manager 都会返回自己的结果
            raw = manager.search(words=query, disk_loader=MagicMock())
            
            # 统一转换成 OmniArch 的标准格式
            for pkg in (raw.new or []):
                all_results.append({
                    "name": pkg.name,
                    "version": pkg.version,
                    "source": pkg.get_type(), # 自动返回 'Arch' 或 'Flatpak'
                    "description": getattr(pkg, 'description', '')
                })
        return all_results