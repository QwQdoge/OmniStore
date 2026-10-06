pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import MeoUI 1.0

MeoCard {
    id: root
    required property var app
    property bool prominent: false
    signal detailsRequested(var app)

    type: "filled"
    interactive: true
    padding: 0
    implicitHeight: prominent ? 286 * MeoTheme.globalScale : 224 * MeoTheme.globalScale
    onClicked: root.detailsRequested(root.app)

    function appName() { return String(app.name || app.id || qsTr("Unknown app")) }
    function sourceName() { return String(app.primary_source || app.source || qsTr("Native")) }
    function versionText() { return String(app.version || "") }
    function artwork() {
        const shots = app.screenshots || []
        if (shots.length > 0 && String(shots[0]).length > 0)
            return String(shots[0])
        return String(app.icon || "")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.prominent ? 170 * MeoTheme.globalScale : 112 * MeoTheme.globalScale
            clip: true

            MeoShape {
                anchors.fill: parent
                type: "rect"
                color: MeoTheme.secondaryContainer
            }

            Image {
                id: artworkImage
                anchors.fill: parent
                source: root.artwork()
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
                visible: source.toString().length > 0 && status === Image.Ready
            }

            MeoIcon {
                anchors.centerIn: parent
                visible: !artworkImage.visible
                icon: root.app.installed ? "check_circle" : "apps"
                size: root.prominent ? 54 * MeoTheme.globalScale : 38 * MeoTheme.globalScale
                color: MeoTheme.contentOnSecondaryContainer
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 16 * MeoTheme.globalScale
            Layout.rightMargin: 16 * MeoTheme.globalScale
            Layout.topMargin: 12 * MeoTheme.globalScale
            Layout.bottomMargin: 14 * MeoTheme.globalScale
            spacing: 4 * MeoTheme.globalScale

            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * MeoTheme.globalScale

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1 * MeoTheme.globalScale
                    MeoText {
                        Layout.fillWidth: true
                        text: root.appName()
                        typeRole: "title"
                        typeSize: root.prominent ? "medium" : "small"
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
                }

                MeoIcon {
                    visible: !!root.app.installed
                    icon: "check_circle"
                    size: 20 * MeoTheme.globalScale
                    color: MeoTheme.primary
                }
            }

            MeoText {
                Layout.fillWidth: true
                visible: String(root.app.description || "").length > 0
                text: String(root.app.description || "")
                typeRole: "body"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
                maximumLineCount: root.prominent ? 2 : 1
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
            }
        }
    }
}
