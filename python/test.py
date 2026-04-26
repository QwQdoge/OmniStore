from main import main
import asyncio
import sys
from unittest.mock import AsyncMock, patch
from pathlib import Path

# 确保导入路径
sys.path.insert(0, str(Path(__file__).resolve().parent))


async def test_cli_distribution():
    print("核心功能分发测试 (CLI Distribution Test)")
    print("-" * 50)

    # 模拟 Backend 对象
    with patch("main.OmnistoreBackend") as MockBackend:
        mock_instance = MockBackend.return_value
        mock_instance.run_search = AsyncMock()
        mock_instance.run_install = AsyncMock()
        mock_instance.run_uninstall = AsyncMock()

        # --- 测试 1: 测试搜索 (-S) ---
        print("测试 [-S]: omni -S telegram --json")
        with patch("sys.argv", ["main.py", "-S", "telegram", "--json"]):
            await main()
            mock_instance.run_search.assert_called_once_with(
                "telegram", json_mode=True)
            print("✅ 搜索指令分发正常")

        # --- 测试 2: 测试安装 (-I) ---
        print("\n测试 [-I]: omni -I wechat --source AUR")
        with patch("sys.argv", ["main.py", "-I", "wechat", "--source", "AUR"]):
            await main()
            # 验证是否传入了正确的参数
            mock_instance.run_install.assert_called_once()
            args, kwargs = mock_instance.run_install.call_args
            assert args[0] == "wechat"
            assert kwargs['source'] == "AUR"
            print("✅ 安装指令分发正常")

        # --- 测试 3: 测试卸载 (-R) ---
        # 注意：你的代码里 remove 对应的是 run_uninstall
        print("\n测试 [-R]: omni -R vlc --source Flatpak")
        with patch("sys.argv", ["main.py", "-R", "vlc", "--source", "Flatpak"]):
            await main()
            mock_instance.run_uninstall.assert_called_once()
            args, kwargs = mock_instance.run_uninstall.call_args
            assert args[0] == "vlc"
            assert kwargs['source'] == "Flatpak"
            print("✅ 卸载指令分发正常")

if __name__ == "__main__":
    asyncio.run(test_cli_distribution())
    print("\n🎉 所有 CLI 路由分支测试通过！")
