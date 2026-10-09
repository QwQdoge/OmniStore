pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeoUI 1.0

Item {
    id: root

    Component.onCompleted: {
        if (backend.updates.length === 0)
            backend.loadUpdates()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28 * MeoTheme.globalScale
        spacing: 14 * MeoTheme.globalScale

        RowLayout {
            Layout.fillWidth: true
            PageHeading {
                Layout.fillWidth: true
                title: qsTr("Updates")
                subtitle: qsTr("One review surface for updates reported by every enabled OmniStore source.")
                icon: "system_update"
            }
            MeoButton {
                text: qsTr("Check")
                type: "tonal"
                icon.name: "refresh"
                enabled: !backend.busy && !transactions.busy
                onClicked: backend.loadUpdates()
            }
            MeoButton {
                visible: backend.updates.length > 0
                text: qsTr("Update all")
                type: "filled"
                icon.name: "upgrade"
                enabled: !backend.busy && !transactions.busy && transactions.available
                onClicked: updateAllDialog.open()
            }
        }

        MeoCard {
            Layout.fillWidth: true
            type: "filled"
            padding: 16 * MeoTheme.globalScale
            RowLayout {
                width: parent.width
                spacing: 12 * MeoTheme.globalScale
                MeoShape {
                    Layout.preferredWidth: 48 * MeoTheme.globalScale
                    Layout.preferredHeight: 48 * MeoTheme.globalScale
                    type: "squircle"
                    radius: 16 * MeoTheme.globalScale
                    color: transactions.busy || backend.updates.length > 0
                           ? MeoTheme.primaryContainer : MeoTheme.secondaryContainer
                    MeoIcon {
                        anchors.centerIn: parent
                        icon: transactions.busy ? "sync"
                              : backend.updates.length > 0 ? "download" : "check_circle"
                        size: 25 * MeoTheme.globalScale
                        color: transactions.busy || backend.updates.length > 0
                               ? MeoTheme.contentOnPrimaryContainer
                               : MeoTheme.contentOnSecondaryContainer
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2 * MeoTheme.globalScale
                    MeoText {
                        text: transactions.busy
                              ? qsTr("Update transaction in progress")
                              : backend.updates.length > 0
                                ? qsTr("%1 updates available").arg(backend.updates.length)
                                : qsTr("Up to date")
                        typeRole: "title"; typeSize: "small"; emphasized: true
                        color: MeoTheme.contentOnSurface
                    }
                    MeoText {
                        Layout.fillWidth: true
                        text: transactions.busy
                              ? qsTr("The transaction is owned by the background OmniStore service and can continue after this window closes.")
                              : qsTr("The backend checks the real package sources; this UI does not synthesize update state.")
                        typeRole: "body"; typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        MeoProgressBar {
            Layout.fillWidth: true
            visible: backend.busyAction === qsTr("updates") || transactions.busy
            indeterminate: transactions.busy ? transactions.progress < 0 : true
            value: transactions.progress >= 0 ? transactions.progress : 0
        }

        MeoBanner {
            Layout.fillWidth: true
            visible: transactions.errorMessage.length > 0
            title: qsTr("Transaction service needs attention")
            text: transactions.errorMessage
            icon: "error"
            tone: "error"
            confirmText: qsTr("Dismiss")
            onConfirmed: transactions.clearError()
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: backend.updates.length > 0
            clip: true
            spacing: 8 * MeoTheme.globalScale
            model: backend.updates
            boundsBehavior: Flickable.StopAtBounds
            delegate: UpdateRow {
                required property var modelData
                width: ListView.view.width
                update: modelData
            }
        }

        MeoEmptyState {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: backend.updates.length === 0 && !backend.busy && !transactions.busy
            icon: "verified"
            title: qsTr("Everything is up to date")
            description: qsTr("Run another check whenever you want to refresh all enabled sources.")
        }
    }

    MeoDialog {
        id: updateAllDialog
        parent: Overlay.overlay
        title: qsTr("Update all %1 items?").arg(backend.updates.length)
        message: qsTr("OmniStore will submit one background update transaction. It continues independently from this window and stays visible from Tasks after reopening the store.")
        icon: "system_update"
        confirmText: qsTr("Update all")
        cancelText: qsTr("Cancel")
        onConfirmed: transactions.updateAll()
    }
}
