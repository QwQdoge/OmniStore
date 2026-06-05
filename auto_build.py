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

    # Windows 下路径不同
    if sys.platform == "win32":
        venv_pip = venv_dir / "Scripts" / "pip.exe"
        venv_pyinstaller = venv_dir / "Scripts" / "pyinstaller.exe"

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
        "--specpath", str(PYTHON_PROJECT_DIR / "build_cache"), # 👈 缓存 spec 丢这里
        "--workpath", str(PYTHON_PROJECT_DIR / "build_cache"), # 👈 缓存 build 丢这里
        str(PYTHON_PROJECT_DIR / "main.py"),
    ], check=True, cwd=str(PYTHON_PROJECT_DIR))

def build_flutter(platform):
    cmd = f"flutter build {platform} --release"
    run_command(cmd, FLUTTER_PROJECT_DIR, f"Flutter {platform} Release build")

def assemble(platform, output_dir):
    print("\n📦 [assemble] assembling Flutter Bundle...")

    if platform == "windows":
        flutter_bundle_dir = FLUTTER_PROJECT_DIR / "build/windows/x64/runner/Release"
        binary_ext = ".exe"
    elif platform == "macos":
        flutter_bundle_dir = FLUTTER_PROJECT_DIR / "build/macos/Build/Products/Release"
        binary_ext = ""
    elif platform == "apk":
        flutter_bundle_dir = FLUTTER_PROJECT_DIR / "build/app/outputs/flutter-apk"
        binary_ext = ""
    else:
        flutter_bundle_dir = FLUTTER_PROJECT_DIR / "build/linux/x64/release/bundle"
        binary_ext = ""

    out_path = Path(output_dir).resolve()
    out_path.mkdir(parents=True, exist_ok=True)

    if platform == "apk":
        # APK 只有单个文件，没有 backend，直接拷贝
        apk_src = flutter_bundle_dir / "app-release.apk"
        if apk_src.exists():
            shutil.copy2(apk_src, out_path / "omnistore.apk")
            print(f"✅ copy apk artifacts: omnistore.apk")
        else:
            print(f"⚠️ can not find apk artifacts: {apk_src}")
        print(f"\n🎉 🎉 🎉 all done!")
        print(f"📁 final bundle directory: {out_path}")
        return

    # 对于非 APK，我们要组装 backend
    target_backend_dir = flutter_bundle_dir / "backends"
    target_backend_dir.mkdir(parents=True, exist_ok=True)

    # 复制 Rust 产物
    rust_bin_name = "omnistore-daemon" + binary_ext
    rust_src = RUST_PROJECT_DIR / "target" / "release" / rust_bin_name
    if rust_src.exists():
        shutil.copy2(rust_src, target_backend_dir / rust_bin_name)
        print(f"✅ copy rust artifacts: {rust_bin_name}")
    else:
        print(f"⚠️ can not find rust artifacts: {rust_src}")

    # 复制 Python 产物
    python_bin_name = "python_server" + binary_ext
    python_src = PYTHON_PROJECT_DIR / "dist" / python_bin_name
    if python_src.exists():
        shutil.copy2(python_src, target_backend_dir / python_bin_name)
        print(f"✅ copy python artifacts: {python_bin_name}")
    else:
        print(f"⚠️ can not find python artifacts: {python_src}")

    # 最后，将整个 flutter_bundle_dir 复制到 output_dir
    print(f"📦 Copying full bundle to {out_path} ...")
    if flutter_bundle_dir.exists():
        # 如果目标目录不为空，先清空或使用 dirs_exist_ok=True
        shutil.copytree(flutter_bundle_dir, out_path, dirs_exist_ok=True)
        print(f"✅ copy bundle to output directory")
    else:
        print(f"⚠️ flutter bundle directory not found: {flutter_bundle_dir}")

    print(f"\n🎉 🎉 🎉 all done!")
    print(f"📁 final bundle directory: {out_path}")

def main():
    parser = argparse.ArgumentParser(description="OmniStore auto build script")
    parser.add_argument("--all", action="store_true", help="build everything (Rust + Python + Flutter)")
    parser.add_argument("--rust", action="store_true", help="only build Rust daemon")
    parser.add_argument("--python", action="store_true", help="only build Python backend")
    parser.add_argument("--flutter", action="store_true", help="only build Flutter frontend")
    parser.add_argument("--assemble", action="store_true", help="only execute assembly step (copy binaries into Flutter bundle)")
    parser.add_argument("--platform", type=str, default="linux", choices=["linux", "windows", "macos", "apk"], help="target platform (default: linux)")
    parser.add_argument("--output-dir", type=str, default="release_bundle", help="output directory for the assembled bundle")

    args = parser.parse_args()

    # 如果没有任何参数，默认显示帮助
    if not any([args.all, args.rust, args.python, args.flutter, args.assemble]):
        parser.print_help()
        return

    # APK 不需要 Python 和 Rust 后端
    if args.platform == "apk":
        if args.all or args.flutter:
            build_flutter("apk")
        if args.all or args.assemble:
            assemble("apk", args.output_dir)
        return

    if args.all or args.rust:
        build_rust()

    if args.all or args.python:
        build_python()

    if args.all or args.flutter:
        build_flutter(args.platform)

    if args.all or args.rust or args.python or args.flutter or args.assemble:
        assemble(args.platform, args.output_dir)

if __name__ == "__main__":
    main()
