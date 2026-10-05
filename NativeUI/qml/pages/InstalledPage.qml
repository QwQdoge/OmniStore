pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import MeoUI 1.0

Item {
    id: root
    signal detailsRequested(var app)

    Component.onCompleted: {
        if (backend.installedApps.length === 0)
            backend.loadInstalled(false)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28 * MeoTheme.globalScale
        spacing: 14 * MeoTheme.globalScale

        RowLayout {
            Layout.fillWidth: true
            PageHeading {
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

            delegate: AppRow {
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
