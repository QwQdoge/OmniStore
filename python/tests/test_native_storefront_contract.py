from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
NATIVE = ROOT / "src" / "native-ui"
QML = NATIVE / "qml"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_home_uses_store_cards_instead_of_only_package_rows():
    home = read(QML / "pages" / "HomePage.qml")
    card = read(QML / "components" / "StoreAppCard.qml")
    cmake = read(NATIVE / "CMakeLists.txt")

    assert "StoreAppCard" in home
    assert 'qsTr("Featured")' in home
    assert 'qsTr("Popular")' in home
    assert "screenshots" in card
    assert "app.icon" in card
    assert "qml/components/StoreAppCard.qml" in cmake


def test_details_consumes_real_metadata_and_hides_optional_sections():
    details = read(QML / "components" / "AppDetailsPane.qml")

    for field in (
        "app.screenshots",
        "app.icon",
        "app.developer",
        "app.license",
        "app.installed_size",
        "app.disk_size",
        "app.variants",
    ):
        assert field in details

    assert 'visible: root.screenshots.length > 0' in details
    assert 'visible: String(root.app.license || "").length > 0' in details
    assert "No description is available for this package." in details


def test_store_utilities_use_shared_meoui_top_app_bar():
    main = read(QML / "Main.qml")

    assert "topAppBarActions: [searchAction, tasksAction]" in main
    assert "showTopAppBarOnExpanded: true" in main
    assert "id: globalActions" not in main
    assert 'id: searchSheet' in main
    assert 'id: tasksSheet' in main
