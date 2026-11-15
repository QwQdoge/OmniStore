pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Controls
import MeoUI 1.0
import OmniStore.Native 1.0 as Store
import Meo.System 1.0

Window {
    id: root
    readonly property MeoWindowMetrics metrics: MeoWindowMetrics { availableWidth: root.width }
    width: 1360
    height: 860
    minimumWidth: 900
    minimumHeight: 620
    visible: true
    title: qsTr("OmniStore")
    color: MeoTheme.surfaceContainerLow

    property string aiMode: "daily"
    property string aiQuery: ""
    property var aiCandidates: []
    property int navigationIndex: 0
    property string pendingSearch: ""
    property var detailFallback: ({})
    readonly property bool dynamicColorReady:
        MeoTheme.colorSchemeMode === "dynamic"
        && MeoTheme.hasActiveDynamicColorScheme
    readonly property bool overlaySheetOpen:
        detailSheet.isOpen || searchSheet.isOpen || tasksSheet.isOpen || aiSheet.isOpen

    SystemPalette { id: desktopPalette }

    // App-local appearance override. "system" follows the desktop and is the
    // default; the system-wide theme itself is owned by Meo Settings.
    Settings {
        id: appearancePreferences
        category: "appearance"
        property string theme: "system" // system | light | dark
        onThemeChanged: root.applyThemePreference()
    }

    function applyThemePreference() {
        const theme = appearancePreferences.theme
        MeoTheme.isDarkMode = theme === "dark"
            || (theme !== "light" && Application.styleHints.colorScheme === Qt.Dark)
    }

    Connections {
        target: Application.styleHints
        function onColorSchemeChanged() { root.applyThemePreference() }
    }
    function syncDynamicColor() {
        const lightScheme = typeof MaterialColors.currentScheme === "function"
            ? MaterialColors.currentScheme(false) : MaterialColors.schemeFor(desktopPalette.highlight, false)
        const darkScheme = typeof MaterialColors.currentScheme === "function"
            ? MaterialColors.currentScheme(true) : MaterialColors.schemeFor(desktopPalette.highlight, true)
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

    function openAi(mode, query, candidates) {
        accountAi.clearPresentation()
        root.aiMode = mode
        root.aiQuery = query
        root.aiCandidates = candidates
        aiSheet.isOpen = true
        accountAi.refreshConnections()
    }

    function openTasks() {
        tasksSheet.isOpen = true
    }

    // App Shell routes after the primary navigation (MeoUI APP_SHELL.md):
    // reached from the sidebar footer, the overflow menu and Ctrl+,.
    readonly property int settingsIndex: 4
    readonly property int aboutIndex: 5

    function closeSheets() {
        detailSheet.isOpen = false
        searchSheet.isOpen = false
        tasksSheet.isOpen = false
        aiSheet.isOpen = false
    }

    function openSettings() {
        root.closeSheets()
        root.navigationIndex = root.settingsIndex
    }

    function openAbout() {
        root.closeSheets()
        root.navigationIndex = root.aboutIndex
    }

    function openHelp() {
        Qt.openUrlExternally("https://meoarch.org/docs/guide/omnistore.html")
    }

    Shortcut { sequence: "Ctrl+,"; onActivated: root.openSettings() }
    Shortcut { sequences: ["Ctrl+?", "Ctrl+Shift+/"]; onActivated: shortcutsDialog.open() }
    Shortcut { sequences: [StandardKey.HelpContents]; onActivated: root.openHelp() }
    Shortcut { sequences: [StandardKey.Find]; onActivated: root.openSearch("") }
    Shortcut { sequences: [StandardKey.Quit]; onActivated: Qt.quit() }
    Shortcut {
        sequence: "Esc"
        enabled: root.overlaySheetOpen
        onActivated: root.closeSheets()
    }

    function refreshPackageState() {
        backend.loadInstalled(true)
        backend.loadUpdates()
    }

    Component.onCompleted: {
        applyThemePreference()
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
        ignoreUnknownSignals: true
        function onSchemeChanged() {
            root.syncDynamicColor()
        }
    }

    Connections {
        target: transactions
        function onOperationFinished(action, success) {
            if (success)
                root.refreshPackageState()
            // One message per outcome (STORE_FEEDBACK.md section 4): success is a
            // short notice; a failure names what failed and offers the log.
            outcomeSnackbar.failed = !success
            outcomeSnackbar.message = success
                ? qsTr("%1 finished.").arg(action)
                : (transactions.errorMessage.length > 0 ? transactions.errorMessage
                                                         : qsTr("%1 didn't finish.").arg(action))
            outcomeSnackbar.openStorage = !success && transactions.errorCategory === "space"
            outcomeSnackbar.actionText = success ? ""
                : (outcomeSnackbar.openStorage ? qsTr("Open storage") : qsTr("View log"))
            outcomeSnackbar.open()
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
            toolTipText: qsTr("Search packages")
            onClicked: root.openSearch("")
        }
    }

    Component {
        id: tasksAction
        MeoIconButton {
            icon.name: transactions.busy ? "sync" : "download"
            type: transactions.busy ? "filled" : "tonal"
            visible: !root.overlaySheetOpen
            toolTipText: transactions.busy ? qsTr("Active package task") : qsTr("Tasks")
            onClicked: root.openTasks()
        }
    }

    Component {
        id: overflowAction
        MeoIconButton {
            id: overflowButton
            icon.name: "more_vert"
            visible: !root.overlaySheetOpen
            toolTipText: qsTr("More options")
            onClicked: overflowMenu.openFrom(overflowButton)

            // Anchor to the button, but clamp inside the whole window.
            MeoMenu {
                id: overflowMenu
                parent: root.contentItem
                placement: "auto"      // the default "manual" ignores openFrom()'s anchor
                model: [
                    { "label": qsTr("Refresh"), "icon": "refresh", "action": function() { root.refreshPackageState() } },
                    { "type": "separator" },
                    { "label": qsTr("Settings"), "icon": "settings", "shortcut": "Ctrl+,", "action": function() { root.openSettings() } },
                    { "label": qsTr("Keyboard shortcuts"), "icon": "keyboard", "shortcut": "Ctrl+?", "action": function() { shortcutsDialog.open() } },
                    { "label": qsTr("Help"), "icon": "help", "shortcut": "F1", "action": function() { root.openHelp() } },
                    { "label": qsTr("About OmniStore"), "icon": "info", "action": function() { root.openAbout() } }
                ]
            }
        }
    }

    Component {
        id: sidebarSettings
        MeoSettingsRow {
            width: parent ? parent.width : implicitWidth
            title: qsTr("Settings")
            leadingIcon: "settings"
            selected: root.navigationIndex === root.settingsIndex || root.navigationIndex === root.aboutIndex
            onActivated: root.openSettings()
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
            { "id": "updates", "label": qsTr("Updates"), "icon": "system_update" }
        ]
        pages: [homePage, explorePage, installedPage, updatesPage, settingsPage, aboutPage]
        pageTitle: root.navigationIndex === root.settingsIndex ? qsTr("Settings")
                   : (root.navigationIndex === root.aboutIndex ? qsTr("About OmniStore") : "")
        compactNavigationLimit: 4
        sidebarTitle: qsTr("OmniStore")
        sidebarFooter: sidebarSettings
        showSearch: false
        showTopAppBarOnExpanded: true
        topAppBarActions: [searchAction, tasksAction, overflowAction]
        onCurrentIndexChanged: root.navigationIndex = currentIndex
    }

    Component {
        id: homePage
        Store.HomePage {
            onAiRequested: function(mode, query, candidates) { root.openAi(mode, query, candidates) }
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
    Component {
        id: settingsPage
        Store.SettingsPage {
            themePreference: appearancePreferences.theme
            onThemePreferenceSelected: function(value) { appearancePreferences.theme = value }
            onAboutRequested: root.openAbout()
        }
    }
    Component {
        id: aboutPage
        MeoAboutPage {
            popupParent: root.contentItem
            appName: qsTr("OmniStore")
            appIcon: "storefront"
            version: Qt.application.version
            description: qsTr("Find software from every source on your system and keep it up to date.")
            links: [
                { "title": qsTr("Website"), "url": "https://meoarch.org/omnistore/", "icon": "language" },
                { "title": qsTr("Source code"), "url": "https://github.com/QwQdoge/OmniStore", "icon": "code" },
                { "title": qsTr("Report a problem"), "url": "https://github.com/QwQdoge/OmniStore/issues", "icon": "bug_report" }
            ]
            licenseName: "GPL-3.0-only"
            licenseText: appLicenseText
            noticesText: appNoticesText
            sourceUrl: "https://github.com/QwQdoge/OmniStore/blob/main/THIRD_PARTY_NOTICES.md"
            copyright: qsTr("© MeoArch contributors")
        }
    }

    MeoDialog {
        id: shortcutsDialog
        parent: Overlay.overlay
        title: qsTr("Keyboard shortcuts")
        message: qsTr("Ctrl+F  Search\nCtrl+,  Settings\nCtrl+?  Keyboard shortcuts\nF1  Help\nEsc  Close the open panel\nCtrl+Q  Quit")
        icon: "keyboard"
        confirmText: qsTr("Close")
        cancelText: ""
    }

    MeoSnackbar {
        id: outcomeSnackbar
        property bool failed: false
        property bool openStorage: false
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: parent.height - height - edgeMargin
        icon: failed ? "error" : "check_circle"
        dismissible: failed
        duration: failed ? 8000 : 4000
        onActionClicked: {
            outcomeSnackbar.close()
            if (outcomeSnackbar.openStorage)
                root.openSettings()   // Storage lives under Advanced
            else
                root.openTasks()
        }
    }

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
                onAiRequested: function(mode, query, candidates) { root.openAi(mode, query, candidates) }
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
            Store.AppDetailsPane {
                fallbackApp: root.detailFallback
                onAiRequested: function(mode, query, candidates) { root.openAi(mode, query, candidates) }
                onSearchRequested: function(query) {
                    detailSheet.isOpen = false
                    root.openSearch(query)
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        z: 90
        visible: root.overlaySheetOpen && !root.metrics.isLargeWidth && !root.metrics.isExtraLargeWidth
        color: Qt.alpha(MeoTheme.scrim, 0.30)
        TapHandler {
            onTapped: {
                detailSheet.isOpen = false
                searchSheet.isOpen = false
                tasksSheet.isOpen = false
            }
        }
    }
    Connections {
        target: accountAi
        function onSearchSuggested(query) {
            aiSheet.isOpen = false
            root.openSearch(query)
            backend.search(query)
        }
    }
    MeoSideSheet {
        id: aiSheet
        z: 110
        height: root.height
        width: Math.min(760 * MeoTheme.globalScale, root.width * 0.78)
        isOpen: false
        title: qsTr("OmniStore AI · Meo Account")
        content: Component {
            Store.AccountAiPanel {
                requestMode: root.aiMode
                query: root.aiQuery
                candidates: root.aiCandidates
                onDetailsRequested: function(app) { aiSheet.isOpen = false; root.showDetails(app) }
            }
        }
    }

}
