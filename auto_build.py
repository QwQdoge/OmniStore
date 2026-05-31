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
    run_command("cargo build --release", RUST_PROJECT_DIR, "Rust Release build")

def build_python():
    # 1. 创建属于沙盒自己的虚拟环境
    venv_dir = PYTHON_PROJECT_DIR / "build_venv"
    venv_pip = venv_dir / "bin" / "pip"
    venv_pyinstaller = venv_dir / "bin" / "pyinstaller"

    subprocess.run([sys.executable, "-m", "venv", str(venv_dir)], check=True, cwd=str(PYTHON_PROJECT_DIR))

    # 2. 用虚拟环境隔离的 pip 装东西（绝对不会触发 PEP 668 报错）
    subprocess.run([str(venv_pip), "install", "--upgrade", "pip"], check=True, cwd=str(PYTHON_PROJECT_DIR))
    subprocess.run([str(venv_pip), "install", "-r", "requirements.txt"], check=True, cwd=str(PYTHON_PROJECT_DIR))
    subprocess.run([str(venv_pip), "install", "pyinstaller"], check=True, cwd=str(PYTHON_PROJECT_DIR))

    # 3. 隔离打包
    subprocess.run([
        str(venv_pyinstaller),
        "--onefile",
        "--name", "python_server",
        "--clean",
        "main.py",
    ], check=True, cwd=str(PYTHON_PROJECT_DIR))

def build_flutter():
    if sys.platform == "win32":
        cmd = "flutter build windows --release"
    else:
        cmd = "flutter build linux --release"
    run_command(cmd, FLUTTER_PROJECT_DIR, "Flutter Release build")

def assemble():
    print("\n📦 [assemble] assembling Flutter Bundle...")
    TARGET_BACKEND_DIR.mkdir(parents=True, exist_ok=True)

    # 复制 Rust 产物
    rust_bin_name = "omnistore-daemon" + BINARY_EXT
    rust_src = RUST_PROJECT_DIR / "target" / "release" / rust_bin_name
    if rust_src.exists():
        shutil.copy2(rust_src, TARGET_BACKEND_DIR / rust_bin_name)
        print(f"✅ copy rust artifacts: {rust_bin_name}")
    else:
        print(f"⚠️ can not find rust artifacts: {rust_src}")

    # 复制 Python 产物
    python_bin_name = "python_server" + BINARY_EXT
    python_src = PYTHON_PROJECT_DIR / "dist" / python_bin_name
    if python_src.exists():
        shutil.copy2(python_src, TARGET_BACKEND_DIR / python_bin_name)
        print(f"✅ copy python artifacts: {python_bin_name}")
    else:
        print(f"⚠️ can not find python artifacts: {python_src}")

    print(f"\n🎉 🎉 🎉 all done!")
    print(f"📁 final bundle directory: {FLUTTER_BUNDLE_DIR}")

def main():
    parser = argparse.ArgumentParser(description="OmniStore auto build script")
    parser.add_argument("--all", action="store_true", help="build everything (Rust + Python + Flutter)")
    parser.add_argument("--rust", action="store_true", help="only build Rust daemon")
    parser.add_argument("--python", action="store_true", help="only build Python backend")
    parser.add_argument("--flutter", action="store_true", help="only build Flutter frontend")
    parser.add_argument("--assemble", action="store_true", help="only execute assembly step (copy binaries into Flutter bundle)")

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
