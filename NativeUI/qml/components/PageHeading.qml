import QtQuick
import QtQuick.Layouts
import MeoUI 1.0

ColumnLayout {
    id: root
    property string title: ""
    property string subtitle: ""
    property string icon: ""
    spacing: 4 * MeoTheme.globalScale

    RowLayout {
        Layout.fillWidth: true
        spacing: 12 * MeoTheme.globalScale

        MeoIcon {
            visible: root.icon.length > 0
            icon: root.icon
            size: 32 * MeoTheme.globalScale
            color: MeoTheme.primary
        }
        MeoText {
            Layout.fillWidth: true
            text: root.title
            typeRole: "headline"
            typeSize: "medium"
            emphasized: true
            color: MeoTheme.contentOnSurface
            wrapMode: Text.WordWrap
        }
    }

    MeoText {
        Layout.fillWidth: true
        visible: root.subtitle.length > 0
        text: root.subtitle
        typeRole: "body"
        typeSize: "medium"
        color: MeoTheme.contentOnSurfaceVariant
        wrapMode: Text.WordWrap
    }
}
