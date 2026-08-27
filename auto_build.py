import os
import shutil
import subprocess
import sys
import argparse
from pathlib import Path

# ==================== 🛠️ 路径配置 ====================

BASE_DIR = Path(__file__).resolve().parent
DEFAULT_OUTPUT_ROOT = BASE_DIR.parent / "outputs"

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

def resolve_output_paths(args):
    """Resolve shared-output paths without creating them during argument parsing."""
    raw_output_root = (
        args.output_root
        or os.environ.get("MEO_OUTPUT_ROOT")
        or DEFAULT_OUTPUT_ROOT
    )
    project_output_root = Path(raw_output_root).expanduser().resolve() / "omni-store"

    raw_build_dir = args.build_dir or os.environ.get("MEO_OMNISTORE_BUILD_DIR")
    build_dir = (
        Path(raw_build_dir).expanduser().resolve()
        if raw_build_dir
        else project_output_root / "build"
    )

    # An explicit --output-dir must win over all environment and root defaults.
    raw_bundle_dir = (
        args.output_dir
        if args.output_dir is not None
        else os.environ.get("MEO_OMNISTORE_OUTPUT_DIR")
    )
    bundle_dir = (
        Path(raw_bundle_dir).expanduser().resolve()
        if raw_bundle_dir
        else project_output_root / "packages" / f"omnistore-{args.platform}"
    )
    return build_dir, bundle_dir


def pyinstaller_paths(build_dir, target_name):
    target_dir = Path(build_dir) / "pyinstaller" / target_name
    return {
        "spec": target_dir / "spec",
        "work": target_dir / "work",
        "dist": target_dir / "dist",
    }


def ensure_venv(build_dir):
    def venv_tools(path):
        if sys.platform == "win32":
            return path / "Scripts" / "pip.exe", path / "Scripts" / "pyinstaller.exe"
        return path / "bin" / "pip", path / "bin" / "pyinstaller"

    # Prefer a reusable venv only when it matches the current platform layout.
    primary_venv = PYTHON_PROJECT_DIR / ".venv"
    # A fallback virtual environment is build tooling, so it belongs under the
    # shared output tree instead of creating python/build_venv in the source
    # checkout.  A healthy, pre-existing python/.venv remains reusable.
    fallback_venv = Path(build_dir) / "venv"
    venv_dir = primary_venv
    if primary_venv.exists():
        primary_pip, _ = venv_tools(primary_venv)
        if not primary_pip.exists():
            venv_dir = fallback_venv
    else:
        venv_dir = fallback_venv

    venv_pip, venv_pyinstaller = venv_tools(venv_dir)

    if not venv_dir.exists():
        print("Creating virtual environment...")
        try:
            venv_dir.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run([sys.executable, "-m", "venv", str(venv_dir)], check=True, cwd=str(PYTHON_PROJECT_DIR))
        except Exception as e:
            print(f"⚠️ Failed to create virtual environment: {e}")

    if venv_pip.exists():
        print("Checking/installing dependencies...")
        try:
            pip_base = [str(venv_pip), "--disable-pip-version-check"]
            subprocess.run(pip_base + ["install", "-r", "requirements.txt"], check=False, cwd=str(PYTHON_PROJECT_DIR))
            if not venv_pyinstaller.exists():
                subprocess.run(pip_base + ["install", "pyinstaller"], check=False, cwd=str(PYTHON_PROJECT_DIR))
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

def build_rust(build_dir):
    print("\n🚀 [正在执行] Python Daemon Build...")
    pyinstaller, extra_args = ensure_venv(build_dir)
    output_paths = pyinstaller_paths(build_dir, "omnistore-daemon")
    for path in output_paths.values():
        path.mkdir(parents=True, exist_ok=True)
    cmd = [
        pyinstaller,
        "--onefile",
        "--name", "omnistore-daemon",
        "--clean",
        "--specpath", str(output_paths["spec"]),
        "--workpath", str(output_paths["work"]),
        "--distpath", str(output_paths["dist"]),
    ] + extra_args + [str(PYTHON_PROJECT_DIR / "daemon_main.py")]
    
    subprocess.run(cmd, check=True, cwd=str(PYTHON_PROJECT_DIR))
    print("✅ Python Daemon Build 成功！")

