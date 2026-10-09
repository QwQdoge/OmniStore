pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import MeoUI 1.0
import OmniStore.Native 1.0 as Store

Item {
    id: root
    signal detailsRequested(var app)
    readonly property bool usageAvailable: backend.installedUsage.schema === "org.meo.omnistore.installed-usage"

    function formatBytes(bytes) {
        const units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"]
        let value = Number(bytes)
        let unit = 0
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024
            ++unit
        }
        return value.toLocaleString(Qt.locale(), "f", unit === 0 ? 0 : 1) + " " + units[unit]
    }

    Component.onCompleted: {
        if (backend.installedApps.length === 0)
            backend.loadInstalled(false)
        else
            backend.loadInstalledUsage()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28 * MeoTheme.globalScale
        spacing: 14 * MeoTheme.globalScale

        RowLayout {
            Layout.fillWidth: true
            Store.PageHeading {
                Layout.fillWidth: true
                title: qsTr("Installed")
                subtitle: qsTr("Apps detected through the enabled sources. Uninstall and launch actions still use the existing OmniStore backend.")
                icon: "apps"
            }
            MeoButton {
                text: qsTr("Rescan")
                type: "tonal"
                icon.name: "refresh"
                enabled: !backend.busy
                onClicked: backend.loadInstalled(true)
            }
        }

        MeoProgressBar {
            Layout.fillWidth: true
            visible: backend.busyAction === qsTr("installed apps")
            indeterminate: true
        }

        MeoCard {
            Layout.fillWidth: true
            type: "filled"
            padding: 16 * MeoTheme.globalScale
            Accessible.role: Accessible.Pane
            Accessible.name: qsTr("Installed app usage")

            ColumnLayout {
                width: parent.width
                spacing: 4 * MeoTheme.globalScale
                MeoText {
                    Layout.fillWidth: true
                    text: root.usageAvailable
                        ? qsTr("%1 installed apps · %2 known size · %3 sources")
                            .arg(backend.installedUsage.applicationCount)
                            .arg(root.formatBytes(backend.installedUsage.knownSizeBytes))
                            .arg(backend.installedUsage.sources.length)
                        : (backend.busy ? qsTr("Loading installed app usage…") : qsTr("Usage information is unavailable"))
                    typeRole: "title"
                    typeSize: "small"
                    wrapMode: Text.WordWrap
                }
                MeoText {
                    Layout.fillWidth: true
                    visible: root.usageAvailable
                    text: qsTr("Source-reported app sizes; %1 apps have no size metadata.")
                        .arg(backend.installedUsage.unknownSizeCount || 0)
                    typeRole: "body"
                    typeSize: "small"
                    color: MeoTheme.contentOnSurfaceVariant
                    wrapMode: Text.WordWrap
                }
            }
        }

        MeoBanner {
            Layout.fillWidth: true
            visible: backend.errorMessage.length > 0 && !backend.busy
            title: qsTr("Installed apps could not be refreshed")
            text: backend.errorMessage
            icon: "error"
            tone: "error"
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: backend.installedApps.length > 0
            clip: true
            spacing: 8 * MeoTheme.globalScale
            model: backend.installedApps
            boundsBehavior: Flickable.StopAtBounds

            delegate: Store.AppRow {
                required property var modelData
                width: ListView.view.width
                app: modelData
                installedContext: true
                onDetailsRequested: function(app) { root.detailsRequested(app) }
            }
        }

        MeoEmptyState {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: backend.installedApps.length === 0 && !backend.busy
            icon: "inventory_2"
            title: qsTr("No managed apps found")
            description: qsTr("Refresh after enabling a source, or install an app from Search.")
        }
    }
}
