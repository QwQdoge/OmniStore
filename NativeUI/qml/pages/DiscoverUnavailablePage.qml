import QtQuick
import MeoUI 1.0

Item {
    id: control
    objectName: "nativeDiscoverUnavailablePage"
    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Discover")
    Accessible.description: qsTr("Catalog browsing will be available when the supported catalog connection is ready.")

    MeoCard {
        anchors.fill: parent
        type: "filled"
        radius: MeoTheme.shapeExtraLarge

        MeoEmptyState {
            anchors.fill: parent
            icon: "travel_explore"
            title: qsTr("Discover is not ready yet")
            description: qsTr("Catalog browsing will appear here when its supported connection is ready. This preview will not use an unsupported search or install path.")
        }
    }
}
