import importlib.util
from pathlib import Path


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
