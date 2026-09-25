from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
NATIVE = ROOT / "NativeUI"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_repository_bridge_reuses_existing_cli_contract_without_shell():
    bridge = read(NATIVE / "app" / "repositorybridge.cpp")
    assert "--list-custom-repos" in bridge
    assert "--add-custom-repo" in bridge
    assert "--remove-custom-repo" in bridge
    assert "process->start(m_backendProgram, finalArguments)" in bridge
    for forbidden in ("/bin/sh", "/bin/bash", "system(", "popen("):
        assert forbidden not in bridge


def test_repository_bridge_preserves_backend_security_boundaries():
    bridge = read(NATIVE / "app" / "repositorybridge.cpp")
    assert 'normalizedType == QStringLiteral("pacman")' in bridge
    assert 'normalizedUrl.startsWith(QStringLiteral("https://"))' in bridge
    assert "basicNameValid" in bridge
    assert "basicUrlValid" in bridge
    # AppImage removal uses the feed URL, matching CustomRepoManager.
    manager = read(NATIVE / "qml" / "components" / "RepositoryManager.qml")
    assert 'item.type === "appimage" ? item.url : item.name' in manager


def test_unmanaged_pacman_repositories_are_read_only_in_native_ui():
    manager = read(NATIVE / "qml" / "components" / "RepositoryManager.qml")
    assert '"managed": type !== "pacman" || !!item.managed' in manager
    assert "visible: repositoryCard.modelData.managed" in manager
    assert "not owned by OmniStore, so removal is disabled" in manager


def test_repository_mutations_require_confirmation():
    manager = read(NATIVE / "qml" / "components" / "RepositoryManager.qml")
    assert manager.count("MeoDialog") >= 2
    assert "onConfirmed: {\n            repoBridge.addRepository" in manager
    assert "onConfirmed: repoBridge.removeRepository" in manager


def test_settings_refreshes_plugin_and_custom_repository_state():
    settings = read(NATIVE / "qml" / "pages" / "SettingsPage.qml")
    assert "backend.loadPlugins()" in settings
    assert "repoBridge.refresh()" in settings
    assert "RepositoryManager" in settings


def test_native_build_registers_repository_bridge_and_component():
    cmake = read(NATIVE / "CMakeLists.txt")
    main = read(NATIVE / "app" / "main.cpp")
    for path in (
        "app/repositorybridge.cpp",
        "app/repositorybridge.h",
        "qml/components/RepositoryManager.qml",
    ):
        assert path in cmake
    assert 'setContextProperty(QStringLiteral("repoBridge"), &repositoryBridge)' in main
