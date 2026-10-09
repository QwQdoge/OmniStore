pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import MeoUI 1.0

MeoCard {
    id: root

    required property var plan
    property bool planning: false
    property string errorMessage: ""

    signal confirmRequested()
    signal cancelRequested()

    readonly property bool hasPlan: String((plan || {}).planHash || "").length > 0
    readonly property var requestData: hasPlan && plan.request ? plan.request : ({})
    readonly property var packageData: hasPlan && plan.package ? plan.package : ({})
    readonly property var sourceData: hasPlan && plan.source ? plan.source : ({})
    readonly property bool canApply: hasPlan && !!plan.canApply

    Layout.fillWidth: true
    visible: planning || hasPlan
    type: "outlined"
    padding: 18 * MeoTheme.globalScale

    function textOrUnknown(value) {
        const text = String(value || "").trim()
        return text.length > 0 ? text : qsTr("Unknown")
    }

    function trustLabel() {
        const trust = String(sourceData.trust || "")
        if (trust === "trusted")
            return qsTr("Trusted source")
        if (trust === "review-required")
            return qsTr("Review required")
        return qsTr("Untrusted source")
    }

    function trustIcon() {
        const trust = String(sourceData.trust || "")
        if (trust === "trusted")
            return "verified_user"
        if (trust === "review-required")
            return "warning"
        return "gpp_maybe"
    }

    function warningText() {
        if (!hasPlan)
            return ""
        if (!sourceData.available)
            return qsTr("This source is not available on the current system.")
        if (!sourceData.enabled)
            return qsTr("This source is disabled. Enable it in OmniStore Settings before installing.")
        const capabilities = sourceData.capabilities || []
        if (capabilities.indexOf("install") < 0)
            return qsTr("This source does not expose an install capability.")
        if (sourceData.requiresReview)
            return qsTr("This source requires extra review. Check the package source and build information before continuing.")
        if (!sourceData.trusted)
            return qsTr("This source is not marked as trusted by OmniStore.")
        return ""
    }

    function dependencyText() {
        const dependencies = packageData.dependencies || []
        if (dependencies.length === 0)
            return qsTr("The backend did not report dependency details. The package manager will resolve the final dependency set during installation.")
        const shown = []
        const limit = Math.min(dependencies.length, 8)
        for (let index = 0; index < limit; ++index)
            shown.push(String(dependencies[index]))
        let text = shown.join(", ")
        if (dependencies.length > limit)
            text += qsTr(" and %1 more").arg(dependencies.length - limit)
        return text
    }

    ColumnLayout {
        width: parent.width
        spacing: 14 * MeoTheme.globalScale

        RowLayout {
            Layout.fillWidth: true
            spacing: 10 * MeoTheme.globalScale

            MeoShape {
                Layout.preferredWidth: 46 * MeoTheme.globalScale
                Layout.preferredHeight: 46 * MeoTheme.globalScale
                type: "squircle"
                radius: 15 * MeoTheme.globalScale
                color: MeoTheme.primaryContainer
                MeoIcon {
                    anchors.centerIn: parent
                    icon: root.planning ? "hourglass_top" : root.trustIcon()
                    size: 24 * MeoTheme.globalScale
                    color: MeoTheme.contentOnPrimaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2 * MeoTheme.globalScale
                MeoText {
                    text: root.planning ? qsTr("Preparing installation plan") : qsTr("Review installation")
                    typeRole: "title"
                    typeSize: "small"
                    emphasized: true
                    color: MeoTheme.contentOnSurface
                }
                MeoText {
                    visible: !root.planning && root.hasPlan
                    text: root.trustLabel()
                    typeRole: "label"
                    typeSize: "small"
                    color: String(root.sourceData.trust || "") === "trusted"
                           ? MeoTheme.primary : MeoTheme.contentOnSurfaceVariant
                }
            }

            MeoButton {
                visible: !root.planning && root.hasPlan
                text: qsTr("Cancel")
                type: "text"
                onClicked: root.cancelRequested()
            }
        }

        MeoProgressBar {
            Layout.fillWidth: true
            visible: root.planning
            indeterminate: true
        }

        GridLayout {
            Layout.fillWidth: true
            visible: root.hasPlan && !root.planning
            columns: width >= 460 * MeoTheme.globalScale ? 2 : 1
            columnSpacing: 10 * MeoTheme.globalScale
            rowSpacing: 10 * MeoTheme.globalScale

            MeoCard {
                Layout.fillWidth: true
                type: "filled"
                compact: true
                padding: 12 * MeoTheme.globalScale
                ColumnLayout {
                    width: parent.width
                    spacing: 2 * MeoTheme.globalScale
                    MeoText { text: qsTr("Source"); typeRole: "label"; typeSize: "small"; color: MeoTheme.contentOnSurfaceVariant }
                    MeoText { Layout.fillWidth: true; text: root.textOrUnknown(root.sourceData.name); typeRole: "title"; typeSize: "small"; emphasized: true; color: MeoTheme.contentOnSurface; elide: Text.ElideRight }
                }
            }

            MeoCard {
                Layout.fillWidth: true
                type: "filled"
                compact: true
                padding: 12 * MeoTheme.globalScale
                ColumnLayout {
                    width: parent.width
                    spacing: 2 * MeoTheme.globalScale
                    MeoText { text: qsTr("Version"); typeRole: "label"; typeSize: "small"; color: MeoTheme.contentOnSurfaceVariant }
                    MeoText { Layout.fillWidth: true; text: root.textOrUnknown(root.packageData.version); typeRole: "title"; typeSize: "small"; emphasized: true; color: MeoTheme.contentOnSurface; elide: Text.ElideRight }
                }
            }

            MeoCard {
                Layout.fillWidth: true
                type: "filled"
                compact: true
                padding: 12 * MeoTheme.globalScale
                ColumnLayout {
                    width: parent.width
                    spacing: 2 * MeoTheme.globalScale
                    MeoText { text: qsTr("Download"); typeRole: "label"; typeSize: "small"; color: MeoTheme.contentOnSurfaceVariant }
                    MeoText { Layout.fillWidth: true; text: root.textOrUnknown(root.packageData.downloadSize); typeRole: "title"; typeSize: "small"; emphasized: true; color: MeoTheme.contentOnSurface; elide: Text.ElideRight }
                }
            }

            MeoCard {
                Layout.fillWidth: true
                type: "filled"
                compact: true
                padding: 12 * MeoTheme.globalScale
                ColumnLayout {
                    width: parent.width
                    spacing: 2 * MeoTheme.globalScale
                    MeoText { text: qsTr("Installed size"); typeRole: "label"; typeSize: "small"; color: MeoTheme.contentOnSurfaceVariant }
                    MeoText { Layout.fillWidth: true; text: root.textOrUnknown(root.packageData.installedSize); typeRole: "title"; typeSize: "small"; emphasized: true; color: MeoTheme.contentOnSurface; elide: Text.ElideRight }
                }
            }
        }

        MeoBanner {
            Layout.fillWidth: true
            visible: !root.planning && root.warningText().length > 0
            title: root.canApply ? qsTr("Review source") : qsTr("Cannot install yet")
            text: root.warningText()
            icon: root.canApply ? "warning" : "block"
            tone: root.canApply ? "warning" : "error"
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.hasPlan && !root.planning
            spacing: 4 * MeoTheme.globalScale

            MeoText {
                text: qsTr("Dependencies")
                typeRole: "label"
                typeSize: "small"
                emphasized: true
                color: MeoTheme.contentOnSurfaceVariant
            }
            MeoText {
                Layout.fillWidth: true
                text: root.dependencyText()
                typeRole: "body"
                typeSize: "small"
                color: MeoTheme.contentOnSurface
                wrapMode: Text.WordWrap
            }
            MeoText {
                Layout.fillWidth: true
                text: root.plan.requiresPrivilege
                      ? qsTr("Administrator authentication may be requested by the package backend.")
                      : qsTr("This plan does not currently report a system-package privilege requirement.")
                typeRole: "body"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
                wrapMode: Text.WordWrap
            }
        }

        MeoButton {
            Layout.fillWidth: true
            visible: root.hasPlan && !root.planning
            text: qsTr("Install")
            type: "filled"
            icon.name: "download"
            enabled: root.canApply
            onClicked: root.confirmRequested()
        }
    }
}
