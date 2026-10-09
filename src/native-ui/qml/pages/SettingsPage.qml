pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeoUI 1.0

Item {
    id: root

    property string pendingPluginId: ""
    property string pendingPluginName: ""

    function appearanceRows() {
        return [{
            "title": qsTr("Dark mode"),
            "subtitle": qsTr("Use MeoUI's dark color roles in this OmniStore window."),
            "leadingIcon": "dark_mode",
            "trailingKind": "switch",
            "checked": MeoTheme.isDarkMode,
            "onToggled": function(value) { MeoTheme.isDarkMode = value }
        }]
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
        if (String(plugin.error || "").length > 0)
            parts.push(String(plugin.error))
        return parts.join("  •  ")
    }

    function sourceGroup(plugin) {
        const id = String(plugin.id || "").toLowerCase()
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
        if (value && plugin.requires_review) {
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
        backend.loadPlugins()
        backend.loadConfig()
        backend.loadStorageInfo()
        repoBridge.refresh()
    }

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: settingsColumn.implicitHeight + 64 * MeoTheme.globalScale
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsColumn
            width: Math.min(parent.width - 56 * MeoTheme.globalScale,
                            980 * MeoTheme.globalScale)
            x: (parent.width - width) / 2
            y: 28 * MeoTheme.globalScale
            spacing: 18 * MeoTheme.globalScale

            PageHeading {
                Layout.fillWidth: true
                title: qsTr("Settings")
                subtitle: qsTr("Configure OmniStore using the capabilities and sources detected on this system.")
                icon: "settings"
            }

            MeoSettingsGroup {
                Layout.fillWidth: true
                title: qsTr("Appearance")
                model: root.appearanceRows()
            }

            SystemStatusPanel {
                Layout.fillWidth: true
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

            RepositoryManager {
                Layout.fillWidth: true
            }

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
        }
    }

    MeoDialog {
        id: sourceReviewDialog
        parent: Overlay.overlay
        title: qsTr("Enable %1?").arg(root.pendingPluginName)
        message: qsTr("This source is marked as requiring review. Packages from it may not receive the same trust or verification guarantees as the default system sources. Enable it only if you want OmniStore to search and install from this source.")
        icon: "warning"
        confirmText: qsTr("Enable source")
        cancelText: qsTr("Cancel")
        onConfirmed: {
            if (root.pendingPluginId.length > 0)
                backend.setPluginEnabled(root.pendingPluginId, true)
            root.pendingPluginId = ""
            root.pendingPluginName = ""
        }
        onRejected: {
            root.pendingPluginId = ""
            root.pendingPluginName = ""
        }
    }
}
