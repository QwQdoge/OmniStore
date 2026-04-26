#!/usr/bin/env python3
"""
验证 Omnistore 提权机制是否可行
运行方式：python test_auth.py
"""
import asyncio
import sys
sys.path.insert(0, '/home/shekong/Projects/Omnistore/python')
from core.downloader.downloader import InstallExecutor


async def main():
    executor = InstallExecutor()

    async def log(msg):
        print(f"  {msg}")

    print("=" * 60)
    print("Omnistore 提权机制测试")
    print("=" * 60)

    # Step 1
    print("\n[1/4] 检查当前 sudo 状态...")
    c = await asyncio.create_subprocess_exec(
        "sudo", "-n", "true",
        stderr=asyncio.subprocess.DEVNULL,
        stdout=asyncio.subprocess.DEVNULL
    )
    await c.wait()
    status = "已有活跃 sudo session ✓" if c.returncode == 0 else "无 sudo session（需要认证）"
    print(f"  sudo -n: {status}")

    # Step 2
    print("\n[2/4] _needs_privilege() 判断：")
    for src in ["AUR", "Native", "Flatpak", "AppImage"]:
        print(f"  {src:10s} → {'需要提权' if executor._needs_privilege(src) else '无需提权（用户空间操作）'}")

    # Step 3
    print("\n[3/4] _find_askpass() 搜索图形密码工具：")
    tool = await executor._find_askpass()
    if tool:
        print(f"  找到: {tool} ✓")
    else:
        print("  ERROR: 未找到任何 askpass 工具！请安装 zenity")
        return

    # Step 4
    print("\n[4/4] 完整提权流程（zenity 密码框将弹出，请输入您的用户密码）：")
    result = await executor._ensure_privileged(log)

    print(f"\n{'=' * 60}")
    if result:
        # Verify
        c2 = await asyncio.create_subprocess_exec(
            "sudo", "-n", "true",
            stderr=asyncio.subprocess.DEVNULL,
            stdout=asyncio.subprocess.DEVNULL
        )
        await c2.wait()
        session_ok = c2.returncode == 0
        print(f"结果: 成功 ✓")
        print(f"sudo -n 验证: {'session 已建立 ✓' if session_ok else '⚠ session 未持久化'}")
        print(f"内存缓存: {'有效 ✓' if executor._is_auth_cached() else '无效'}")

        print("\n[缓存测试] 第二次调用应直接从缓存返回（不弹框）...")
        result2 = await executor._ensure_privileged(log)
        print(f"缓存命中: {'是 ✓' if result2 else '否 ✗'}")
    else:
        print(f"结果: 失败 ✗（密码取消或不正确）")
    print("=" * 60)


asyncio.run(main())
