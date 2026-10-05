import importlib.util
from pathlib import Path
from types import SimpleNamespace


_REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
_SPEC = importlib.util.spec_from_file_location("omnistore_auto_build", _REPOSITORY_ROOT / "auto_build.py")
assert _SPEC is not None and _SPEC.loader is not None
auto_build = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(auto_build)


def test_assembly_copies_builtin_source_manifests_without_python_cache(tmp_path, monkeypatch):
    source_root = tmp_path / "source"
    manifest = source_root / "plugins" / "sources" / "pacman" / "plugin.json"
    manifest.parent.mkdir(parents=True)
    manifest.write_text('{"id": "builtin.pacman"}', encoding="utf-8")
    cache = manifest.parent / "__pycache__" / "stale.pyc"
    cache.parent.mkdir()
    cache.write_bytes(b"stale")
    monkeypatch.setattr(auto_build, "BASE_DIR", source_root)

    bundle = tmp_path / "bundle"
    assert auto_build.copy_builtin_source_manifests(bundle)
    assert (bundle / "plugins" / "sources" / "pacman" / "plugin.json").is_file()
    assert not (bundle / "plugins" / "sources" / "pacman" / "__pycache__").exists()


def test_assembly_reports_missing_manifest_source(tmp_path, monkeypatch):
    monkeypatch.setattr(auto_build, "BASE_DIR", tmp_path / "missing")
    assert not auto_build.copy_builtin_source_manifests(tmp_path / "bundle")


def test_release_bundle_carries_project_license(tmp_path, monkeypatch):
    source_root = tmp_path / "source"
    flutter_root = source_root / "FlutterUI"
    bundle = flutter_root / "build" / "linux" / "x64" / "release" / "bundle"
    bundle.mkdir(parents=True)
    (bundle / "frontend").write_text("fixture", encoding="utf-8")
    (source_root / "LICENSE").write_text("GNU GENERAL PUBLIC LICENSE\n", encoding="utf-8")
    monkeypatch.setattr(auto_build, "BASE_DIR", source_root)
    monkeypatch.setattr(auto_build, "FLUTTER_PROJECT_DIR", flutter_root)

    output = tmp_path / "output"
    auto_build.assemble("linux", output, tmp_path / "build")

    assert (output / "LICENSE").read_text(encoding="utf-8") == "GNU GENERAL PUBLIC LICENSE\n"


def test_frozen_backend_collects_manifest_loaded_source_modules(tmp_path, monkeypatch):
    commands = []
    pyinstaller = tmp_path / "pyinstaller"
    pyinstaller.touch()
    monkeypatch.setattr(auto_build, "ensure_venv", lambda _build_dir: (str(pyinstaller), []))
    monkeypatch.setattr(
        auto_build.subprocess,
        "run",
        lambda command, **_kwargs: commands.append(command) or SimpleNamespace(returncode=0),
    )

    auto_build.build_python(tmp_path / "build")

    assert len(commands) == 1
    hidden_modules = {
        argument
        for index, argument in enumerate(commands[0])
        if index and commands[0][index - 1] == "--hidden-import"
    }
    assert hidden_modules == set(auto_build.PYINSTALLER_SOURCE_MODULES)
    assert {
        "core.sources.pacman",
        "core.sources.aur.aur",
        "core.sources.flatpak.flatpak",
        "core.sources.appimage.appimage",
        "core.sources.github.github",
        "core.sources.bitu.bitu",
    } <= hidden_modules
