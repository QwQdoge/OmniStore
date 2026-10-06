pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import MeoUI 1.0
import Meo.System 1.0

Window {
    id: root
    width: 1360
    height: 860
    minimumWidth: 900
    minimumHeight: 620
    visible: true
    title: qsTr("OmniStore")
    color: MeoTheme.surfaceContainerLow

    property int navigationIndex: 0
    property string pendingSearch: ""
    property var detailFallback: ({})
    readonly property bool dynamicColorReady:
        MeoTheme.colorSchemeMode === "dynamic"
        && MeoTheme.hasActiveDynamicColorScheme
    readonly property bool overlaySheetOpen:
        detailSheet.isOpen || searchSheet.isOpen || tasksSheet.isOpen

    function syncDynamicColor() {
        const lightScheme = MaterialColors.currentScheme(false)
        const darkScheme = MaterialColors.currentScheme(true)
        MeoTheme.applyDynamicColorSchemes(
            lightScheme,
            darkScheme,
            "kde-" + MaterialColors.sourceId()
        )
    }

    function openSearch(query) {
        root.pendingSearch = String(query || "")
        searchSheet.isOpen = true
    }

    function openTasks() {
        tasksSheet.isOpen = true
    }

    Component.onCompleted: syncDynamicColor()

    // Temporary release fail-safe until mutating work is owned by the
    // persistent OmniStore transaction service. BackendBridge currently owns
    // its child process, so allowing the window to close while it is busy can
    // terminate an install/update in its destructor.
    onClosing: function(close) {
        if (!backend.busy)
            return
        close.accepted = false
        closeBlockedDialog.open()
    }

    Connections {
        target: MaterialColors
        function onSchemeChanged() {
            root.syncDynamicColor()
        }
    }

    function showDetails(app) {
        root.detailFallback = app || ({})
        const id = String(root.detailFallback.id || root.detailFallback.name || "")
        const source = String(root.detailFallback.primary_source || root.detailFallback.source || "")
        detailSheet.title = String(root.detailFallback.name || root.detailFallback.id || qsTr("App details"))
        detailSheet.isOpen = true
        if (id.length > 0)
            backend.loadDetails(id, source)
    }

    MeoAppLayout {
        id: appLayout
        anchors.fill: parent
        currentIndex: root.navigationIndex
        navigationModel: [
            { "id": "home", "label": qsTr("Home"), "icon": "home" },
            { "id": "explore", "label": qsTr("Explore"), "icon": "explore" },
            { "id": "installed", "label": qsTr("Installed"), "icon": "apps" },
            { "id": "updates", "label": qsTr("Updates"), "icon": "system_update" },
            { "id": "settings", "label": qsTr("Settings"), "icon": "settings" }
        ]
        pages: [homePage, explorePage, installedPage, updatesPage, settingsPage]
        compactNavigationLimit: 5
        sidebarTitle: qsTr("OmniStore")
        onCurrentIndexChanged: root.navigationIndex = currentIndex
    }

    Component {
        id: homePage
        HomePage {
            onSearchRequested: function(query) { root.openSearch(query) }
            onDetailsRequested: function(app) { root.showDetails(app) }
        }
    }

    Component {
        id: explorePage
        ExplorePage {
            onDetailsRequested: function(app) { root.showDetails(app) }
        }
    }

    Component {
        id: installedPage
        InstalledPage { onDetailsRequested: function(app) { root.showDetails(app) } }
    }
    Component { id: updatesPage; UpdatesPage {} }
    Component { id: settingsPage; SettingsPage {} }

    // Store-level utilities are intentionally not primary navigation items.
    // These controls act as the current app-bar actions while MeoAppLayout's
    // shared top-bar action slot is being generalized.
    Row {
        id: globalActions
        z: 80
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 8 * MeoTheme.globalScale
        anchors.rightMargin: 10 * MeoTheme.globalScale
        spacing: 4 * MeoTheme.globalScale
        visible: !root.overlaySheetOpen

        MeoIconButton {
            icon.name: "search"
            type: "tonal"
            Accessible.name: qsTr("Search")
            onClicked: root.openSearch("")
        }

        MeoIconButton {
            icon.name: backend.busy ? "sync" : "download"
            type: backend.busy ? "filled" : "tonal"
            Accessible.name: qsTr("Tasks")
            onClicked: root.openTasks()
        }
    }

    MeoBanner {
        id: dynamicColorWarning
        z: 120
        visible: !root.dynamicColorReady
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16 * MeoTheme.globalScale
        title: qsTr("Dynamic color unavailable")
        text: qsTr("OmniStore could not load the current Meo desktop color scheme. The interface is using the safe preview palette.")
        icon: "palette"
        tone: "warning"
    }

    MeoSideSheet {
        id: searchSheet
        z: 100
        height: root.height
        width: Math.min(720 * MeoTheme.globalScale, root.width * 0.72)
        isOpen: false
        title: qsTr("Search")
        content: Component {
            SearchPage {
                initialQuery: root.pendingSearch
                onDetailsRequested: function(app) {
                    searchSheet.isOpen = false
                    root.showDetails(app)
                }
            }
        }
    }

    MeoSideSheet {
        id: tasksSheet
        z: 100
        height: root.height
        width: Math.min(620 * MeoTheme.globalScale, root.width * 0.68)
        isOpen: false
        title: qsTr("Tasks")
        content: Component { TasksPage {} }
    }

    MeoSideSheet {
        id: detailSheet
        z: 100
        height: root.height
        width: Math.min(520 * MeoTheme.globalScale, root.width * 0.50)
        isOpen: false
        title: qsTr("App details")
        content: Component {
            AppDetailsPane { fallbackApp: root.detailFallback }
        }
    }

    Rectangle {
        anchors.fill: parent
        z: 90
        visible: root.overlaySheetOpen && root.width < 1180 * MeoTheme.globalScale
        color: Qt.rgba(0, 0, 0, 0.30)
        TapHandler {
            onTapped: {
                detailSheet.isOpen = false
                searchSheet.isOpen = false
                tasksSheet.isOpen = false
            }
        }
    }

    MeoDialog {
        id: closeBlockedDialog
        parent: Overlay.overlay
        title: qsTr("OmniStore is still working")
        message: qsTr("Keep OmniStore open until the current operation finishes. Closing it now could interrupt the package backend.")
        icon: "hourglass_top"
        confirmText: qsTr("Keep open")
        showRejectButton: false
    }
}
