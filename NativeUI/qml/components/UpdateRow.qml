pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeoUI 1.0

MeoCard {
    id: root
    required property var update

    Layout.fillWidth: true
    type: "filled"
    compact: true
    padding: 14 * MeoTheme.globalScale

    function packageName() { return String(update.name || "") }
    function sourceName() { return String(update.source || "Native") }

    RowLayout {
        width: parent.width
        spacing: 14 * MeoTheme.globalScale

        MeoShape {
            Layout.preferredWidth: 46 * MeoTheme.globalScale
            Layout.preferredHeight: 46 * MeoTheme.globalScale
            type: "squircle"
            radius: 15 * MeoTheme.globalScale
            color: MeoTheme.primaryContainer
            MeoIcon {
                anchors.centerIn: parent
                icon: "system_update"
                size: 24 * MeoTheme.globalScale
                color: MeoTheme.contentOnPrimaryContainer
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2 * MeoTheme.globalScale
            MeoText {
                Layout.fillWidth: true
                text: root.packageName()
                typeRole: "title"
                typeSize: "small"
                emphasized: true
                color: MeoTheme.contentOnSurface
                elide: Text.ElideRight
            }
            MeoText {
                Layout.fillWidth: true
                text: root.sourceName() + " · "
                      + String(root.update.current_version || qsTr("Unknown"))
                      + " → " + String(root.update.new_version || qsTr("Unknown"))
                typeRole: "body"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
                elide: Text.ElideRight
            }
        }

        MeoButton {
            text: qsTr("Update")
            type: "tonal"
            icon.name: "upgrade"
            enabled: !backend.busy
            onClicked: updateDialog.open()
        }
    }

    MeoDialog {
        id: updateDialog
        parent: Overlay.overlay
        title: qsTr("Update %1?").arg(root.packageName())
        message: qsTr("OmniStore will update this package through %1 using the existing backend and package-manager safeguards.").arg(root.sourceName())
        icon: "upgrade"
        confirmText: qsTr("Update")
        cancelText: qsTr("Cancel")
        onConfirmed: backend.updateApp(root.packageName(), root.sourceName())
    }
}
