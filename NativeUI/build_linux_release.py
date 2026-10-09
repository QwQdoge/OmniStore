#!/usr/bin/env python3
"""Build the native Qt/QML + MeoUI OmniStore release bundle for MeoArch.

This Linux release path intentionally does not build or assemble Flutter. It
reuses the existing PyInstaller backend build helper, then assembles the
release bundle around the native client and the shared backend contracts.
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
REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT_ROOT = REPO_ROOT.parent / "outputs"


def _load_auto_build():
    spec = importlib.util.spec_from_file_location(
        "omnistore_auto_build", REPO_ROOT / "auto_build.py"
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("Could not load auto_build.py for backend packaging")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


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


def build_backend(build_root: Path) -> Path:
    auto_build = _load_auto_build()
    auto_build.build_python(build_root)
    backend = auto_build.pyinstaller_paths(build_root, "python_server")["dist"] / "python_server"
    if not backend.is_file():
        raise RuntimeError(f"backend build did not produce {backend}")
    return backend


def _native_parallelism() -> int:
    """Return a conservative release-build parallelism value.

    MeoUI compiles a large generated QML resource translation unit. Hosted CI
    runners can OOM when CMake expands to every advertised CPU, so release
    builds default to two jobs. Builders with known memory headroom can raise
    this explicitly without changing the release contract.
    """
    raw = os.environ.get("OMNISTORE_BUILD_JOBS", "2").strip()
    try:
        jobs = int(raw)
    except ValueError as exc:
        raise RuntimeError("OMNISTORE_BUILD_JOBS must be a positive integer") from exc
    if jobs < 1:
        raise RuntimeError("OMNISTORE_BUILD_JOBS must be at least 1")
    return jobs


def build_native(build_root: Path, meoui_source: Path, release_version: str) -> Path:
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
        f"-DOMNISTORE_RELEASE_VERSION={release_version}",
    ])
    run([
        "cmake",
        "--build",
        str(native_build),
        "--target",
        "omnistore-native",
        "--parallel",
        str(_native_parallelism()),
    ])

    binary = native_build / "omnistore-native"
    if not binary.is_file():
        raise RuntimeError(f"native build did not produce {binary}")
    return binary


def _copy_tree(source: Path, destination: Path) -> None:
    if source.is_dir():
        shutil.copytree(source, destination, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))


def assemble_native_bundle(
    bundle: Path,
    *,
    backend: Path,
    native_binary: Path,
    release_version: str,
) -> None:
    bundle.mkdir(parents=True, exist_ok=True)

    backend_dir = bundle / "backends"
    backend_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(backend, backend_dir / "python_server")
    (backend_dir / "python_server").chmod((backend_dir / "python_server").stat().st_mode | 0o111)

    for helper_name in ("meo_stable_rollback.py", "meo_repository_helper.py"):
        helper = REPO_ROOT / "python" / "helpers" / helper_name
        if not helper.is_file():
            raise RuntimeError(f"required backend helper is missing: {helper}")
        shutil.copy2(helper, backend_dir / helper_name)
        (backend_dir / helper_name).chmod((backend_dir / helper_name).stat().st_mode | 0o111)

    destination = bundle / "omnistore-native"
    shutil.copy2(native_binary, destination)
    destination.chmod(destination.stat().st_mode | 0o111)

    _copy_tree(REPO_ROOT / "plugins" / "sources", bundle / "plugins" / "sources")
    _copy_tree(REPO_ROOT / "data" / "app-manifests", bundle / "data" / "app-manifests")
    _copy_tree(REPO_ROOT / "data" / "systemd" / "user", bundle / "data" / "systemd" / "user")

    docs_dir = bundle / "data" / "docs"
    docs_dir.mkdir(parents=True, exist_ok=True)
    for doc_name in (
        "UNIFIED_UPDATES.md",
        "NATIVE_MEOUI_FRONTEND.md",
        "TRANSACTION_RELEASE_CONTRACT.md",
    ):
        source = REPO_ROOT / "docs" / doc_name
        if source.is_file():
            shutil.copy2(source, docs_dir / doc_name)

    license_file = REPO_ROOT / "LICENSE"
    if not license_file.is_file():
        raise RuntimeError(f"required project license is missing: {license_file}")
    shutil.copy2(license_file, bundle / "LICENSE")

    icon = REPO_ROOT / "omnistore.svg"
    if icon.is_file():
        shutil.copy2(icon, bundle / "omnistore.svg")

    marker = bundle / "data" / "native-ui-v2"
    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.write_text(
        "OmniStore MeoArch release: Qt/QML + MeoUI is the only graphical frontend.\n"
        f"Version: {release_version}\n",
        encoding="utf-8",
    )

    stale_frontend = bundle / "frontend"
    if stale_frontend.exists():
        if stale_frontend.is_dir():
            shutil.rmtree(stale_frontend)
        else:
            stale_frontend.unlink()

    print(f"[native-release] native frontend: {destination}")
    print(f"[native-release] backend: {backend_dir / 'python_server'}")
    print(f"[native-release] bundle: {bundle}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build the native MeoUI OmniStore release bundle for MeoArch."
    )
    parser.add_argument("--output-root")
    parser.add_argument("--output-dir")
    parser.add_argument("--build-dir")
    parser.add_argument("--meoui-source")
    parser.add_argument(
        "--version",
        default=os.environ.get("OMNISTORE_VERSION", "development"),
        help="release-visible OmniStore version injected into the native client",
    )
    parser.add_argument(
        "--skip-backend-build",
        action="store_true",
        help="reuse an already built python_server under the configured build root",
    )
    args = parser.parse_args()

    build_root, bundle, meoui_source = resolve_paths(args)
    build_root.mkdir(parents=True, exist_ok=True)
    bundle.mkdir(parents=True, exist_ok=True)

    auto_build = _load_auto_build()
    backend = auto_build.pyinstaller_paths(build_root, "python_server")["dist"] / "python_server"
    if not args.skip_backend_build:
        backend = build_backend(build_root)
    elif not backend.is_file():
        raise RuntimeError(f"--skip-backend-build requested but {backend} does not exist")

    native_binary = build_native(build_root, meoui_source, args.version)
    assemble_native_bundle(
        bundle,
        backend=backend,
        native_binary=native_binary,
        release_version=args.version,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
