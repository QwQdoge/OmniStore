#!/usr/bin/env python3
"""Build the OmniStore desktop bundle for macOS (.app, .dmg) or Windows (folder, .zip).

Steps: freeze the Python backend with PyInstaller, build the Qt/QML client with
OMNISTORE_BUNDLE=ON, run macdeployqt / windeployqt, place the backend where
BackendLocator looks for it (macOS: Contents/Resources/backends, Windows: backends\\
next to the executable), then archive.

Run on the target OS. It cannot cross-compile.
"""

from __future__ import annotations

import argparse
import importlib.util
import os
import shutil
import subprocess
import sys
from pathlib import Path

NATIVE_ROOT = Path(__file__).resolve().parent
REPO_ROOT = NATIVE_ROOT.parents[1]


def run(command: list[str], cwd: Path | None = None) -> None:
    print("+", " ".join(command), flush=True)
    subprocess.run(command, cwd=cwd, check=True)


def load_auto_build():
    spec = importlib.util.spec_from_file_location("omnistore_auto_build", REPO_ROOT / "auto_build.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def find_tool(name: str) -> str:
    found = shutil.which(name)
    if found:
        return found
    qt_bin = os.environ.get("QT_BIN_DIR")
    if qt_bin and (Path(qt_bin) / name).exists():
        return str(Path(qt_bin) / name)
    raise SystemExit(f"{name} not found; add Qt's bin directory to PATH or set QT_BIN_DIR.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--meoui-source", default=os.environ.get("MEOUI_SOURCE_DIR", ""))
    parser.add_argument("--version", default="development")
    parser.add_argument("--build-dir", default=str(REPO_ROOT / "build" / "desktop"))
    parser.add_argument("--output-dir", default=str(REPO_ROOT / "dist"))
    parser.add_argument("--skip-backend", action="store_true", help="reuse an existing frozen backend")
    args = parser.parse_args()

    if sys.platform not in ("darwin", "win32"):
        raise SystemExit("This script packages macOS and Windows. Linux uses build_linux_release.py.")
    meoui = Path(args.meoui_source)
    if not (meoui / "CMakeLists.txt").is_file():
        raise SystemExit("Pass --meoui-source (or MEOUI_SOURCE_DIR) pointing at a MeoUI checkout.")

    build = Path(args.build_dir).resolve()
    output = Path(args.output_dir).resolve()
    build.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    exe = ".exe" if sys.platform == "win32" else ""

    auto_build = load_auto_build()
    if not args.skip_backend:
        auto_build.build_python(build)
    backend = auto_build.pyinstaller_paths(build, "python_server")["dist"] / f"python_server{exe}"
    if not backend.is_file():
        raise SystemExit(f"Frozen backend not found at {backend}")

    native = build / "native-ui"
    run(["cmake", "-S", str(NATIVE_ROOT), "-B", str(native), "-DCMAKE_BUILD_TYPE=Release",
         "-DOMNISTORE_BUNDLE=ON", f"-DMEOUI_SOURCE_DIR={meoui}",
         f"-DOMNISTORE_RELEASE_VERSION={args.version}"])
    run(["cmake", "--build", str(native), "--target", "omnistore-native", "--config", "Release",
         "--parallel", str(os.cpu_count() or 2)])

    if sys.platform == "darwin":
        app = native / "omnistore-native.app"
        if not app.is_dir():
            raise SystemExit(f"{app} was not produced")
        final = output / "OmniStore.app"
        if final.exists():
            shutil.rmtree(final)
        shutil.copytree(app, final, symlinks=True)
        run([find_tool("macdeployqt"), str(final), f"-qmldir={NATIVE_ROOT / 'qml'}"])
        backends = final / "Contents" / "Resources" / "backends"
        backends.mkdir(parents=True, exist_ok=True)
        shutil.copy2(backend, backends / "python_server")
        shutil.copytree(REPO_ROOT / "plugins", final / "Contents" / "Resources" / "plugins",
                        dirs_exist_ok=True, ignore=shutil.ignore_patterns("__pycache__"))
        marker_dir = final / "Contents" / "Resources" / "data"   # PluginRegistry finds the bundle by this marker
        marker_dir.mkdir(parents=True, exist_ok=True)
        (marker_dir / "native-ui-v2").write_text("native-ui-v2\n")
        for notice in ("LICENSE", "THIRD_PARTY_NOTICES.md"):
            if (REPO_ROOT / notice).is_file():
                shutil.copy2(REPO_ROOT / notice, final / "Contents" / "Resources" / notice)
        dmg = output / f"OmniStore-{args.version}.dmg"
        if dmg.exists():
            dmg.unlink()
        run(["hdiutil", "create", "-volname", "OmniStore", "-srcfolder", str(final), "-ov", str(dmg)])
        print(f"Built {final} and {dmg} (unsigned: sign and notarize before distributing).")
    else:
        exe_path = next((p for p in (native / "Release" / "omnistore-native.exe",
                                     native / "omnistore-native.exe") if p.is_file()), None)
        if exe_path is None:
            raise SystemExit("omnistore-native.exe was not produced")
        final = output / "OmniStore"
        if final.exists():
            shutil.rmtree(final)
        final.mkdir(parents=True)
        shutil.copy2(exe_path, final / "OmniStore.exe")
        run([find_tool("windeployqt"), "--qmldir", str(NATIVE_ROOT / "qml"), str(final / "OmniStore.exe")])
        (final / "backends").mkdir()
        shutil.copy2(backend, final / "backends" / "python_server.exe")
        shutil.copytree(REPO_ROOT / "plugins", final / "plugins", dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns("__pycache__"))
        (final / "data").mkdir()
        (final / "data" / "native-ui-v2").write_text("native-ui-v2\n")
        for notice in ("LICENSE", "THIRD_PARTY_NOTICES.md"):
            if (REPO_ROOT / notice).is_file():
                shutil.copy2(REPO_ROOT / notice, final / notice)
        archive = shutil.make_archive(str(output / f"OmniStore-{args.version}-windows"), "zip", output, "OmniStore")
        print(f"Built {final} and {archive} (unsigned).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
