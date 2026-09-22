pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import MeoUI 1.0

Item {
    id: root

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

                MeoSettingsRow {
                    title: qsTr("Dark mode")
                    subtitle: qsTr("Use MeoUI's dark color roles in this OmniStore window.")
                    leadingIcon: "dark_mode"
                    trailingKind: "switch"
                    checked: MeoTheme.isDarkMode
                    onToggled: function(value) { MeoTheme.isDarkMode = value }
                }
            }

            MeoSettingsGroup {
                Layout.fillWidth: true
                title: qsTr("Package sources")

                Repeater {
                    model: backend.plugins
                    delegate: MeoSettingsRow {
                        id: sourceRow
                        required property var modelData
                        title: String(modelData.name || modelData.id || qsTr("Source"))
                        subtitle: String(modelData.description || modelData.id || "")
                        leadingIcon: modelData.enabled ? "extension" : "extension_off"
                        trailingKind: "switch"
                        checked: !!modelData.enabled
                        enabled: !backend.busy
                        onToggled: function(value) {
                            backend.setPluginEnabled(String(sourceRow.modelData.id || ""), value)
                        }
                    }
                }

                MeoSettingsRow {
                    visible: backend.plugins.length === 0
                    title: qsTr("No source registry available")
                    subtitle: backend.busy ? qsTr("Loading source plugins…")
                                           : qsTr("The backend did not return any installed source plugins.")
                    leadingIcon: "extension_off"
                    trailingKind: "none"
                }
            }

            MeoSettingsGroup {
                Layout.fillWidth: true
                title: qsTr("Backend")

                MeoSettingsRow {
                    title: qsTr("Runtime")
                    subtitle: backend.backendDescription
                    leadingIcon: "terminal"
                    trailingKind: "none"
                }
                MeoSettingsRow {
                    title: qsTr("Current state")
                    subtitle: backend.statusMessage
                    leadingIcon: backend.busy ? "sync" : "check_circle"
                    trailingKind: "none"
                }
                MeoSettingsRow {
                    title: qsTr("Storage information")
                    subtitle: backend.storageInfo && Object.keys(backend.storageInfo).length > 0
                              ? JSON.stringify(backend.storageInfo)
                              : qsTr("No storage summary returned yet.")
                    leadingIcon: "storage"
                    trailingKind: "none"
                }
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
                        text: qsTr("Read-only view for the migration phase. Existing config validation remains in Python instead of being duplicated in QML.")
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
