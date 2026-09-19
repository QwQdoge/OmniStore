import QtQuick
import QtQuick.Layouts
import MeoUI 1.0

Item {
    id: control
    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Installed library")
    Accessible.description: qsTr("A local, read-only overview of installed applications.")

    property var usageSummary: ({})
    property var applicationModel: null
    readonly property bool hasAvailableUsage: Boolean(usageSummary && usageSummary.available)
    readonly property int applicationCount: usageSummary && usageSummary.applicationCount
                                           ? usageSummary.applicationCount : 0

    ColumnLayout {
        anchors.fill: parent
        spacing: MeoTheme.space16

        ColumnLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space4

            MeoText {
                text: qsTr("Installed library")
                typeRole: "title"
                typeSize: "large"
                emphasized: true
            }

            MeoText {
                text: qsTr("See installed apps and their storage use. This preview cannot change software on your device.")
                typeRole: "body"
                typeSize: "medium"
                color: MeoTheme.contentOnSurfaceVariant
                wrapMode: Text.WordWrap
            }
        }

        MeoCard {
            id: summarySurface
            objectName: "nativeLibraryReadOnlySummary"
            Layout.fillWidth: true
            Layout.preferredHeight: 120 * MeoTheme.globalScale
            type: "filled"
            radius: MeoTheme.shapeExtraLarge
            Accessible.role: Accessible.Pane
            Accessible.name: control.hasAvailableUsage
                             ? qsTr("%1 installed apps").arg(control.applicationCount)
                             : qsTr("Library information is not available yet")
            Accessible.description: control.hasAvailableUsage
                                    ? qsTr("%1 known storage · %2 sources")
                                          .arg(control.usageSummary.knownSizeText)
                                          .arg(control.usageSummary.sourceCount)
                                    : qsTr("The local library source is not ready. Try again when it is available.")

            RowLayout {
                anchors.fill: parent
                anchors.margins: MeoTheme.space16
                spacing: MeoTheme.space16

                MeoIcon {
                    icon: control.hasAvailableUsage ? "inventory_2" : "cloud_off"
                    size: 36 * MeoTheme.globalScale
                    color: control.hasAvailableUsage ? MeoTheme.primary
                                                        : MeoTheme.contentOnSurfaceVariant
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: MeoTheme.space4

                    MeoText {
                        Layout.fillWidth: true
                        text: control.hasAvailableUsage
                              ? qsTr("%1 installed apps").arg(control.applicationCount)
                              : qsTr("Library information is not available yet")
                        typeRole: "title"
                        typeSize: "medium"
                        emphasized: true
                        elide: Text.ElideRight
                    }

                    MeoText {
                        Layout.fillWidth: true
                        text: control.hasAvailableUsage
                              ? qsTr("%1 known storage · %2 sources")
                                    .arg(control.usageSummary.knownSizeText)
                                    .arg(control.usageSummary.sourceCount)
                              : qsTr("The local library source is not ready. Try again when it is available.")
                        typeRole: "body"
                        typeSize: "medium"
                        color: MeoTheme.contentOnSurfaceVariant
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
            }
        }

        MeoText {
            Layout.fillWidth: true
            visible: control.hasAvailableUsage && control.applicationCount > 0
            text: qsTr("Applications")
            typeRole: "title"
            typeSize: "small"
            emphasized: true
        }

        ListView {
            id: applicationList
            Layout.fillWidth: true
            Layout.fillHeight: visible
            visible: control.hasAvailableUsage && control.applicationCount > 0
            clip: true
            spacing: MeoTheme.space4
            model: control.applicationModel
            Accessible.role: Accessible.List
            Accessible.name: qsTr("Installed applications")

            delegate: MeoListItem {
                required property int index
                required property string name
                required property string sourceName
                required property string sizeText

                width: ListView.view ? ListView.view.width : 0
                headline: name
                supportingText: qsTr("%1 · %2").arg(sourceName).arg(sizeText)
                leadingIcon: "apps"
                interactive: false
                showDivider: index < (ListView.view ? ListView.view.count : 0) - 1
                dividerInset: 56 * MeoTheme.globalScale
            }
        }

        MeoEmptyState {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !control.hasAvailableUsage || control.applicationCount === 0
            icon: control.hasAvailableUsage ? "inventory_2" : "info"
            title: control.hasAvailableUsage
                   ? qsTr("No installed applications were reported")
                   : qsTr("Library information is not ready")
            description: control.hasAvailableUsage
                         ? qsTr("The exporter completed, but it reported no applications.")
                         : qsTr("This preview only reads the supported local library source. It does not use package commands as a fallback.")
        }
    }
}
