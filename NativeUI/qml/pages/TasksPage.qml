pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import MeoUI 1.0

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28 * MeoTheme.globalScale
        spacing: 14 * MeoTheme.globalScale

        PageHeading {
            Layout.fillWidth: true
            title: qsTr("Tasks")
            subtitle: qsTr("Live output from the existing OmniStore package backend. Long-running package actions can be cancelled here.")
            icon: "download"
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
                        color: backend.busy ? MeoTheme.primaryContainer : MeoTheme.secondaryContainer
                        MeoIcon {
                            anchors.centerIn: parent
                            icon: backend.busy ? "sync" : "check_circle"
                            size: 25 * MeoTheme.globalScale
                            color: backend.busy ? MeoTheme.contentOnPrimaryContainer
                                                : MeoTheme.contentOnSecondaryContainer
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2 * MeoTheme.globalScale
                        MeoText {
                            Layout.fillWidth: true
                            text: backend.busy ? backend.busyAction : qsTr("No active task")
                            typeRole: "title"; typeSize: "small"; emphasized: true
                            color: MeoTheme.contentOnSurface
                            elide: Text.ElideRight
                        }
                        MeoText {
                            Layout.fillWidth: true
                            text: backend.taskStage.length > 0 ? backend.taskStage : backend.statusMessage
                            typeRole: "body"; typeSize: "small"
                            color: MeoTheme.contentOnSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }
                    MeoText {
                        visible: backend.taskSpeed.length > 0
                        text: backend.taskSpeed
                        typeRole: "label"; typeSize: "medium"; emphasized: true
                        color: MeoTheme.primary
                    }
                }

                MeoProgressBar {
                    Layout.fillWidth: true
                    visible: backend.busy || backend.progress >= 0
                    value: backend.progress >= 0 ? backend.progress : 0
                    indeterminate: backend.busy && backend.progress < 0
                    linearStyle: "pill"
                    wavy: backend.busy
                }

                MeoBanner {
                    Layout.fillWidth: true
                    visible: backend.errorMessage.length > 0
                    title: qsTr("Task error")
                    text: backend.errorMessage
                    icon: "error"
                    tone: "error"
                }

                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    MeoButton {
                        text: qsTr("Clear log")
                        type: "text"
                        icon.name: "delete_sweep"
                        enabled: backend.taskLog.length > 0 && !backend.busy
                        onClicked: backend.clearTaskLog()
                    }
                    MeoButton {
                        visible: backend.busy
                        text: qsTr("Cancel")
                        type: "outlined"
                        icon.name: "stop"
                        onClicked: backend.cancelOperation()
                    }
                }
            }
        }

        MeoTextArea {
            Layout.fillWidth: true
            Layout.fillHeight: true
            label: qsTr("Backend output")
            text: backend.taskLog.length > 0 ? backend.taskLog : qsTr("Package operation logs will appear here.")
            readOnly: true
            type: "filled"
            selectByMouse: true
        }
    }
}
