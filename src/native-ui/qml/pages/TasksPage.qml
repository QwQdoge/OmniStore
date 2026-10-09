pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeoUI 1.0
import OmniStore.Native 1.0 as Store

Item {
    id: root

    function sourceStatusLabel(status) {
        if (status === "queued") return qsTr("Waiting")
        if (status === "running") return qsTr("Updating")
        if (status === "succeeded") return qsTr("Completed")
        if (status === "failed") return qsTr("Failed")
        if (status === "skipped") return qsTr("Skipped")
        return status
    }

    function sourceSummary() {
        const rows = transactions.sourceUpdates || []
        const planned = rows.filter(row => row.status !== "skipped")
        const finished = planned.filter(row => row.status === "succeeded" || row.status === "failed")
        return qsTr("Sources finished: %1 / %2").arg(finished.length).arg(planned.length)
    }

    function statusLabel() {
        const value = String(transactions.status || "")
        if (value === "queued") return qsTr("Queued")
        if (value === "running") return qsTr("Running")
        if (value === "succeeded") return qsTr("Completed")
        if (value === "failed") return qsTr("Failed")
        if (value === "cancelled") return qsTr("Cancelled")
        return qsTr("No package task")
    }

    function statusIcon() {
        const value = String(transactions.status || "")
        if (value === "queued") return "schedule"
        if (value === "running") return "sync"
        if (value === "succeeded") return "check_circle"
        if (value === "failed") return "error"
        if (value === "cancelled") return "cancel"
        return transactions.available ? "download_done" : "cloud_off"
    }

    Component.onCompleted: transactions.reconnect()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28 * MeoTheme.globalScale
        spacing: 14 * MeoTheme.globalScale

        Store.PageHeading {
            Layout.fillWidth: true
            title: qsTr("Tasks")
            subtitle: qsTr("Package transactions are owned by the OmniStore background service, so they can continue after this window closes.")
            icon: "download"
        }

        MeoBanner {
            Layout.fillWidth: true
            visible: !transactions.available
            title: qsTr("Transaction service unavailable")
            text: transactions.errorMessage.length > 0
                  ? transactions.errorMessage
                  : qsTr("Reconnect to restore package task state.")
            icon: "cloud_off"
            tone: "warning"
            confirmText: qsTr("Reconnect")
            onConfirmed: transactions.reconnect()
        }

        MeoCard {
            Layout.fillWidth: true
            type: "filled"
            padding: 18 * MeoTheme.globalScale

            ColumnLayout {
                width: parent.width
                spacing: 10 * MeoTheme.globalScale

                RowLayout {
                    Layout.fillWidth: true
                    MeoShape {
                        Layout.preferredWidth: 48 * MeoTheme.globalScale
                        Layout.preferredHeight: 48 * MeoTheme.globalScale
                        type: "squircle"
                        radius: 16 * MeoTheme.globalScale
                        color: transactions.busy ? MeoTheme.primaryContainer
                                                 : MeoTheme.secondaryContainer
                        MeoIcon {
                            anchors.centerIn: parent
                            icon: root.statusIcon()
                            size: 25 * MeoTheme.globalScale
                            color: transactions.busy ? MeoTheme.contentOnPrimaryContainer
                                                     : MeoTheme.contentOnSecondaryContainer
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2 * MeoTheme.globalScale
                        MeoText {
                            Layout.fillWidth: true
                            text: transactions.actionName.length > 0
                                  ? transactions.actionName
                                  : root.statusLabel()
                            typeRole: "title"
                            typeSize: "small"
                            emphasized: true
                            color: MeoTheme.contentOnSurface
                            elide: Text.ElideRight
                        }
                        MeoText {
                            Layout.fillWidth: true
                            text: transactions.stage.length > 0
                                  ? transactions.stage
                                  : root.statusLabel()
                            typeRole: "body"
                            typeSize: "small"
                            color: MeoTheme.contentOnSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }

                    MeoText {
                        visible: transactions.speed.length > 0
                        text: transactions.speed
                        typeRole: "label"
                        typeSize: "medium"
                        emphasized: true
                        color: MeoTheme.primary
                    }
                }

                MeoProgressBar {
                    Layout.fillWidth: true
                    visible: transactions.busy || transactions.progress >= 0
                    value: transactions.progress >= 0 ? transactions.progress : 0
                    indeterminate: transactions.busy && transactions.progress < 0
                    linearStyle: "pill"
                    wavy: transactions.busy
                }

                MeoText {
                    visible: transactions.sourceUpdates.length > 0
                    text: root.sourceSummary()
                    typeRole: "label"
                    typeSize: "medium"
                    color: MeoTheme.contentOnSurfaceVariant
                }

                RowLayout {
                    Layout.fillWidth: true
                    MeoText {
                        Layout.fillWidth: true
                        text: transactions.taskId.length > 0
                              ? qsTr("Task %1").arg(transactions.taskId.slice(0, 12))
                              : qsTr("No remembered package transaction")
                        typeRole: "label"
                        typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                        elide: Text.ElideRight
                    }
                    MeoButton {
                        text: qsTr("Refresh")
                        type: "text"
                        icon.name: "refresh"
                        onClicked: transactions.reconnect()
                    }
                }
            }
        }

        ScrollView {
            id: sourceScroll
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(sourceColumn.implicitHeight, root.height * 0.35)
            visible: transactions.sourceUpdates.length > 0
            clip: true
            contentWidth: availableWidth
            contentHeight: sourceColumn.implicitHeight
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                id: sourceColumn
                width: sourceScroll.availableWidth
                spacing: 8 * MeoTheme.globalScale
                Repeater {
                    model: transactions.sourceUpdates
                    delegate: MeoCard {
                        required property var modelData
                        Layout.fillWidth: true
                        padding: 12 * MeoTheme.globalScale
                        type: "filled"
                        ColumnLayout {
                            width: parent.width
                            MeoText {
                                Layout.fillWidth: true
                                text: String(modelData.source) + " · " + root.sourceStatusLabel(modelData.status)
                                typeRole: "title"
                                typeSize: "small"
                                color: modelData.status === "failed" ? MeoTheme.error : MeoTheme.contentOnSurface
                            }
                            MeoText {
                                Layout.fillWidth: true
                                visible: !!modelData.detail
                                text: String(modelData.detail || "")
                                elide: Text.ElideRight
                                typeRole: "body"
                                typeSize: "small"
                                color: MeoTheme.contentOnSurfaceVariant
                            }
                            MeoProgressBar {
                                Layout.fillWidth: true
                                visible: modelData.status === "running"
                                indeterminate: modelData.progress === null || modelData.progress === undefined
                                value: Number(modelData.progress || 0)
                            }
                            MeoText {
                                visible: modelData.status === "running" && modelData.progress !== null && modelData.progress !== undefined
                                text: qsTr("Current operation: %1%").arg(Math.round(Number(modelData.progress || 0) * 100))
                                typeRole: "label"
                                typeSize: "small"
                                color: MeoTheme.contentOnSurfaceVariant
                            }
                        }
                    }
                }
            }
        }

        MeoBanner {
            Layout.fillWidth: true
            visible: transactions.errorMessage.length > 0 && transactions.available
            title: qsTr("Task error")
            text: transactions.errorMessage
            icon: "error"
            tone: "error"
            confirmText: qsTr("Dismiss")
            onConfirmed: transactions.clearError()
        }

        MeoTextArea {
            Layout.fillWidth: true
            Layout.fillHeight: true
            label: qsTr("Transaction output")
            text: transactions.log.length > 0
                  ? transactions.log
                  : qsTr("Package transaction output will appear here. Reopening OmniStore restores the latest task from the background service.")
            readOnly: true
            type: "filled"
            selectByMouse: true
        }

        MeoText {
            Layout.fillWidth: true
            text: qsTr("Closing OmniStore is not cancellation. Explicit transaction cancellation is intentionally unavailable until each package backend can prove safe interruption semantics.")
            typeRole: "body"
            typeSize: "small"
            color: MeoTheme.contentOnSurfaceVariant
            wrapMode: Text.WordWrap
        }
    }
}
