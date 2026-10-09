from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
NATIVE = ROOT / "src" / "native-ui"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_primary_navigation_matches_meoui_product_contract():
    main = read(NATIVE / "qml" / "Main.qml")
    navigation = main.split("navigationModel: [", 1)[1].split("]\n        pages:", 1)[0]

    for route in ("home", "explore", "installed", "updates", "settings"):
        assert f'"id": "{route}"' in navigation

    assert '"label": qsTr("Search")' not in navigation
    assert '"label": qsTr("Tasks")' not in navigation
    assert "pages: [homePage, explorePage, installedPage, updatesPage, settingsPage]" in main


def test_search_and_tasks_are_store_level_utility_sheets():
    main = read(NATIVE / "qml" / "Main.qml")

    assert "id: searchSheet" in main
    assert "SearchPage {" in main
    assert "id: tasksSheet" in main
    assert "TasksPage {}" in main
    assert 'Accessible.name: qsTr("Search packages")' in main
    assert 'qsTr("Active package task") : qsTr("Tasks")' in main
    assert "topAppBarActions: [searchAction, tasksAction]" in main


def test_explore_page_is_built_and_uses_runtime_backend_data():
    cmake = read(NATIVE / "CMakeLists.txt")
    explore = read(NATIVE / "qml" / "pages" / "ExplorePage.qml")

    assert "qml/pages/ExplorePage.qml" in cmake
    assert 'title: qsTr("Explore")' in explore
    assert "backend.browseCategory(category)" in explore
    assert "backend.loadRecommendations()" in explore
    assert "backend.categoryResults" in explore
