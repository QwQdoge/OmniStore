pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import MeoUI

// Loading placeholder for a list of app rows whose layout is known
// (MeoUI STORE_FEEDBACK.md section 3). Shows immediately, no flash delay.
Item {
    id: root

    property bool active: false
    property int rows: 5
    property string accessibleName: qsTr("Loading apps")
    readonly property real rowHeight: 64 * MeoTheme.globalScale

    visible: active || feedback.visible
    implicitHeight: rows * rowHeight

    MeoLoadingFeedback {
        id: feedback
        anchors.fill: parent
        active: root.active
        accessibleName: root.accessibleName
        placeholder: Component {
            Column {
                spacing: 0
                Repeater {
                    model: root.rows
                    delegate: Row {
                        required property int index
                        width: root.width
                        height: root.rowHeight
                        spacing: 14 * MeoTheme.globalScale
                        leftPadding: 4 * MeoTheme.globalScale
                        MeoSkeleton {
                            type: "card"
                            width: 48 * MeoTheme.globalScale
                            height: 48 * MeoTheme.globalScale
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8 * MeoTheme.globalScale
                            MeoSkeleton { type: "text"; width: (150 + (index % 3) * 40) * MeoTheme.globalScale; height: 14 * MeoTheme.globalScale }
                            MeoSkeleton { type: "text"; width: 100 * MeoTheme.globalScale; height: 11 * MeoTheme.globalScale }
                        }
                    }
                }
            }
        }
    }
}
