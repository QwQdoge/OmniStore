import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeoUI 1.0
import "pages"

ApplicationWindow {
    id: window

    width: 1280 * MeoTheme.globalScale
    height: 820 * MeoTheme.globalScale
    minimumWidth: 960 * MeoTheme.globalScale
    minimumHeight: 640 * MeoTheme.globalScale
    visible: true
    title: qsTr("OmniStore preview")
    color: MeoTheme.surface

    property int currentPage: 0
    required property var installedUsageSummary
    required property var installedUsageModel

    header: Item {
        implicitHeight: 80 * MeoTheme.globalScale

        Rectangle {
            anchors.fill: parent
            color: MeoTheme.surface
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: MeoTheme.space32
            anchors.rightMargin: MeoTheme.space32
            spacing: MeoTheme.space12

            MeoIcon {
                icon: "storefront"
                size: 28 * MeoTheme.globalScale
                color: MeoTheme.primary
                Accessible.ignored: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                MeoText {
                    text: qsTr("OmniStore")
                    typeRole: "title"
                    typeSize: "medium"
                    emphasized: true
                }

                MeoText {
                    text: qsTr("Your local library, in preview")
                    typeRole: "body"
                    typeSize: "small"
                    color: MeoTheme.contentOnSurfaceVariant
                }
            }

            MeoText {
                text: window.installedUsageSummary.available
                      ? qsTr("Local library")
                      : qsTr("Preview mode")
                typeRole: "label"
                typeSize: "medium"
                color: MeoTheme.primary
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: MeoTheme.space24
        spacing: MeoTheme.space24

        MeoCard {
            Layout.preferredWidth: 240 * MeoTheme.globalScale
            Layout.fillHeight: true
            type: "filled"
            radius: MeoTheme.shapeExtraLarge

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: MeoTheme.space16
                spacing: MeoTheme.space8

                MeoText {
                    Layout.fillWidth: true
                    text: qsTr("Library")
                    typeRole: "label"
                    typeSize: "medium"
                    color: MeoTheme.contentOnSurfaceVariant
                }

                MeoButton {
                    Layout.fillWidth: true
                    text: qsTr("Installed apps")
                    icon.name: "inventory_2"
                    type: window.currentPage === 0 ? "tonal" : "text"
                    onClicked: window.currentPage = 0
                }

                MeoButton {
                    Layout.fillWidth: true
                    text: qsTr("Discover")
                    icon.name: "travel_explore"
                    type: window.currentPage === 1 ? "tonal" : "text"
                    onClicked: window.currentPage = 1
                }

                Item { Layout.fillHeight: true }

                MeoText {
                    Layout.fillWidth: true
                    text: qsTr("This preview shows information only. It cannot change software on your device.")
                    typeRole: "body"
                    typeSize: "small"
                    color: MeoTheme.contentOnSurfaceVariant
                    wrapMode: Text.WordWrap
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: window.currentPage

            LibraryPage {
                usageSummary: window.installedUsageSummary
                applicationModel: window.installedUsageModel
            }

            DiscoverUnavailablePage {}
        }
    }
}
