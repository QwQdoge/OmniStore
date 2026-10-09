pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeoUI 1.0

MeoCard {
    id: root
    required property var app
    property bool installedContext: false
    signal detailsRequested(var app)

    Layout.fillWidth: true
    type: "filled"
    compact: true
    padding: 14 * MeoTheme.globalScale

    function appName() { return String(app.name || app.id || qsTr("Unknown app")) }
    function appId() { return String(app.id || app.name || "") }
    function sourceName() { return String(app.primary_source || app.source || "Native") }
    function versionText() { return String(app.version || "") }

    RowLayout {
        width: parent.width
        spacing: 14 * MeoTheme.globalScale

        MeoShape {
            Layout.preferredWidth: 48 * MeoTheme.globalScale
            Layout.preferredHeight: 48 * MeoTheme.globalScale
            type: "squircle"
            radius: 16 * MeoTheme.globalScale
            color: MeoTheme.secondaryContainer

            MeoIcon {
                anchors.centerIn: parent
                icon: app.installed || root.installedContext ? "check_circle" : "apps"
                size: 25 * MeoTheme.globalScale
                color: MeoTheme.contentOnSecondaryContainer
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2 * MeoTheme.globalScale

            MeoText {
                Layout.fillWidth: true
                text: root.appName()
                typeRole: "title"
                typeSize: "small"
                emphasized: true
                color: MeoTheme.contentOnSurface
                elide: Text.ElideRight
            }
            MeoText {
                Layout.fillWidth: true
                text: root.sourceName() + (root.versionText().length > 0 ? " · " + root.versionText() : "")
                typeRole: "label"
                typeSize: "small"
                color: MeoTheme.primary
                elide: Text.ElideRight
            }
            MeoText {
                Layout.fillWidth: true
                visible: String(root.app.description || "").length > 0
                text: String(root.app.description || "")
                typeRole: "body"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
                maximumLineCount: 2
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
            }
        }

        RowLayout {
            spacing: 6 * MeoTheme.globalScale

            MeoButton {
                visible: root.app.installed || root.installedContext
                text: qsTr("Open")
                type: "text"
                icon.name: "open_in_new"
                enabled: !backend.busy
                onClicked: backend.launchApp(root.appId(), root.sourceName())
            }
            MeoButton {
                visible: root.app.installed || root.installedContext
                text: qsTr("Remove")
                type: "outlined"
                icon.name: "delete"
                enabled: !backend.busy && !transactions.busy
                onClicked: removeDialog.open()
            }
            MeoIconButton {
                icon.name: "chevron_right"
                type: "standard"
                Accessible.name: qsTr("App details")
                onClicked: root.detailsRequested(root.app)
            }
        }
    }

    MeoDialog {
        id: removeDialog
        parent: Overlay.overlay
        title: qsTr("Remove %1?").arg(root.appName())
        message: qsTr("OmniStore will hand this uninstall to its background transaction service using %1. Package-manager safeguards remain unchanged.").arg(root.sourceName())
        icon: "delete"
        confirmText: qsTr("Remove")
        cancelText: qsTr("Cancel")
        onConfirmed: transactions.removeApp(root.appId(), root.sourceName())
    }
}
