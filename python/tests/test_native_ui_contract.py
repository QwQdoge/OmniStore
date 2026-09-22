import importlib.util
from pathlib import Path
import re

import pytest


ROOT = Path(__file__).resolve().parents[2]
NATIVE = ROOT / "NativeUI"
QML_ROOT = NATIVE / "qml"
TEXT_SOURCE_SUFFIXES = {".py", ".qml", ".cpp", ".h", ".md", ".txt"}

_RELEASE_SPEC = importlib.util.spec_from_file_location(
    "omnistore_native_release", NATIVE / "build_linux_release.py"
)
assert _RELEASE_SPEC is not None and _RELEASE_SPEC.loader is not None
native_release = importlib.util.module_from_spec(_RELEASE_SPEC)
_RELEASE_SPEC.loader.exec_module(native_release)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def native_text_sources():
    for path in NATIVE.rglob("*"):
        if not path.is_file() or "__pycache__" in path.parts:
            continue
        if path.name == "CMakeLists.txt" or path.suffix in TEXT_SOURCE_SUFFIXES:
            yield path


def test_native_ui_uses_meoui_adaptive_shell():
    main = read(QML_ROOT / "Main.qml")
    assert "import MeoUI 1.0" in main
    assert "MeoAppLayout" in main
    assert all(label in main for label in (
        'qsTr("Home")',
        'qsTr("Search")',
        'qsTr("Updates")',
        'qsTr("Installed")',
        'qsTr("Tasks")',
        'qsTr("Settings")',
    ))
    assert "MeoSideSheet" in main


def test_every_native_qml_file_is_declared_in_cmake_module():
    cmake = read(NATIVE / "CMakeLists.txt")
    qml_files = sorted(
        path.relative_to(NATIVE).as_posix()
        for path in QML_ROOT.rglob("*.qml")
    )
    missing = [path for path in qml_files if path not in cmake]
    assert missing == []


def test_backend_bridge_never_uses_a_shell_for_package_actions():
    bridge = read(NATIVE / "app" / "backendbridge.cpp")
    forbidden = (
        "/bin/sh",
        "/bin/bash",
        "runInShell",
        "system(",
        "popen(",
        "QProcess::execute(QStringLiteral(\"sh\")",
    )
    assert not any(token in bridge for token in forbidden)
    assert "process->start(m_backendProgram, arguments)" in bridge
    assert "QStringList arguments" in bridge


def test_native_actions_reuse_existing_backend_cli_contract():
    bridge = read(NATIVE / "app" / "backendbridge.cpp")
    for flag in (
        "--recommend",
        "--search",
        "--list-installed",
        "--check-updates",
        "--list-plugins",
        "--get-config",
        "--storage-info",
        "--details",
        "--install",
        "--remove",
        "--update",
        "--launch",
        "--set-plugin-enabled",
        "--json",
    ):
        assert flag in bridge


def test_mutating_ui_actions_have_explicit_confirmation_surfaces():
    app_row = read(QML_ROOT / "components" / "AppRow.qml")
    update_row = read(QML_ROOT / "components" / "UpdateRow.qml")
    details = read(QML_ROOT / "components" / "AppDetailsPane.qml")
    updates = read(QML_ROOT / "pages" / "UpdatesPage.qml")

    assert app_row.count("MeoDialog") >= 2
    assert "onConfirmed: backend.installApp" in app_row
    assert "onConfirmed: backend.removeApp" in app_row
    assert "onConfirmed: backend.updateApp" in update_row
    assert "onConfirmed: backend.installApp" in details
    assert "onConfirmed: backend.removeApp" in details
    assert "onConfirmed: backend.updateAll" in updates


def test_settings_groups_use_meoui_data_models_not_free_form_rows():
    settings = read(QML_ROOT / "pages" / "SettingsPage.qml")
    assert "function pluginRows()" in settings
    groups = settings.split("MeoSettingsGroup {")[1:]
    assert groups
    for group in groups:
        body = group.split("}", 1)[0]
        assert "model:" in body
    assert "trailingControl:" not in settings
    assert "description:" not in settings


def test_meolistitem_is_not_given_settings_only_properties():
    for path in QML_ROOT.rglob("*.qml"):
        text = read(path)
        for match in re.finditer(r"MeoListItem\s*\{", text):
            tail = text[match.end():]
            block = tail.split("}\n", 1)[0]
            assert "trailingKind:" not in block, path


def test_details_only_accept_backend_payload_for_current_app():
    details = read(QML_ROOT / "components" / "AppDetailsPane.qml")
    assert "fallbackIdentity" in details
    assert "selectedIdentity === fallbackIdentity" in details
    assert "selectedMatches ? backend.selectedApp : fallbackApp" in details


def test_native_ui_keeps_flutter_as_fallback_during_migration():
    assert (ROOT / "FlutterUI" / "pubspec.yaml").is_file()
    assert (ROOT / "FlutterUI" / "lib").is_dir()


def test_native_ui_does_not_duplicate_backend_package_logic():
    native_text = "\n".join(read(path) for path in native_text_sources())
    for forbidden in (
        "pacman -S",
        "yay -S",
        "flatpak install",
        "apt install",
        "dnf install",
    ):
        assert forbidden not in native_text


def test_linux_overlay_requires_existing_backend_and_fallback(tmp_path):
    bundle = tmp_path / "bundle"
    bundle.mkdir()
    binary = tmp_path / "omnistore-native"
    binary.write_bytes(b"native")

    with pytest.raises(RuntimeError, match="incomplete Linux release bundle"):
        native_release.overlay_native(bundle, binary)


def test_linux_overlay_adds_native_without_removing_flutter(tmp_path):
    bundle = tmp_path / "bundle"
    (bundle / "backends").mkdir(parents=True)
    (bundle / "frontend").write_bytes(b"flutter")
    (bundle / "backends" / "python_server").write_bytes(b"backend")
    (bundle / "LICENSE").write_text("GPL\n", encoding="utf-8")
    binary = tmp_path / "omnistore-native"
    binary.write_bytes(b"native")

    native_release.overlay_native(bundle, binary)

    assert (bundle / "omnistore-native").read_bytes() == b"native"
    assert (bundle / "frontend").read_bytes() == b"flutter"
    assert (bundle / "backends" / "python_server").read_bytes() == b"backend"
    assert (bundle / "data" / "native-ui-v1").is_file()


def test_arch_package_prefers_native_but_keeps_old_release_compatible():
    pkgbuild = read(ROOT / "PKGBUILD")
    assert "meoui-qml: preferred native Qt/QML frontend on MeoArch" in pkgbuild
    assert "[ -x /opt/omnistore/omnistore-native ]" in pkgbuild
    assert "[ -f /usr/lib/qt6/qml/MeoUI/qmldir ]" in pkgbuild
    assert "exec /opt/omnistore/omnistore-native" in pkgbuild
    assert "exec /opt/omnistore/frontend" in pkgbuild
    # Current published bundles remain valid until a new native asset exists.
    release_check = pkgbuild.split("_release_source_dir()", 1)[1].split("prepare()", 1)[0]
    assert "omnistore-native" not in release_check
