pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import MeoUI 1.0

Item {
    id: root

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

    function pluginRows() {
        const rows = []
        for (let index = 0; index < backend.plugins.length; ++index) {
            const plugin = backend.plugins[index]
            const pluginId = String(plugin.id || "")
            rows.push({
                "title": String(plugin.name || plugin.id || qsTr("Source")),
                "subtitle": String(plugin.description || plugin.id || ""),
                "leadingIcon": plugin.enabled ? "extension" : "extension_off",
                "trailingKind": "switch",
                "checked": !!plugin.enabled,
                "enabled": !backend.busy && pluginId.length > 0,
                "onToggled": function(value) {
                    backend.setPluginEnabled(pluginId, value)
                }
            })
        }
        if (rows.length === 0) {
            rows.push({
                "title": qsTr("No source registry available"),
                "subtitle": backend.busy ? qsTr("Loading source plugins…")
                                         : qsTr("The backend did not return any installed source plugins."),
                "leadingIcon": "extension_off",
                "trailingKind": "none",
                "interactive": false
            })
        }
        return rows
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
            },
            {
                "title": qsTr("Storage information"),
                "subtitle": backend.storageInfo && Object.keys(backend.storageInfo).length > 0
                            ? JSON.stringify(backend.storageInfo)
                            : qsTr("No storage summary returned yet."),
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
                subtitle: qsTr("Configure the native interface and the same OmniStore source registry used by the existing backend.")
                icon: "settings"
            }

            MeoSettingsGroup {
                Layout.fillWidth: true
                title: qsTr("Appearance")
                model: root.appearanceRows()
            }

            MeoSettingsGroup {
                Layout.fillWidth: true
                title: qsTr("Package sources")
                subtitle: qsTr("These switches modify the existing OmniStore source-plugin registry, not a separate NativeUI setting.")
                model: root.pluginRows()
            }

            MeoSettingsGroup {
                Layout.fillWidth: true
                title: qsTr("Backend")
                model: root.backendRows()
            }

            MeoCard {
                Layout.fillWidth: true
                type: "filled"
                padding: 18 * MeoTheme.globalScale
                ColumnLayout {
                    width: parent.width
                    spacing: 8 * MeoTheme.globalScale
                    MeoText {
                        text: qsTr("Backend configuration")
                        typeRole: "title"; typeSize: "small"; emphasized: true
                        color: MeoTheme.contentOnSurface
                    }
                    MeoText {
                        Layout.fillWidth: true
                        text: qsTr("Read-only during the native migration. Existing config validation remains in Python instead of being duplicated in QML.")
                        typeRole: "body"; typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                        wrapMode: Text.WordWrap
                    }
                    MeoTextArea {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 220 * MeoTheme.globalScale
                        text: JSON.stringify(backend.config, null, 2)
                        readOnly: true
                        type: "filled"
                        selectByMouse: true
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                MeoButton {
                    text: qsTr("Refresh settings")
                    type: "tonal"
                    icon.name: "refresh"
                    enabled: !backend.busy
                    onClicked: {
                        backend.loadPlugins()
                        backend.loadConfig()
                        backend.loadStorageInfo()
                    }
                }
            }
        }
    }
}
