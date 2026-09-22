pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import MeoUI 1.0

Flickable {
    id: root
    property var fallbackApp: ({})
    readonly property var app: backend.selectedApp && Object.keys(backend.selectedApp).length > 0
                               ? backend.selectedApp : fallbackApp

    clip: true
    contentWidth: width
    contentHeight: detailColumn.implicitHeight + 40 * MeoTheme.globalScale
    boundsBehavior: Flickable.StopAtBounds

    function appName() { return String(app.name || app.id || qsTr("App details")) }
    function appId() { return String(app.id || app.name || "") }
    function sourceName() { return String(app.primary_source || app.source || "Native") }

    ColumnLayout {
        id: detailColumn
        width: parent.width - 32 * MeoTheme.globalScale
        x: 16 * MeoTheme.globalScale
        spacing: 14 * MeoTheme.globalScale

        MeoShape {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 84 * MeoTheme.globalScale
            Layout.preferredHeight: 84 * MeoTheme.globalScale
            type: "squircle"
            radius: 28 * MeoTheme.globalScale
            color: MeoTheme.primaryContainer
            MeoIcon {
                anchors.centerIn: parent
                icon: root.app.installed ? "check_circle" : "apps"
                size: 40 * MeoTheme.globalScale
                color: MeoTheme.contentOnPrimaryContainer
            }
        }

        MeoText {
            Layout.fillWidth: true
            text: root.appName()
            typeRole: "headline"; typeSize: "small"; emphasized: true
            horizontalAlignment: Text.AlignHCenter
            color: MeoTheme.contentOnSurface
            wrapMode: Text.WordWrap
        }
        MeoText {
            Layout.fillWidth: true
            text: root.sourceName() + (root.app.version ? " · " + String(root.app.version) : "")
            typeRole: "label"; typeSize: "medium"
            horizontalAlignment: Text.AlignHCenter
            color: MeoTheme.primary
        }

        MeoProgressBar {
            Layout.fillWidth: true
            visible: backend.busyAction === qsTr("app details")
            indeterminate: true
        }

        MeoText {
            Layout.fillWidth: true
            text: String(root.app.description || qsTr("No description is available for this package."))
            typeRole: "body"; typeSize: "medium"
            color: MeoTheme.contentOnSurfaceVariant
            wrapMode: Text.WordWrap
        }

        MeoCard {
            Layout.fillWidth: true
            visible: root.app.developer || root.app.license || root.app.installed_size || root.app.install_location
            type: "filled"
            padding: 14 * MeoTheme.globalScale
            ColumnLayout {
                width: parent.width
                spacing: 7 * MeoTheme.globalScale
                MeoText {
                    visible: !!root.app.developer
                    text: qsTr("Developer · %1").arg(String(root.app.developer || ""))
                    typeRole: "body"; typeSize: "small"; color: MeoTheme.contentOnSurfaceVariant
                    wrapMode: Text.WordWrap
                }
                MeoText {
                    visible: !!root.app.license
                    text: qsTr("License · %1").arg(String(root.app.license || ""))
                    typeRole: "body"; typeSize: "small"; color: MeoTheme.contentOnSurfaceVariant
                }
                MeoText {
                    visible: !!root.app.installed_size
                    text: qsTr("Installed size · %1").arg(String(root.app.installed_size || ""))
                    typeRole: "body"; typeSize: "small"; color: MeoTheme.contentOnSurfaceVariant
                }
                MeoText {
                    visible: !!root.app.install_location
                    text: qsTr("Location · %1").arg(String(root.app.install_location || ""))
                    typeRole: "body"; typeSize: "small"; color: MeoTheme.contentOnSurfaceVariant
                    wrapMode: Text.WrapAnywhere
                }
            }
        }

        MeoText {
            visible: (root.app.variants || []).length > 0
            text: qsTr("Available variants")
            typeRole: "title"; typeSize: "small"; emphasized: true
            color: MeoTheme.contentOnSurface
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: (root.app.variants || []).length > 0
            spacing: 4 * MeoTheme.globalScale
            Repeater {
                model: root.app.variants || []
                delegate: MeoListItem {
                    required property var modelData
                    Layout.fillWidth: true
                    headline: String(modelData.source || qsTr("Source"))
                    supportingText: String(modelData.version || qsTr("Unknown version"))
                    leadingIcon: modelData.installed ? "check_circle" : "package_2"
                    trailingKind: "none"
                    interactive: false
                    isSegmented: true
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * MeoTheme.globalScale
            MeoButton {
                visible: !!root.app.installed
                Layout.fillWidth: true
                text: qsTr("Open")
                type: "tonal"
                icon.name: "open_in_new"
                enabled: !backend.busy
                onClicked: backend.launchApp(root.appId(), root.sourceName())
            }
            MeoButton {
                visible: !root.app.installed
                Layout.fillWidth: true
                text: qsTr("Install")
                type: "filled"
                icon.name: "download"
                enabled: !backend.busy
                onClicked: backend.installApp(root.appId(), root.sourceName(), String(root.app.url || ""))
            }
        }

        MeoBanner {
            Layout.fillWidth: true
            visible: backend.errorMessage.length > 0
            title: qsTr("Details unavailable")
            text: backend.errorMessage
            icon: "error"
            tone: "error"
        }
    }
}
