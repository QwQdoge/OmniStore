pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import MeoUI 1.0
import Meo.System 1.0
import "components"
import "pages"

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

    function syncDynamicColor() {
        const lightScheme = MaterialColors.currentScheme(false)
        const darkScheme = MaterialColors.currentScheme(true)
        MeoTheme.applyDynamicColorSchemes(
            lightScheme,
            darkScheme,
            "kde-" + MaterialColors.sourceId()
        )
    }

    Component.onCompleted: syncDynamicColor()

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
            { "id": "search", "label": qsTr("Search"), "icon": "search" },
            { "id": "updates", "label": qsTr("Updates"), "icon": "system_update" },
            { "id": "installed", "label": qsTr("Installed"), "icon": "apps" },
            { "id": "tasks", "label": qsTr("Tasks"), "icon": "download" },
            { "id": "settings", "label": qsTr("Settings"), "icon": "settings" }
        ]
        pages: [homePage, searchPage, updatesPage, installedPage, tasksPage, settingsPage]
        sidebarTitle: qsTr("OmniStore")
        onCurrentIndexChanged: root.navigationIndex = currentIndex
    }

    Component {
        id: homePage
        HomePage {
            onSearchRequested: function(query) {
                root.pendingSearch = query
                root.navigationIndex = 1
            }
            onDetailsRequested: function(app) { root.showDetails(app) }
        }
    }

    Component {
        id: searchPage
        SearchPage {
            initialQuery: root.pendingSearch
            onDetailsRequested: function(app) { root.showDetails(app) }
        }
    }

    Component { id: updatesPage; UpdatesPage {} }
    Component {
        id: installedPage
        InstalledPage { onDetailsRequested: function(app) { root.showDetails(app) } }
    }
    Component { id: tasksPage; TasksPage {} }
    Component { id: settingsPage; SettingsPage {} }

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
        id: detailSheet
        z: 100
        height: root.height
        width: Math.min(440 * MeoTheme.globalScale, root.width * 0.46)
        isOpen: false
        title: qsTr("App details")
        content: Component {
            AppDetailsPane { fallbackApp: root.detailFallback }
        }
    }

    Rectangle {
        anchors.fill: parent
        z: 90
        visible: detailSheet.isOpen && root.width < 1050 * MeoTheme.globalScale
        color: Qt.rgba(0, 0, 0, 0.30)
        TapHandler { onTapped: detailSheet.isOpen = false }
    }
}