def build_python(build_dir):
    print("\n🚀 [正在执行] Python Server Build...")
    pyinstaller, extra_args = ensure_venv(build_dir)
    output_paths = pyinstaller_paths(build_dir, "python_server")
    for path in output_paths.values():
        path.mkdir(parents=True, exist_ok=True)
    cmd = [
        pyinstaller,
        "--onefile",
        "--name", "python_server",
        "--clean",
        "--exclude-module", "PyQt5",
        "--exclude-module", "PySide6",
        "--specpath", str(output_paths["spec"]),
        "--workpath", str(output_paths["work"]),
        "--distpath", str(output_paths["dist"]),
    ] + extra_args + [str(PYTHON_PROJECT_DIR / "main.py")]
    
    subprocess.run(cmd, check=True, cwd=str(PYTHON_PROJECT_DIR))
    print("✅ Python Server Build 成功！")

def build_flutter(platform):
    cmd = f"flutter build {platform} --release"
    run_command(cmd, FLUTTER_PROJECT_DIR, f"Flutter {platform} Release build")


def copy_builtin_source_manifests(bundle_dir):
    """Ship the manifest layer that the frozen backend resolves at runtime.

    ``python_server`` contains the builtin source implementations, but the
    runtime registry intentionally reads the trusted source manifests next to
    the release bundle.  Without them a PyInstaller backend can start and
    still report an empty source inventory.
    """
    manifests_src = BASE_DIR / "plugins" / "sources"
    manifests_dest = bundle_dir / "plugins" / "sources"
    if not manifests_src.is_dir():
        print(f"⚠️ can not find built-in source manifests: {manifests_src}")
        return False
    shutil.copytree(
        manifests_src,
        manifests_dest,
        dirs_exist_ok=True,
        ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
    )
    print("✅ copy built-in source manifests")
    return True


def assemble(platform, output_dir, build_dir):
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
    rust_src = pyinstaller_paths(build_dir, "omnistore-daemon")["dist"] / rust_bin_name
    if rust_src.exists():
        shutil.copy2(rust_src, target_backend_dir / rust_bin_name)
        print(f"✅ copy rust artifacts: {rust_bin_name}")
    else:
        print(f"⚠️ can not find rust artifacts: {rust_src}")

    # 复制 Python 产物
    python_bin_name = "python_server" + binary_ext
    python_src = pyinstaller_paths(build_dir, "python_server")["dist"] / python_bin_name
    if python_src.exists():
        shutil.copy2(python_src, target_backend_dir / python_bin_name)
        print(f"✅ copy python artifacts: {python_bin_name}")
    else:
        print(f"⚠️ can not find python artifacts: {python_src}")

    copy_builtin_source_manifests(flutter_bundle_dir)

    icon_src = BASE_DIR / "omnistore.svg"
    if icon_src.exists():
        shutil.copy2(icon_src, flutter_bundle_dir / "omnistore.svg")
        print("✅ copy icon artifact: omnistore.svg")
    else:
        print(f"⚠️ can not find icon artifact: {icon_src}")

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
    parser.add_argument(
        "--output-dir",
        type=str,
        default=None,
        help="exact assembled-bundle directory; takes priority over environment/default paths",
    )
    parser.add_argument(
        "--output-root",
        type=str,
        default=None,
        help="shared Projects output root (overrides MEO_OUTPUT_ROOT)",
    )
    parser.add_argument(
        "--build-dir",
        type=str,
        default=None,
        help="PyInstaller build/spec/work root (overrides MEO_OMNISTORE_BUILD_DIR)",
    )

    args = parser.parse_args()

    # 如果没有任何参数，默认显示帮助
    if not any([args.all, args.rust, args.python, args.flutter, args.assemble]):
        parser.print_help()
        return

    build_dir, output_dir = resolve_output_paths(args)

    # APK 不需要 Python 和 Rust 后端
    if args.platform == "apk":
        if args.all or args.flutter:
            build_flutter("apk")
        if args.all or args.assemble:
            assemble("apk", output_dir, build_dir)
        return

    if args.all or args.rust:
        build_rust(build_dir)

    if args.all or args.python:
        build_python(build_dir)

    if args.all or args.flutter:
        build_flutter(args.platform)

    if args.all or args.rust or args.python or args.flutter or args.assemble:
        assemble(args.platform, output_dir, build_dir)

if __name__ == "__main__":
    main()
