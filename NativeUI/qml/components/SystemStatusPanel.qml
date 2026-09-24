pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeoUI 1.0

ColumnLayout {
    id: root
    spacing: 12 * MeoTheme.globalScale

    function channelName() {
        const value = String((systemBridge.channelState || ({})).channel || "")
        if (value === "beta") return qsTr("Beta")
        if (value === "stable") return qsTr("Stable")
        if (value === "invalid") return qsTr("Invalid repository order")
        if (value === "unconfigured") return qsTr("Not configured")
        return qsTr("Unknown")
    }

    function updateCount() {
        const value = Number((systemBridge.updateState || ({})).count)
        return Number.isFinite(value) && value >= 0 ? value : 0
    }

    function environmentCounts() {
        const state = systemBridge.environmentState || ({})
        const keys = Object.keys(state)
        let ok = 0
        let attention = 0
        for (let index = 0; index < keys.length; ++index) {
            const item = state[keys[index]] || ({})
            if (String(item.status || "") === "ok")
                ++ok
            else
                ++attention
        }
        return { "known": keys.length, "ok": ok, "attention": attention }
    }

    function environmentSummary() {
        const counts = environmentCounts()
        if (counts.known === 0)
            return qsTr("Environment status has not been checked yet.")
        if (counts.attention === 0)
            return qsTr("%1 checks passed").arg(counts.ok)
        return qsTr("%1 passed · %2 need attention").arg(counts.ok).arg(counts.attention)
    }

    function downgradeItems() {
        const preview = systemBridge.stablePreview || ({})
        return Array.isArray(preview.downgrades) ? preview.downgrades : []
    }

    function stablePlanHash() {
        return String((systemBridge.stablePreview || ({})).planHash || "")
    }

    function validStablePlan() {
        return /^[0-9a-f]{64}$/.test(stablePlanHash())
    }

    Component.onCompleted: systemBridge.refreshAll()

    RowLayout {
        Layout.fillWidth: true
        spacing: 10 * MeoTheme.globalScale

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2 * MeoTheme.globalScale

            MeoText {
                text: qsTr("System and update channel")
                typeRole: "title"
                typeSize: "medium"
                emphasized: true
                color: MeoTheme.contentOnSurface
            }

            MeoText {
                Layout.fillWidth: true
                text: qsTr("Uses OmniStore's existing package-owned channel and update contracts. Channel changes may request administrator authentication.")
                typeRole: "body"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
                wrapMode: Text.WordWrap
            }
        }

        MeoIconButton {
            icon.name: "refresh"
            type: "tonal"
            Accessible.name: qsTr("Refresh system status")
            enabled: !systemBridge.busy
            onClicked: systemBridge.refreshAll()
        }
    }

    MeoProgressBar {
        Layout.fillWidth: true
        visible: systemBridge.busy
        indeterminate: true
    }

    MeoBanner {
        Layout.fillWidth: true
        visible: systemBridge.errorMessage.length > 0
        title: qsTr("System action failed")
        text: systemBridge.errorMessage
        icon: "error"
        tone: "error"
        actionText: qsTr("Dismiss")
        onActionTriggered: systemBridge.clearError()
    }

    GridLayout {
        Layout.fillWidth: true
        columns: width >= 820 * MeoTheme.globalScale ? 3 : 1
        columnSpacing: 10 * MeoTheme.globalScale
        rowSpacing: 10 * MeoTheme.globalScale

        MeoCard {
            Layout.fillWidth: true
            Layout.minimumHeight: 150 * MeoTheme.globalScale
            type: "filled"
            padding: 16 * MeoTheme.globalScale

            ColumnLayout {
                width: parent.width
                spacing: 6 * MeoTheme.globalScale

                MeoIcon {
                    icon: "experiment"
                    size: 26 * MeoTheme.globalScale
                    color: MeoTheme.primary
                }
                MeoText {
                    text: qsTr("Meo channel")
                    typeRole: "label"
                    typeSize: "medium"
                    color: MeoTheme.contentOnSurfaceVariant
                }
                MeoText {
                    Layout.fillWidth: true
                    text: root.channelName()
                    typeRole: "title"
                    typeSize: "medium"
                    emphasized: true
                    color: MeoTheme.contentOnSurface
                    elide: Text.ElideRight
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8 * MeoTheme.globalScale

                    MeoButton {
                        visible: String((systemBridge.channelState || ({})).channel || "") !== "beta"
                        text: qsTr("Switch to Beta")
                        type: "tonal"
                        icon.name: "science"
                        enabled: !systemBridge.busy
                        onClicked: betaDialog.open()
                    }
                    MeoButton {
                        visible: String((systemBridge.channelState || ({})).channel || "") !== "stable"
                        text: qsTr("Switch to Stable")
                        type: "tonal"
                        icon.name: "verified"
                        enabled: !systemBridge.busy
                        onClicked: stableDialog.open()
                    }
                }
            }
        }

        MeoCard {
            Layout.fillWidth: true
            Layout.minimumHeight: 150 * MeoTheme.globalScale
            type: "filled"
            padding: 16 * MeoTheme.globalScale

            ColumnLayout {
                width: parent.width
                spacing: 6 * MeoTheme.globalScale

                MeoIcon {
                    icon: root.updateCount() > 0 ? "system_update" : "check_circle"
                    size: 26 * MeoTheme.globalScale
                    color: MeoTheme.primary
                }
                MeoText {
                    text: qsTr("Update state")
                    typeRole: "label"
                    typeSize: "medium"
                    color: MeoTheme.contentOnSurfaceVariant
                }
                MeoText {
                    text: root.updateCount() === 1
                          ? qsTr("1 update")
                          : qsTr("%1 updates").arg(root.updateCount())
                    typeRole: "title"
                    typeSize: "medium"
                    emphasized: true
                    color: MeoTheme.contentOnSurface
                }
                MeoText {
                    Layout.fillWidth: true
                    text: String((systemBridge.updateState || ({})).checked_at || "").length > 0
                          ? qsTr("Last checked: %1").arg(String(systemBridge.updateState.checked_at))
                          : qsTr("No saved update check timestamp")
                    typeRole: "body"
                    typeSize: "small"
                    color: MeoTheme.contentOnSurfaceVariant
                    wrapMode: Text.WordWrap
                }
            }
        }

        MeoCard {
            Layout.fillWidth: true
            Layout.minimumHeight: 150 * MeoTheme.globalScale
            type: "filled"
            padding: 16 * MeoTheme.globalScale

            ColumnLayout {
                width: parent.width
                spacing: 6 * MeoTheme.globalScale

                MeoIcon {
                    icon: root.environmentCounts().attention > 0 ? "warning" : "health_and_safety"
                    size: 26 * MeoTheme.globalScale
                    color: MeoTheme.primary
                }
                MeoText {
                    text: qsTr("Environment")
                    typeRole: "label"
                    typeSize: "medium"
                    color: MeoTheme.contentOnSurfaceVariant
                }
                MeoText {
                    Layout.fillWidth: true
                    text: root.environmentSummary()
                    typeRole: "title"
                    typeSize: "small"
                    emphasized: true
                    color: MeoTheme.contentOnSurface
                    wrapMode: Text.WordWrap
                }

                Item { Layout.fillHeight: true }

                MeoButton {
                    visible: root.environmentCounts().attention > 0
                             && String(((systemBridge.environmentState || ({})).is_arch || ({})).status || "") === "ok"
                    text: qsTr("Repair environment")
                    type: "text"
                    icon.name: "build"
                    enabled: !systemBridge.busy
                    onClicked: bootstrapDialog.open()
                }
            }
        }
    }

    MeoCard {
        Layout.fillWidth: true
        visible: root.downgradeItems().length > 0
        type: "filled"
        padding: 18 * MeoTheme.globalScale

        ColumnLayout {
            width: parent.width
            spacing: 10 * MeoTheme.globalScale

            RowLayout {
                Layout.fillWidth: true
                MeoIcon {
                    icon: "fact_check"
                    size: 24 * MeoTheme.globalScale
                    color: MeoTheme.primary
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2 * MeoTheme.globalScale
                    MeoText {
                        text: qsTr("Review Stable rollback")
                        typeRole: "title"
                        typeSize: "small"
                        emphasized: true
                        color: MeoTheme.contentOnSurface
                    }
                    MeoText {
                        Layout.fillWidth: true
                        text: qsTr("%1 Meo package(s) would be downgraded. Review the package list before applying the signed plan.").arg(root.downgradeItems().length)
                        typeRole: "body"
                        typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                        wrapMode: Text.WordWrap
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4 * MeoTheme.globalScale

                Repeater {
                    model: root.downgradeItems().slice(0, 8)
                    delegate: MeoListItem {
                        id: downgradeRow
                        required property var modelData
                        Layout.fillWidth: true
                        headline: String(downgradeRow.modelData.name || qsTr("Meo package"))
                        supportingText: qsTr("%1 → %2")
                                        .arg(String(downgradeRow.modelData.installed || downgradeRow.modelData.current || ""))
                                        .arg(String(downgradeRow.modelData.stable || downgradeRow.modelData.target || ""))
                        leadingIcon: "package_2"
                        isDense: true
                        isSegmented: true
                        roundingStrategy: "all"
                    }
                }

                MeoText {
                    visible: root.downgradeItems().length > 8
                    text: qsTr("…and %1 more").arg(root.downgradeItems().length - 8)
                    typeRole: "label"
                    typeSize: "small"
                    color: MeoTheme.contentOnSurfaceVariant
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                MeoButton {
                    text: qsTr("Cancel")
                    type: "text"
                    enabled: !systemBridge.busy
                    onClicked: systemBridge.clearStablePreview()
                }
                MeoButton {
                    text: qsTr("Apply reviewed plan")
                    type: "filled"
                    icon.name: "verified"
                    enabled: !systemBridge.busy && root.validStablePlan()
                    onClicked: stableApplyDialog.open()
                }
            }
        }
    }

    MeoDialog {
        id: betaDialog
        parent: Overlay.overlay
        title: qsTr("Switch to Meo Beta?")
        message: qsTr("OmniStore will install the package-owned Beta channel configuration and run a normal system upgrade. This can request administrator authentication.")
        icon: "science"
        confirmText: qsTr("Switch to Beta")
        cancelText: qsTr("Cancel")
        onConfirmed: systemBridge.switchBeta()
    }

    MeoDialog {
        id: stableDialog
        parent: Overlay.overlay
        title: qsTr("Switch to Meo Stable?")
        message: qsTr("OmniStore will install the Stable channel configuration and refresh repository metadata. If Meo packages need downgrades, you will be shown a signed rollback plan before anything is downgraded.")
        icon: "verified"
        confirmText: qsTr("Review Stable")
        cancelText: qsTr("Cancel")
        onConfirmed: systemBridge.switchStable()
    }

    MeoDialog {
        id: stableApplyDialog
        parent: Overlay.overlay
        title: qsTr("Apply Stable rollback?")
        message: qsTr("Apply the exact reviewed plan for %1 package(s). OmniStore verifies the plan hash again before the privileged helper can commit it.").arg(root.downgradeItems().length)
        icon: "fact_check"
        confirmText: qsTr("Apply")
        cancelText: qsTr("Cancel")
        onConfirmed: systemBridge.confirmStable(root.stablePlanHash())
    }

    MeoDialog {
        id: bootstrapDialog
        parent: Overlay.overlay
        title: qsTr("Repair OmniStore environment?")
        message: qsTr("Install missing OmniStore build and integration dependencies using the existing environment bootstrap. This can request administrator authentication and may build the AUR helper if it is missing.")
        icon: "build"
        confirmText: qsTr("Repair")
        cancelText: qsTr("Cancel")
        onConfirmed: systemBridge.bootstrapEnvironment()
    }
}
