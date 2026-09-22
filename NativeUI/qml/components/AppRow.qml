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
    function installUrl() {
        const variants = app.variants || []
        for (let index = 0; index < variants.length; ++index) {
            if (String(variants[index].source || "") === sourceName() && variants[index].url)
                return String(variants[index].url)
        }
        return String(app.url || "")
    }

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
                enabled: !backend.busy
                onClicked: removeDialog.open()
            }
            MeoButton {
                visible: !(root.app.installed || root.installedContext)
                text: qsTr("Install")
                type: "filled"
                icon.name: "download"
                enabled: !backend.busy
                onClicked: installDialog.open()
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
        id: installDialog
        parent: Overlay.overlay
        title: qsTr("Install %1?").arg(root.appName())
        message: qsTr("OmniStore will ask the existing %1 backend to install this app. Package permissions and authentication remain handled by the current backend.").arg(root.sourceName())
        icon: "download"
        confirmText: qsTr("Install")
        cancelText: qsTr("Cancel")
        onConfirmed: backend.installApp(root.appId(), root.sourceName(), root.installUrl())
    }

    MeoDialog {
        id: removeDialog
        parent: Overlay.overlay
        title: qsTr("Remove %1?").arg(root.appName())
        message: qsTr("This uses OmniStore's existing uninstall path for %1. Review the task output if the package manager asks for authentication or reports dependent packages.").arg(root.sourceName())
        icon: "delete"
        confirmText: qsTr("Remove")
        cancelText: qsTr("Cancel")
        onConfirmed: backend.removeApp(root.appId(), root.sourceName())
    }
}
