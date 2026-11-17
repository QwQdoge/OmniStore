pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeoUI 1.0
import OmniStore.Native 1.0 as Store

Item {
    id: root

    property string pendingPluginId: ""
    property string pendingPluginName: ""
    property bool pendingNeedsSetup: false
    property bool pendingNeedsReview: true
    // Stable stored values; the labels below are presentation only.
    readonly property var themeValues: ["system", "light", "dark"]
    property string themePreference: "system"

    signal themePreferenceSelected(string value)
    signal aboutRequested()

    function appearanceRows() {
        return [{
            "objectName": "omnistoreThemeRow",
            "title": qsTr("Theme"),
            "subtitle": qsTr("Follow the system appearance, or override it for OmniStore only."),
            "leadingIcon": "dark_mode",
            "trailingKind": "segmented",
            "segmentedModel": [qsTr("System"), qsTr("Light"), qsTr("Dark")],
            "currentIndex": Math.max(0, root.themeValues.indexOf(root.themePreference)),
            "onOptionSelected": function(optionIndex) {
                root.themePreferenceSelected(root.themeValues[optionIndex])
            }
        }]
    }

    function aiRows() {
        const f = accountAi.features
        const master = !!f.enabled
        const row = (key, icon, title, subtitle) => ({
            "title": title,
            "subtitle": subtitle,
            "leadingIcon": icon,
            "trailingKind": "switch",
            "checked": key === "enabled" ? master : !!accountAi.rawFeature(key),
            "enabled": key === "enabled" || master,
            "interactive": key === "enabled" || master,
            "onToggled": function(value) { accountAi.setFeature(key, value) }
        })
        return [
            row("enabled", "auto_awesome", qsTr("Use AI assistance"),
                qsTr("Off by default. Uses the AI connection saved in Meo Settings; every request is shown to you before it is sent.")),
            row("search", "search", qsTr("AI search"), qsTr("Find software from a description of what you need.")),
            row("recommend", "recommend", qsTr("AI recommendations"), qsTr("Suggest apps on Home and rank search results.")),
            row("summary", "summarize", qsTr("AI summaries"), qsTr("Explain what a package is and does.")),
            row("safety", "shield", qsTr("AI safety check"), qsTr("Advisory risk assessment of a package. It is not a security guarantee."))
        ]
    }

    function privacyRows() {
        return [{
            "title": qsTr("Saved AI permission"),
            "subtitle": accountAi.rememberedConsent
                ? qsTr("OmniStore may send catalog advice requests to your selected AI connection without asking each time. Select to revoke.")
                : qsTr("No saved permission. OmniStore asks before every AI request."),
            "leadingIcon": "verified_user",
            "trailingKind": accountAi.rememberedConsent ? "navigation" : "none",
            "interactive": accountAi.rememberedConsent && !accountAi.busy,
            "action": function() { accountAi.revokeRememberedConsent() }
        }, {
            "title": qsTr("Telemetry"),
            "subtitle": qsTr("OmniStore does not send usage telemetry."),
            "leadingIcon": "visibility_off",
            "trailingKind": "none"
        }]
    }

    function resetRows() {
        return [{
            "title": qsTr("Reset to defaults"),
            "subtitle": qsTr("Turns AI assistance off and clears OmniStore preferences. Installed software is not changed."),
            "leadingIcon": "restart_alt",
            "trailingKind": "navigation",
            "action": function() { resetDialog.open() }
        }]
    }

    function aboutRows() {
        return [{
            "objectName": "omnistoreAboutRow",
            "title": qsTr("About OmniStore"),
            "subtitle": qsTr("Version %1, licenses and links").arg(Qt.application.version),
            "leadingIcon": "info",
            "trailingKind": "navigation",
            "action": function() { root.aboutRequested() }
        }]
    }

    readonly property var cacheChoicesMb: [0, 1024, 2048, 5120]
    property bool meoSettingsMissing: false

    function preference(key, fallback) {
        const prefs = backend.appPreferences || ({})
        return prefs[key] === undefined ? fallback : prefs[key]
    }

    function updatePreferenceRows() {
        const limit = Number(root.preference("cacheLimitMb", 0))
        const index = root.cacheChoicesMb.indexOf(limit)
        return [{
            "title": qsTr("Update Flatpak apps automatically"),
            "subtitle": qsTr("Installs updates for apps you installed for your own account in the background. System packages always need your authorization."),
            "leadingIcon": "update",
            "trailingKind": "switch",
            "checked": !!root.preference("autoUpdate", false),
            "enabled": !backend.busy,
            "interactive": true,
            "onToggled": function(value) { backend.setAppPreference("autoUpdate", value) }
        }, {
            "title": qsTr("Limit app caches"),
            "subtitle": index >= 0
                ? qsTr("When app caches together grow past the limit, the largest are cleared. Settings and data are never removed.")
                : qsTr("Custom limit: %1 MB. Choose a value to replace it.").arg(limit),
            "leadingIcon": "cleaning_services",
            "trailingKind": "segmented",
            "segmentedModel": [qsTr("Off"), qsTr("1 GB"), qsTr("2 GB"), qsTr("5 GB")],
            "currentIndex": Math.max(0, index),
            "enabled": !backend.busy,
            "onOptionSelected": function(optionIndex) {
                backend.setAppPreference("cacheLimitMb", root.cacheChoicesMb[optionIndex])
            }
        }]
    }

    function notificationRows() {
        const rows = root.linuxDesktop ? [{
            "title": qsTr("Notify when updates are available"),
            "subtitle": qsTr("Sent by the background update check. Delivery follows your desktop's notification rules."),
            "leadingIcon": "notifications_active",
            "trailingKind": "switch",
            "checked": !!root.preference("notifyUpdates", true),
            "enabled": !backend.busy,
            "interactive": true,
            "onToggled": function(value) { backend.setAppPreference("notifyUpdates", value) }
        }] : []
        rows.push({
            "title": qsTr("Notify when a task finishes in the background"),
            "subtitle": qsTr("Only when the OmniStore window is not in front. An install or update keeps running either way."),
            "leadingIcon": "task_alt",
            "trailingKind": "switch",
            "checked": systemBridge.taskNotifications,
            "interactive": true,
            "onToggled": function(value) { systemBridge.taskNotifications = value }
        })
        if (systemBridge.canOpenMeoSettings) rows.push({
            "title": qsTr("Open notification settings in Meo Settings"),
            "subtitle": root.meoSettingsMissing
                ? qsTr("Meo Settings isn't installed on this computer.")
                : qsTr("Do Not Disturb, popups and history for OmniStore are managed there."),
            "leadingIcon": "settings_applications",
            "trailingKind": "navigation",
            "interactive": true,
            "action": function() { root.meoSettingsMissing = !systemBridge.openMeoSettings("notifications") }
        })
        return rows
    }

    function capabilityLabel(capability) {
        const key = String(capability || "")
        if (key === "search") return qsTr("Search")
        if (key === "install") return qsTr("Install")
        if (key === "uninstall") return qsTr("Remove")
        if (key === "update") return qsTr("Updates")
        if (key === "details") return qsTr("Details")
        if (key === "list_installed") return qsTr("Installed apps")
        if (key === "size") return qsTr("Size info")
        if (key === "repositories") return qsTr("Repositories")
        if (key === "mirrors") return qsTr("Mirrors")
        return key
    }

    function pluginSubtitle(plugin) {
        const parts = []
        if (!plugin.available)
            parts.push(qsTr("Unavailable on this system"))
        else if (plugin.requires_review)
            parts.push(qsTr("Review required"))
        else if (plugin.trusted)
            parts.push(qsTr("Trusted source"))
        else
            parts.push(qsTr("Not marked trusted"))

        const capabilities = Array.isArray(plugin.capabilities) ? plugin.capabilities : []
        if (capabilities.length > 0) {
            const labels = []
            const limit = Math.min(capabilities.length, 4)
            for (let index = 0; index < limit; ++index)
                labels.push(root.capabilityLabel(capabilities[index]))
            parts.push(labels.join(" · "))
        }
        if (plugin.offered)
            parts.unshift(qsTr("Found on this computer"))
        if (plugin.experimental)
            parts.push(qsTr("Experimental"))
        if (String(plugin.error || "").length > 0)
            parts.push(String(plugin.error))
        return parts.join("  •  ")
    }

    function sourceGroup(plugin) {
        const id = String(plugin.id || "").toLowerCase()
        if (plugin.offered)
            return "offers"
        if (id === "builtin.pacman")
            return "system"
        if (id === "builtin.flatpak")
            return "apps"
        if (id === "builtin.aur")
            return "community"
        return "advanced"
    }

    function requestPluginToggle(plugin, value) {
        const pluginId = String(plugin.id || "")
        if (pluginId.length === 0 || !plugin.available)
            return
        const needsSetup = Array.isArray(plugin.requires) && plugin.requires.length > 0
        if (value && (plugin.requires_review || needsSetup)) {
            root.pendingNeedsSetup = needsSetup
            root.pendingNeedsReview = !!plugin.requires_review
            root.pendingPluginId = pluginId
            root.pendingPluginName = String(plugin.name || plugin.id || qsTr("Source"))
            sourceReviewDialog.open()
            return
        }
        backend.setPluginEnabled(pluginId, value)
    }

    function sourceRow(plugin) {
        const available = !!plugin.available
        const pluginId = String(plugin.id || "")
        let icon = "extension"
        if (!available)
            icon = "block"
        else if (!plugin.enabled)
            icon = "extension_off"
        else if (plugin.requires_review)
            icon = "warning"
        else if (plugin.trusted)
            icon = "verified"

        return {
            "title": String(plugin.name || plugin.id || qsTr("Source")),
            "subtitle": root.pluginSubtitle(plugin),
            "leadingIcon": icon,
            "trailingKind": available ? "switch" : "none",
            "checked": available && !!plugin.enabled,
            "enabled": available && !backend.busy && pluginId.length > 0,
            "interactive": available,
            "onToggled": function(value) { root.requestPluginToggle(plugin, value) }
        }
    }

    function bottleRows() {
        const info = backend.bottles || {}
        const rows = []
        if (!info.enabled)
            return rows
        const bottles = Array.isArray(info.bottles) ? info.bottles : []
        for (let index = 0; index < bottles.length; ++index) {
            const bottle = bottles[index]
            const name = String(bottle.name || "")
            if (name.length === 0)
                continue
            const decided = bottle.listed === true || bottle.listed === false
            rows.push({
                "title": name,
                "subtitle": decided
                    ? (bottle.listed ? qsTr("Programs appear in Installed") : qsTr("Programs are hidden"))
                    : qsTr("Not decided yet. Programs stay hidden until you choose."),
                "leadingIcon": "wine_bar",
                "trailingKind": "switch",
                "checked": bottle.listed === true,
                "enabled": !backend.busy,
                "interactive": true,
                "onToggled": function(value) { backend.setBottleListed(name, value) }
            })
        }
        return rows
    }

    function sourceRows(group) {
        const rows = []
        for (let index = 0; index < backend.plugins.length; ++index) {
            const plugin = backend.plugins[index]
            if (!!plugin.legacy)
                continue
            if (root.sourceGroup(plugin) !== group)
                continue
            // Product-facing core groups explain their state even when the
            // underlying executable is unavailable. Advanced integrations stay
            // out of the normal UI unless they actually work on this machine.
            if (group === "advanced" && !plugin.available)
                continue
            rows.push(root.sourceRow(plugin))
        }
        return rows
    }

    // Kept as a small compatibility helper for tests/tools that inspect the
    // source registry presentation. Product UI uses the grouped functions.
    function pluginRows() {
        return root.sourceRows("system")
            .concat(root.sourceRows("apps"))
            .concat(root.sourceRows("community"))
            .concat(root.sourceRows("advanced"))
    }

    function backendRows() {
        return [
            {
                "title": qsTr("Runtime"),
                "subtitle": backend.backendDescription,
                "leadingIcon": "terminal",
                "trailingKind": "none",
                "interactive": false
            },
            {
                "title": qsTr("Current state"),
                "subtitle": backend.statusMessage,
                "leadingIcon": backend.busy ? "sync" : "check_circle",
                "trailingKind": "none",
                "interactive": false
            }
        ]
    }

    function formatBytes(value) {
        let amount = Number(value)
        if (!Number.isFinite(amount) || amount < 0)
            return qsTr("Unavailable")
        const units = [qsTr("B"), qsTr("KB"), qsTr("MB"), qsTr("GB"), qsTr("TB")]
        let index = 0
        while (amount >= 1024 && index < units.length - 1) {
            amount /= 1024
            ++index
        }
        return (index === 0 ? Math.round(amount) : amount.toFixed(amount >= 10 ? 1 : 2)) + " " + units[index]
    }

    function storageRows() {
        const info = backend.storageInfo || ({})
        return [
            {
                "title": qsTr("Free space"),
                "subtitle": root.formatBytes(info.disk_free),
                "leadingIcon": "hard_drive",
                "trailingKind": "none",
                "interactive": false
            },
            {
                "title": qsTr("Used space"),
                "subtitle": root.formatBytes(info.disk_used),
                "leadingIcon": "storage",
                "trailingKind": "none",
                "interactive": false
            }
        ]
    }

    Component.onCompleted: {
        if (root.twoPane && root.category === "")
            root.category = "appearance"
        backend.loadSettingsSnapshot()
        backend.loadConfig()
        backend.loadStorageInfo()
        repoBridge.refresh()
    }

    // Two-level settings (MeoUI PAGE_TYPES.md): a category list selects a domain,
    // the content area shows that domain. On narrow windows they replace each other.
    readonly property MeoWindowMetrics metrics: MeoWindowMetrics { availableWidth: root.width }
    readonly property bool twoPane: metrics.supportsTwoPane
    property string category: ""
    // Background update checks, Flatpak/pacman repositories and the Meo channel are Linux
    // features; Windows and macOS use their own sources (winget/Scoop/Chocolatey, Homebrew).
    readonly property bool linuxDesktop: String((backend.systemProfile || ({})).platform || "linux") === "linux"
    readonly property var allCategories: [
        { "id": "appearance", "title": qsTr("Appearance"), "icon": "palette" },
        { "id": "sources", "title": qsTr("Sources"), "icon": "extension" },
        { "id": "updates", "title": qsTr("Updates"), "icon": "system_update" },
        { "id": "ai", "title": qsTr("AI assistance"), "icon": "auto_awesome" },
        { "id": "notifications", "title": qsTr("Notifications"), "icon": "notifications" },
        { "id": "privacy", "title": qsTr("Privacy & data"), "icon": "shield" },
        { "id": "advanced", "title": qsTr("Advanced"), "icon": "tune" }
    ]
    readonly property var categories: allCategories.filter(function(c) { return root.linuxDesktop || c.id !== "updates" })
    function categoryTitle(id) {
        for (let i = 0; i < categories.length; ++i)
            if (categories[i].id === id) return categories[i].title
        return qsTr("Settings")
    }
    onTwoPaneChanged: if (twoPane && category === "") category = "appearance"
    function categoryRows() {
        const kind = root.twoPane ? "none" : "navigation"
        const rows = root.categories.map(function(c) {
            return { "id": c.id, "title": c.title, "icon": c.icon, "kind": kind,
                     "interactive": true, "selected": root.twoPane && root.category === c.id }
        })
        rows.push({ "id": "about", "title": qsTr("About OmniStore"), "icon": "info", "kind": kind, "interactive": true })
        return rows
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Category list (level one).
        ScrollView {
            id: indexScroll
            visible: root.twoPane || root.category === ""
            Layout.fillHeight: true
            Layout.fillWidth: !root.twoPane
            Layout.preferredWidth: root.twoPane ? 300 * MeoTheme.globalScale : -1
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: indexScroll.availableWidth - 24 * MeoTheme.globalScale
                x: 12 * MeoTheme.globalScale
                y: 20 * MeoTheme.globalScale
                spacing: 4 * MeoTheme.globalScale

                Store.PageHeading {
                    visible: !root.twoPane
                    Layout.fillWidth: true
                    title: qsTr("Settings")
                    subtitle: qsTr("Manage appearance, software sources and updates.")
                    icon: "settings"
                }
                // One connected group (like the sidebar), not loose bubbles.
                MeoSettingsGroup {
                    Layout.fillWidth: true
                    model: root.categoryRows()
                    onRowActivated: function(index, row) {
                        if (row.id === "about")
                            root.aboutRequested()
                        else
                            root.category = row.id
                    }
                }
            }
        }

        // Selected category (level two).
        ScrollView {
            id: settingsScroll
            visible: root.twoPane || root.category !== ""
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            contentHeight: settingsColumn.implicitHeight + 64 * MeoTheme.globalScale
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                id: settingsColumn
                width: Math.min(settingsScroll.availableWidth - 56 * MeoTheme.globalScale,
                                980 * MeoTheme.globalScale)
                x: (settingsScroll.availableWidth - width) / 2
                y: 28 * MeoTheme.globalScale
                spacing: 18 * MeoTheme.globalScale

                MeoButton {
                    visible: !root.twoPane
                    text: qsTr("All settings")
                    type: "text"
                    icon.name: "arrow_back"
                    onClicked: root.category = ""
                }

                Store.PageHeading {
                    Layout.fillWidth: true
                    title: root.categoryTitle(root.category)
                    subtitle: ""
                    icon: "settings"
                }

                Loader {
                    Layout.fillWidth: true
                    active: root.category === "appearance"
                    visible: active
                    sourceComponent: Component {
                        ColumnLayout {
                            width: parent ? parent.width : 0
                            spacing: 18 * MeoTheme.globalScale

                            MeoSettingsGroup {
                                Layout.fillWidth: true
                                title: qsTr("Appearance")
                                model: root.appearanceRows()
                            }
                        }
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    active: root.category === "sources"
                    visible: active
                    sourceComponent: Component {
                        ColumnLayout {
                            width: parent ? parent.width : 0
                            spacing: 18 * MeoTheme.globalScale

                            MeoSettingsGroup {
                                Layout.fillWidth: true
                                visible: root.sourceRows("offers").length > 0
                                title: qsTr("Available to add")
                                subtitle: qsTr("Found on this computer. Nothing is added until you turn it on.")
                                model: root.sourceRows("offers")
                            }

                            MeoSettingsGroup {
                                Layout.fillWidth: true
                                visible: root.bottleRows().length > 0
                                title: qsTr("Windows app containers")
                                subtitle: qsTr("Choose which Bottles containers show their programs as normal apps.")
                                model: root.bottleRows()
                            }

                            MeoSettingsGroup {
                                Layout.fillWidth: true
                                visible: root.sourceRows("system").length > 0
                                title: qsTr("System source")
                                subtitle: qsTr("Packages integrated with the MeoArch and Arch system package stack.")
                                model: root.sourceRows("system")
                            }

                            MeoSettingsGroup {
                                Layout.fillWidth: true
                                visible: root.sourceRows("apps").length > 0
                                title: qsTr("App sources")
                                subtitle: qsTr("Application-focused sources detected on this system.")
                                model: root.sourceRows("apps")
                            }

                            MeoSettingsGroup {
                                Layout.fillWidth: true
                                visible: root.sourceRows("community").length > 0
                                title: qsTr("Community sources")
                                subtitle: qsTr("Community-maintained software requires explicit review before it is enabled.")
                                model: root.sourceRows("community")
                            }

                            MeoSettingsGroup {
                                Layout.fillWidth: true
                                visible: root.sourceRows("advanced").length > 0
                                title: qsTr("Advanced sources")
                                subtitle: qsTr("Additional integrations appear here only when their runtime backend is available on this system.")
                                model: root.sourceRows("advanced")
                            }

                            MeoCard {
                                Layout.fillWidth: true
                                type: "filled"
                                padding: 18 * MeoTheme.globalScale

                                ColumnLayout {
                                    width: parent.width
                                    spacing: 10 * MeoTheme.globalScale

                                    MeoText {
                                        text: qsTr("Add a third-party source")
                                        typeRole: "title"
                                        typeSize: "small"
                                        emphasized: true
                                        color: MeoTheme.contentOnSurface
                                    }
                                    MeoText {
                                        Layout.fillWidth: true
                                        text: qsTr("A source list is a public file that points to apps your installed sources can install. It runs no code and stays off until you review and turn it on.")
                                        typeRole: "body"
                                        typeSize: "small"
                                        color: MeoTheme.contentOnSurfaceVariant
                                        wrapMode: Text.WordWrap
                                    }
                                    MeoTextField {
                                        id: catalogUrl
                                        Layout.fillWidth: true
                                        label: qsTr("Source list address")
                                        placeholder: "https://example.org/apps/index.json"
                                        leadingIcon: "link"
                                        maxLength: 2048
                                        supportingText: qsTr("Must start with https://")
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Item { Layout.fillWidth: true }
                                        MeoButton {
                                            text: qsTr("Add source list")
                                            type: "filled"
                                            icon.name: "add"
                                            enabled: !backend.busy && catalogUrl.text.trim().indexOf("https://") === 0
                                            onClicked: {
                                                backend.addCatalog(catalogUrl.text.trim())
                                                catalogUrl.text = ""
                                            }
                                        }
                                    }
                                }
                            }

                            Store.RepositoryManager {
                                visible: root.linuxDesktop
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    active: root.category === "updates"
                    visible: active
                    sourceComponent: Component {
                        ColumnLayout {
                            width: parent ? parent.width : 0
                            spacing: 18 * MeoTheme.globalScale

                            Store.SystemStatusPanel {
                                Layout.fillWidth: true
                            }

                MeoSettingsGroup {
                    Layout.fillWidth: true
                    title: qsTr("Background updates")
                    model: root.updatePreferenceRows()
                }
                        }
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    active: root.category === "ai"
                    visible: active
                    sourceComponent: Component {
                        ColumnLayout {
                            width: parent ? parent.width : 0
                            spacing: 18 * MeoTheme.globalScale

                            MeoSettingsGroup {
                                Layout.fillWidth: true
                                model: root.aiRows()
                            }
                        }
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    active: root.category === "notifications"
                    visible: active
                    sourceComponent: Component {
                        ColumnLayout {
                            width: parent ? parent.width : 0
                            spacing: 18 * MeoTheme.globalScale

                MeoSettingsGroup {
                    Layout.fillWidth: true
                    model: root.notificationRows()
                }
                        }
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    active: root.category === "privacy"
                    visible: active
                    sourceComponent: Component {
                        ColumnLayout {
                            width: parent ? parent.width : 0
                            spacing: 18 * MeoTheme.globalScale

                            MeoSettingsGroup {
                                Layout.fillWidth: true
                                model: root.privacyRows()
                            }
                        }
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    active: root.category === "advanced"
                    visible: active
                    sourceComponent: Component {
                        ColumnLayout {
                            width: parent ? parent.width : 0
                            spacing: 18 * MeoTheme.globalScale

                            MeoSettingsGroup {
                                Layout.fillWidth: true
                                title: qsTr("Storage")
                                subtitle: qsTr("Values are read from the current system at runtime.")
                                model: root.storageRows()
                            }

                            MeoSettingsGroup {
                                Layout.fillWidth: true
                                title: qsTr("Backend")
                                subtitle: qsTr("Runtime status for OmniStore's existing package authority.")
                                model: root.backendRows()
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.fillWidth: true }
                                MeoButton {
                                    text: qsTr("Refresh settings")
                                    type: "tonal"
                                    icon.name: "refresh"
                                    enabled: !backend.busy && !repoBridge.busy
                                    onClicked: {
                                        backend.loadPlugins()
                                        backend.loadConfig()
                                        backend.loadStorageInfo()
                                        repoBridge.refresh()
                                    }
                                }
                            }

                            MeoSettingsGroup {
                                Layout.fillWidth: true
                                model: root.resetRows()
                            }
                        }
                    }
                }
            }
        }
    }

    MeoDialog {
        id: resetDialog
        parent: Overlay.overlay
        title: qsTr("Reset OmniStore preferences?")
        message: qsTr("AI assistance will be turned off and local preferences cleared. Installed software and sources are not changed.")
        icon: "restart_alt"
        confirmText: qsTr("Reset")
        cancelText: qsTr("Cancel")
        onConfirmed: {
            accountAi.resetFeatures()
            root.themePreferenceSelected("system")
        }
    }

    MeoDialog {
        id: sourceReviewDialog
        parent: Overlay.overlay
        title: qsTr("Enable %1?").arg(root.pendingPluginName)
        message: (root.pendingNeedsReview
                  ? qsTr("This source is marked as requiring review. Packages from it may not receive the same trust or verification guarantees as the default system sources. Enable it only if you want OmniStore to search and install from this source.")
                  : qsTr("OmniStore will use this source to search and install apps."))
                 + (root.pendingNeedsSetup
                    ? " " + qsTr("If a tool it needs is missing, OmniStore installs it first and skips anything already installed. You may be asked to authorize.")
                    : "")
        icon: "warning"
        confirmText: qsTr("Enable source")
        cancelText: qsTr("Cancel")
        onConfirmed: {
            if (root.pendingPluginId.length > 0)
                backend.setPluginEnabled(root.pendingPluginId, true)
            root.pendingPluginId = ""
            root.pendingPluginName = ""
        }
        onCancelled: {
            root.pendingPluginId = ""
            root.pendingPluginName = ""
            backend.loadPlugins()
        }
    }
}
