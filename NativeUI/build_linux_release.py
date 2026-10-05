#!/usr/bin/env python3
"""Build the MeoUI Linux frontend and overlay it onto the normal OmniStore bundle.

The existing auto_build.py remains authoritative for the frozen Python backend,
source manifests, license, update units, and Flutter fallback.  This script is
Linux-only: it invokes that existing release assembly first, then adds the
native Qt/QML executable without changing Windows, macOS, or APK packaging.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
NATIVE_ROOT = REPO_ROOT / "NativeUI"
DEFAULT_OUTPUT_ROOT = REPO_ROOT.parent / "outputs"


def resolve_paths(args: argparse.Namespace) -> tuple[Path, Path, Path]:
    output_root = Path(
        args.output_root
        or os.environ.get("MEO_OUTPUT_ROOT")
        or DEFAULT_OUTPUT_ROOT
    ).expanduser().resolve()

    build_root = Path(
        args.build_dir
        or os.environ.get("MEO_OMNISTORE_BUILD_DIR")
        or output_root / "omni-store" / "build"
    ).expanduser().resolve()

    bundle = Path(
        args.output_dir
        or os.environ.get("MEO_OMNISTORE_OUTPUT_DIR")
        or output_root / "omni-store" / "packages" / "omnistore-linux"
    ).expanduser().resolve()

    raw_meoui = args.meoui_source or os.environ.get("MEOUI_SOURCE_DIR")
    if not raw_meoui:
        sibling_candidates = (
            REPO_ROOT.parent / "MeoUI",
            REPO_ROOT.parent / "meo-ui",
        )
        raw_meoui = next(
            (str(path) for path in sibling_candidates if (path / "CMakeLists.txt").is_file()),
            "",
        )
    meoui = Path(raw_meoui).expanduser().resolve() if raw_meoui else Path()
    return build_root, bundle, meoui


def run(command: list[str], *, cwd: Path | None = None) -> None:
    printable = " ".join(command)
    print(f"[native-release] {printable}")
    subprocess.run(command, cwd=str(cwd) if cwd else None, check=True)


def build_existing_bundle(args: argparse.Namespace, build_root: Path, bundle: Path) -> None:
    command = [
        sys.executable,
        str(REPO_ROOT / "auto_build.py"),
        "--all",
        "--platform",
        "linux",
        "--build-dir",
        str(build_root),
        "--output-dir",
        str(bundle),
    ]
    if args.allow_account_disabled:
        command.append("--allow-account-disabled")
    run(command, cwd=REPO_ROOT)


def build_native(build_root: Path, meoui_source: Path) -> Path:
    if not meoui_source or not (meoui_source / "CMakeLists.txt").is_file():
        raise RuntimeError(
            "MeoUI source checkout is required for the native release build. "
            "Pass --meoui-source or set MEOUI_SOURCE_DIR."
        )

    native_build = build_root / "native-ui"
    native_build.mkdir(parents=True, exist_ok=True)
    run([
        "cmake",
        "--fresh",
        "-S",
        str(NATIVE_ROOT),
        "-B",
        str(native_build),
        "-DCMAKE_BUILD_TYPE=Release",
        f"-DMEOUI_SOURCE_DIR={meoui_source}",
    ])
    run([
        "cmake",
        "--build",
        str(native_build),
        "--target",
        "omnistore-native",
        "--parallel",
    ])

    binary = native_build / "omnistore-native"
    if not binary.is_file():
        raise RuntimeError(f"native build did not produce {binary}")
    return binary


def overlay_native(bundle: Path, binary: Path) -> None:
    required_existing = (
        bundle / "frontend",
        bundle / "backends" / "python_server",
        bundle / "LICENSE",
    )
    missing = [str(path) for path in required_existing if not path.exists()]
    if missing:
        raise RuntimeError(
            "refusing to overlay an incomplete Linux release bundle: " + ", ".join(missing)
        )

    destination = bundle / "omnistore-native"
    shutil.copy2(binary, destination)
    destination.chmod(destination.stat().st_mode | 0o111)

    marker = bundle / "data" / "native-ui-v1"
    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.write_text(
        "OmniStore NativeUI contract: Qt/QML + MeoUI frontend; Flutter frontend retained as fallback.\n",
        encoding="utf-8",
    )
    print(f"[native-release] native frontend: {destination}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build the normal Linux OmniStore bundle and overlay the MeoUI NativeUI frontend."
    )
    parser.add_argument("--output-root")
    parser.add_argument("--output-dir")
    parser.add_argument("--build-dir")
    parser.add_argument("--meoui-source")
    parser.add_argument(
        "--allow-account-disabled",
        action="store_true",
        help="forward the intentionally-offline developer option to auto_build.py",
    )
    parser.add_argument(
        "--skip-base-bundle",
        action="store_true",
        help="overlay an already assembled Linux bundle instead of rerunning auto_build.py",
    )
    args = parser.parse_args()

    build_root, bundle, meoui_source = resolve_paths(args)
    build_root.mkdir(parents=True, exist_ok=True)
    bundle.mkdir(parents=True, exist_ok=True)

    if not args.skip_base_bundle:
        build_existing_bundle(args, build_root, bundle)
    binary = build_native(build_root, meoui_source)
    overlay_native(bundle, binary)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
