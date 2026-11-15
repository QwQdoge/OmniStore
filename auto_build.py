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

# Built-in sources are loaded lazily from reviewed runtime manifests.
# PyInstaller cannot discover those imports by tracing main.py, and several
# source directories are intentional namespace packages, so name every entry
# module explicitly instead of relying on package discovery.
PYINSTALLER_SOURCE_MODULES = (
    "core.sources.pacman",
    "core.sources.pacman.search",
    "core.sources.pacman.download",
    "core.sources.aur.aur",
    "core.sources.flatpak.flatpak",
    "core.sources.appimage.appimage",
    "core.sources.github.github",
    "core.sources.bitu.bitu",
)


def pyinstaller_source_args():
    return [argument for module in PYINSTALLER_SOURCE_MODULES
            for argument in ("--hidden-import", module)]

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
    ] + pyinstaller_source_args() + extra_args + [str(PYTHON_PROJECT_DIR / "main.py")]
    
    subprocess.run(cmd, check=True, cwd=str(PYTHON_PROJECT_DIR))
    print("✅ Python Server Build 成功！")

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


def main():
    parser = argparse.ArgumentParser(description="OmniStore backend build helper (the native bundle is built by src/native-ui/build_linux_release.py)")
    parser.add_argument("--rust", action="store_true", help="only build Rust daemon")
    parser.add_argument("--python", action="store_true", help="only build Python backend")
    parser.add_argument("--build-dir", type=str, default=None, help="PyInstaller build/spec/work root (overrides MEO_OMNISTORE_BUILD_DIR)")
    parser.add_argument("--output-dir", type=str, default=None, help=argparse.SUPPRESS)
    parser.add_argument("--output-root", type=str, default=None, help="shared Projects output root (overrides MEO_OUTPUT_ROOT)")
    args = parser.parse_args()
    if not (args.rust or args.python):
        parser.print_help()
        return
    build_dir, _ = resolve_output_paths(args)
    if args.rust:
        build_rust(build_dir)
    if args.python:
        build_python(build_dir)


if __name__ == "__main__":
    main()
