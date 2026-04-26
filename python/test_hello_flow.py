import asyncio
import sys
import os

# Ensure we can import core
sys.path.insert(0, '/home/shekong/Projects/Omnistore/python')

from core.downloader.downloader import InstallExecutor

async def test_hello_lifecycle():
    executor = InstallExecutor()
    
    async def callback(msg):
        print(f"  [LOG] {msg}")

    print("="*60)
    print("Omnistore 端到端流程测试: hello 软件包")
    print("="*60)

    # 1. 安装测试
    print("\n[阶段 1] 正在尝试安装 'hello'...")
    package_to_install = {
        "name": "hello",
        "source": "AUR" # YayDownloader handles both AUR and Pacman
    }
    
    install_success = await executor.install(package_to_install, callback)
    
    if install_success:
        print("\n[验证] 检查 'hello' 是否已安装在系统中...")
        check_proc = await asyncio.create_subprocess_exec(
            "which", "hello",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL
        )
        await check_proc.wait()
        if check_proc.returncode == 0:
            print("  ✓ 'hello' 已成功安装，路径: " + (await check_proc.stdout.read()).decode().strip())
        else:
            print("  ✗ 安装报告成功，但 'which hello' 找不到可执行文件。")
    else:
        print("\n  ✗ 安装失败。")
        return

    # 2. 卸载测试
    print("\n" + "-"*40)
    print("[阶段 2] 正在尝试卸载 'hello'...")
    
    uninstall_success = await executor.uninstall(package_to_install, callback)
    
    if uninstall_success:
        print("\n[验证] 检查 'hello' 是否已从系统中移除...")
        check_proc = await asyncio.create_subprocess_exec(
            "which", "hello",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL
        )
        await check_proc.wait()
        if check_proc.returncode != 0:
            print("  ✓ 'hello' 已成功卸载。")
        else:
            print("  ✗ 卸载报告成功，但 'which hello' 仍然能找到文件。")
    else:
        print("\n  ✗ 卸载失败。")

    print("\n" + "="*60)
    print("测试完成。")

if __name__ == "__main__":
    try:
        asyncio.run(test_hello_lifecycle())
    except KeyboardInterrupt:
        print("\n用户中断测试。")
