pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import MeoUI 1.0
import OmniStore.Native 1.0 as Store
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

    function refreshPackageState() {
        backend.loadInstalled(true)
        backend.loadUpdates()
    }

    Component.onCompleted: {
        syncDynamicColor()
        transactions.reconnect()
        // An external request only opens the current details/review flow.
        // Planning and applying still require separate user actions.
        if (pendingInstallRequest.id)
            Qt.callLater(function() { root.showDetails(pendingInstallRequest) })
    }

    // Package mutations are owned by omnistore-task.service rather than this
    // Window. Closing the UI must therefore never cancel an install, remove or
    // update operation; reopening OmniStore reconnects through task.list.

    Connections {
        target: MaterialColors
        function onSchemeChanged() {
            root.syncDynamicColor()
        }
    }

    Connections {
        target: transactions
        function onOperationFinished(action, success) {
            if (success)
                root.refreshPackageState()
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

    Component {
        id: searchAction
        MeoIconButton {
            icon.name: "search"
            type: "tonal"
            visible: !root.overlaySheetOpen
            Accessible.name: qsTr("Search packages")
            onClicked: root.openSearch("")
        }
    }

    Component {
        id: tasksAction
        MeoIconButton {
            icon.name: transactions.busy ? "sync" : "download"
            type: transactions.busy ? "filled" : "tonal"
            visible: !root.overlaySheetOpen
            Accessible.name: transactions.busy ? qsTr("Active package task") : qsTr("Tasks")
            onClicked: root.openTasks()
        }
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
        showSearch: false
        showTopAppBarOnExpanded: true
        topAppBarActions: [searchAction, tasksAction]
        onCurrentIndexChanged: root.navigationIndex = currentIndex
    }

    Component {
        id: homePage
        Store.HomePage {
            onSearchRequested: function(query) { root.openSearch(query) }
            onExploreRequested: root.navigationIndex = 1
            onDetailsRequested: function(app) { root.showDetails(app) }
        }
    }

    Component {
        id: explorePage
        Store.ExplorePage {
            onDetailsRequested: function(app) { root.showDetails(app) }
        }
    }

    Component {
        id: installedPage
        Store.InstalledPage { onDetailsRequested: function(app) { root.showDetails(app) } }
    }
    Component { id: updatesPage; Store.UpdatesPage { onTasksRequested: root.openTasks() } }
    Component { id: settingsPage; Store.SettingsPage {} }

    MeoBanner {
        z: 130
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16 * MeoTheme.globalScale
        visible: transactions.busy && transactions.authenticationPrompt.length > 0
        title: qsTr("Scan your fingerprint")
        text: transactions.authenticationPrompt
        icon: "fingerprint"
        tone: "info"
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
        width: Math.min(760 * MeoTheme.globalScale, root.width * 0.72)
        isOpen: false
        title: qsTr("Search")
        content: Component {
            Store.SearchPage {
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
        content: Component { Store.TasksPage {} }
    }

    MeoSideSheet {
        id: detailSheet
        z: 100
        height: root.height
        width: Math.min(640 * MeoTheme.globalScale, root.width * 0.58)
        isOpen: false
        title: qsTr("App details")
        content: Component {
            Store.AppDetailsPane { fallbackApp: root.detailFallback }
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
}
