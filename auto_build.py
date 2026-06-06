import os
import shutil
import subprocess
import sys
import argparse
from pathlib import Path

# ==================== 🛠️ 路径配置 ====================
BASE_DIR = Path(__file__).resolve().parent

RUST_PROJECT_DIR = BASE_DIR / "daemon"
PYTHON_PROJECT_DIR = BASE_DIR / "python"
FLUTTER_PROJECT_DIR = BASE_DIR / "FlutterUI"

# 根据平台确定 Flutter Bundle 路径
if sys.platform == "win32":
    FLUTTER_BUNDLE_DIR = FLUTTER_PROJECT_DIR / "build/windows/x64/runner/Release"
    BINARY_EXT = ".exe"
else:
    # 默认为 Linux
    FLUTTER_BUNDLE_DIR = FLUTTER_PROJECT_DIR / "build/linux/x64/release/bundle"
    BINARY_EXT = ""

TARGET_BACKEND_DIR = FLUTTER_BUNDLE_DIR / "backends"
# =====================================================================

def run_command(cmd, cwd, name):
    print(f"\n🚀 [正在执行] {name}...")
    print(f"📂 工作目录: {cwd}")
    print(f"💻 命令: {cmd}")
    result = subprocess.run(cmd, shell=True, cwd=cwd)
    if result.returncode != 0:
        print(f"❌ {name} 失败，程序终止！")
        sys.exit(1)
    print(f"✅ {name} 成功！")

def build_rust():
    run_command("cargo build --release", RUST_PROJECT_DIR, "Rust Release 编译")

def build_python():
    # 探测 venv 路径
    if sys.platform == "win32":
        pyinstaller_path = PYTHON_PROJECT_DIR / ".venv" / "Scripts" / "pyinstaller.exe"
    else:
        pyinstaller_path = PYTHON_PROJECT_DIR / ".venv" / "bin" / "pyinstaller"

    if not pyinstaller_path.exists():
        # 尝试直接使用系统 pyinstaller
        pyinstaller_path = "pyinstaller"

    # 增加一些隐藏导入以确保 FastAPI/Uvicorn 正常运行
    hidden_imports = [
        "--hidden-import=uvicorn",
        "--hidden-import=fastapi",
        "--hidden-import=fastapi.middleware.cors",
        "--hidden-import=uvicorn.protocols.http.httptools_impl",
        "--hidden-import=uvicorn.protocols.http.h11_impl",
        "--hidden-import=uvicorn.protocols.websockets.websockets_impl",
        "--hidden-import=uvicorn.lifespan.on",
    ]

    cmd = f"{pyinstaller_path} --onefile {' '.join(hidden_imports)} --name python_server --clean main.py"
    run_command(cmd, PYTHON_PROJECT_DIR, "Python PyInstaller 打包")

def build_flutter():
    if sys.platform == "win32":
        cmd = "flutter build windows --release"
    else:
        cmd = "flutter build linux --release"
    run_command(cmd, FLUTTER_PROJECT_DIR, "Flutter Release 编译")

def assemble():
    print("\n📦 [正在拼装] 正在将后端二进制文件移入 Flutter Bundle...")
    TARGET_BACKEND_DIR.mkdir(parents=True, exist_ok=True)

    # 复制 Rust 产物
    rust_bin_name = "omnistore-daemon" + BINARY_EXT
    rust_src = RUST_PROJECT_DIR / "target" / "release" / rust_bin_name
    if rust_src.exists():
        shutil.copy2(rust_src, TARGET_BACKEND_DIR / rust_bin_name)
        print(f"✅ 已复制 Rust 守护进程: {rust_bin_name}")
    else:
        print(f"⚠️ 未找到 Rust 产物: {rust_src}")

    # 复制 Python 产物
    python_bin_name = "python_server" + BINARY_EXT
    python_src = PYTHON_PROJECT_DIR / "dist" / python_bin_name
    if python_src.exists():
        shutil.copy2(python_src, TARGET_BACKEND_DIR / python_bin_name)
        print(f"✅ 已复制 Python 后端: {python_bin_name}")
    else:
        print(f"⚠️ 未找到 Python 产物: {python_src}")

    print(f"\n🎉 🎉 🎉 所有打包工作已完美自动完成！")
    print(f"📁 最终成品目录: {FLUTTER_BUNDLE_DIR}")

def main():
    parser = argparse.ArgumentParser(description="OmniStore 自动化打包工具")
    parser.add_argument("--all", action="store_true", help="全量打包 (Rust + Python + Flutter)")
    parser.add_argument("--rust", action="store_true", help="仅打包 Rust 守护进程")
    parser.add_argument("--python", action="store_true", help="仅打包 Python 后端")
    parser.add_argument("--flutter", action="store_true", help="仅打包 Flutter 前端")
    parser.add_argument("--assemble", action="store_true", help="仅执行组装步骤")

    args = parser.parse_args()

    # 如果没有任何参数，默认显示帮助
    if not any(vars(args).values()):
        parser.print_help()
        return

    if args.all or args.rust:
        build_rust()

    if args.all or args.python:
        build_python()

    if args.all or args.flutter:
        build_flutter()

    if args.all or args.rust or args.python or args.flutter or args.assemble:
        assemble()

if __name__ == "__main__":
    main()
