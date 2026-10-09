from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
NATIVE = ROOT / "src" / "native-ui"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_native_window_does_not_own_package_transaction_lifetime():
    main = read(NATIVE / "qml" / "Main.qml")
    transaction_client = read(NATIVE / "app" / "transactionclient.cpp")

    assert "omnistore-task.service" in transaction_client
    assert 'QStringLiteral("task.list")' in transaction_client
    assert 'QStringLiteral("task.submit")' in transaction_client
    assert "onClosing: function(close)" not in main
    assert "close.accepted = false" not in main
    assert "transactions.reconnect()" in main


def test_native_version_is_build_injected_not_stale_literal():
    cmake = read(NATIVE / "CMakeLists.txt")
    main = read(NATIVE / "app" / "main.cpp")
    release_builder = read(NATIVE / "build_linux_release.py")

    assert 'set(OMNISTORE_RELEASE_VERSION "development" CACHE STRING' in cmake
    assert 'OMNISTORE_RELEASE_VERSION="${OMNISTORE_RELEASE_VERSION}"' in cmake
    assert "QString::fromUtf8(OMNISTORE_RELEASE_VERSION)" in main
    assert "0.1.0-native" not in main
    assert "-DOMNISTORE_RELEASE_VERSION=" in release_builder
    assert 'os.environ.get("OMNISTORE_VERSION", "development")' in release_builder


def test_linux_package_exposes_stable_native_launcher():
    pkgbuild = read(ROOT / "PKGBUILD")

    assert '${pkgdir}/usr/bin/omnistore-native' in pkgbuild
    assert 'exec /opt/omnistore/omnistore-native "$@"' in pkgbuild
    assert 'exec /usr/bin/omnistore-native "$@"' in pkgbuild


def test_source_settings_use_runtime_availability_and_trust_metadata():
    settings = read(NATIVE / "qml" / "pages" / "SettingsPage.qml")
    for token in (
        "plugin.available",
        "plugin.trusted",
        "plugin.requires_review",
        "plugin.capabilities",
        "plugin.error",
    ):
        assert token in settings
    assert 'qsTr("Unavailable on this system")' in settings
    for section in ("System source", "App sources", "Community sources", "Advanced sources"):
        assert f'title: qsTr("{section}")' in settings
