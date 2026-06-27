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

def ensure_venv():
    # Check if .venv already exists in the project
    venv_dir = PYTHON_PROJECT_DIR / ".venv"
    if not venv_dir.exists():
        venv_dir = PYTHON_PROJECT_DIR / "build_venv"

    venv_pip = venv_dir / "bin" / "pip"
    venv_pyinstaller = venv_dir / "bin" / "pyinstaller"

    if sys.platform == "win32":
        venv_pip = venv_dir / "Scripts" / "pip.exe"
        venv_pyinstaller = venv_dir / "Scripts" / "pyinstaller.exe"

    if not venv_dir.exists():
        print("Creating virtual environment...")
        try:
            subprocess.run([sys.executable, "-m", "venv", str(venv_dir)], check=True, cwd=str(PYTHON_PROJECT_DIR))
        except Exception as e:
            print(f"⚠️ Failed to create virtual environment: {e}")

    if venv_pip.exists():
        print("Checking/installing dependencies...")
        try:
            subprocess.run([str(venv_pip), "install", "-r", "requirements.txt"], check=False, cwd=str(PYTHON_PROJECT_DIR))
            subprocess.run([str(venv_pip), "install", "pyinstaller"], check=False, cwd=str(PYTHON_PROJECT_DIR))
        except Exception as e:
            print(f"⚠️ Dependency installation skipped/failed (possibly offline): {e}")

    # Determine PyInstaller path and extra paths for packaging
    import shutil
    pyinstaller_path = None
    extra_args = []

    if venv_pyinstaller.exists():
        pyinstaller_path = str(venv_pyinstaller)
    else:
        system_py = shutil.which("pyinstaller")
        if system_py:
            print(f"Using system PyInstaller: {system_py}")
            pyinstaller_path = system_py
            site_packages = venv_dir / "lib" / f"python{sys.version_info.major}.{sys.version_info.minor}" / "site-packages"
            if sys.platform == "win32":
                site_packages = venv_dir / "Lib" / "site-packages"
            if site_packages.exists():
                extra_args = ["--paths", str(site_packages)]
        else:
            raise RuntimeError("PyInstaller could not be found in the virtual environment or system PATH.")

    return pyinstaller_path, extra_args

def build_rust():
    print("\n🚀 [正在执行] Python Daemon Build...")
    pyinstaller, extra_args = ensure_venv()
    cmd = [
        pyinstaller,
        "--onefile",
        "--name", "omnistore-daemon",
        "--clean",
        "--specpath", str(PYTHON_PROJECT_DIR / "build_cache"),
        "--workpath", str(PYTHON_PROJECT_DIR / "build_cache"),
    ] + extra_args + [str(PYTHON_PROJECT_DIR / "daemon_main.py")]
    
    subprocess.run(cmd, check=True, cwd=str(PYTHON_PROJECT_DIR))
    print("✅ Python Daemon Build 成功！")

def build_python():
    print("\n🚀 [正在执行] Python Server Build...")
    pyinstaller, extra_args = ensure_venv()
    cmd = [
        pyinstaller,
        "--onefile",
        "--name", "python_server",
        "--clean",
        "--exclude-module", "PyQt5",
        "--exclude-module", "PySide6",
        "--specpath", str(PYTHON_PROJECT_DIR / "build_cache"),
        "--workpath", str(PYTHON_PROJECT_DIR / "build_cache"),
    ] + extra_args + [str(PYTHON_PROJECT_DIR / "main.py")]
    
    subprocess.run(cmd, check=True, cwd=str(PYTHON_PROJECT_DIR))
    print("✅ Python Server Build 成功！")

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
    rust_src = PYTHON_PROJECT_DIR / "dist" / rust_bin_name
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
