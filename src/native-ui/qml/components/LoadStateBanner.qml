pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import MeoUI

// Standard load-failure surfaces (MeoUI STORE_FEEDBACK.md section 4):
//  - offline with data on screen -> warning banner "showing what was saved"
//  - failed with data on screen  -> error banner with Retry
//  - failed with nothing to show -> full-page error state with Retry
ColumnLayout {
    id: root

    property bool hasData: false
    property string failureTitle: qsTr("Couldn't load this page.")
    signal retryRequested()

    readonly property bool failed: backend.errorMessage.length > 0 && !backend.busy
    readonly property bool offlineStale: failed && backend.offline && hasData
    readonly property bool plainFailure: failed && !offlineStale && hasData
    readonly property bool pageFailure: failed && !hasData

    spacing: 8 * MeoTheme.globalScale

    MeoBanner {
        Layout.fillWidth: true
        visible: root.offlineStale
        title: qsTr("You're offline. Showing what was saved.")
        text: backend.lastUpdated.length > 0 ? qsTr("Last updated %1.").arg(backend.lastUpdated) : ""
        icon: "cloud_off"
        tone: "warning"
    }

    MeoBanner {
        Layout.fillWidth: true
        visible: root.plainFailure
        title: root.failureTitle
        text: backend.errorMessage
        icon: "error"
        tone: "error"
    }

    MeoEmptyState {
        Layout.fillWidth: true
        visible: root.pageFailure
        icon: backend.offline ? "cloud_off" : "error"
        title: backend.offline ? qsTr("You're offline.") : root.failureTitle
        description: backend.errorMessage
    }

    RowLayout {
        visible: root.failed
        spacing: 8 * MeoTheme.globalScale
        MeoButton {
            text: qsTr("Retry")
            type: "tonal"
            icon.name: "refresh"
            onClicked: root.retryRequested()
        }
        MeoButton {
            text: qsTr("Start service")
            type: "text"
            icon.name: "play_arrow"
            onClicked: backend.startBackend()
        }
    }
}
