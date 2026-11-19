pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import MeoUI

// Marks a source that is not part of the reviewed system set (STORE_FEEDBACK.md
// section 1, "Source and trust"): tertiary tone with an icon and text, never
// color alone. MeoBadge is a notification-count control and has no tone, so
// this small store-specific label lives in the product.
Item {
    id: root

    property string source: ""

    readonly property var plugin: {
        const list = backend.plugins || []
        const wanted = String(source).toLowerCase()
        for (let i = 0; i < list.length; ++i) {
            const p = list[i] || ({})
            if (String(p.name || "").toLowerCase() === wanted)
                return p
        }
        return null
    }
    readonly property string kind: {
        if (!plugin) return ""
        if (plugin.experimental) return "experimental"
        if (plugin.type === "catalog") return "thirdparty"
        if (plugin.requires_review || !plugin.trusted) return "community"
        return ""
    }
    readonly property string label: kind === "experimental" ? qsTr("Experimental")
                                  : kind === "thirdparty" ? qsTr("Third-party")
                                  : kind === "community" ? qsTr("Community") : ""
    readonly property string iconName: kind === "experimental" ? "science"
                                     : kind === "thirdparty" ? "link" : "groups"

    visible: label.length > 0
    implicitWidth: visible ? row.implicitWidth + 16 * MeoTheme.globalScale : 0
    implicitHeight: visible ? 22 * MeoTheme.globalScale : 0
    Accessible.role: Accessible.StaticText
    Accessible.name: qsTr("%1 source").arg(label)

    MeoShape {
        anchors.fill: parent
        type: "round"
        radius: height / 2
        color: MeoTheme.tertiaryContainer
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4 * MeoTheme.globalScale
        MeoIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: root.iconName
            size: 14 * MeoTheme.globalScale
            color: MeoTheme.contentOnTertiaryContainer
        }
        MeoText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            typeRole: "label"
            typeSize: "small"
            color: MeoTheme.contentOnTertiaryContainer
        }
    }
}
