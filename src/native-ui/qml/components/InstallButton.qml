pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import MeoUI

// The single primary action of a store item (MeoUI STORE_FEEDBACK.md section 2).
// One slot with a fixed width so the layout never shifts between states.
RowLayout {
    id: root

    property string appName: ""
    property bool installed: false
    // False while something unrelated blocks new work (service missing, no identity).
    property bool ready: true
    // Rows that only exist because an update is pending (the Updates page).
    property bool forceUpdate: false

    signal installRequested()
    signal updateRequested()

    readonly property bool mine: appName.length > 0
                                 && String(transactions.taskName).toLowerCase() === appName.toLowerCase()
    readonly property bool updateAvailable: {
        const list = backend.updates || []
        const wanted = appName.toLowerCase()
        for (let i = 0; i < list.length; ++i) {
            const item = list[i] || ({})
            if (String(item.name || item.id || "").toLowerCase() === wanted)
                return true
        }
        return false
    }
    readonly property bool working: mine && transactions.status === "running"
    readonly property bool queued: mine && transactions.status === "queued"
    readonly property bool failed: mine && transactions.status === "failed"
    readonly property bool needsAuth: mine && transactions.busy && transactions.authenticationPrompt.length > 0
    // "Open" is a different control (the installed row); this one then steps aside.
    readonly property string state: {
        if (transactions.planning) return "planning"
        if (needsAuth) return "auth"
        if (queued) return "queued"
        if (working) return "working"
        if (failed) return "failed"
        if (installed && (updateAvailable || forceUpdate)) return "update"
        if (installed) return "open"
        return "install"
    }
    readonly property bool showsFailure: state === "failed"

    function verb(progressive) {
        const kind = String(transactions.taskKind)
        if (kind === "remove") return progressive ? qsTr("Removing") : qsTr("Remove")
        if (kind === "update" || kind === "update_all") return progressive ? qsTr("Updating") : qsTr("Update")
        return progressive ? qsTr("Installing") : qsTr("Install")
    }
    readonly property string label: {
        switch (state) {
        case "planning": return qsTr("Preparing…")
        case "auth": return qsTr("Authorize…")
        case "queued": return qsTr("Queued")
        case "working":
            return transactions.progress >= 0
                ? qsTr("%1 %2%").arg(verb(true)).arg(Math.round(transactions.progress * 100))
                : qsTr("%1…").arg(verb(true))
        case "failed": return qsTr("Retry")
        case "update": return qsTr("Update")
        default: return qsTr("Install")
        }
    }

    visible: state !== "open"
    spacing: 10 * MeoTheme.globalScale

    // Reserve the width of the longest label (translations change it).
    TextMetrics { id: m1; text: qsTr("Installing 100%") }
    TextMetrics { id: m2; text: qsTr("Authorize…") }
    TextMetrics { id: m3; text: qsTr("Preparing…") }
    readonly property real slotWidth: Math.max(m1.width, m2.width, m3.width) + 72 * MeoTheme.globalScale

    MeoButton {
        id: button
        objectName: "installButtonControl"
        Layout.preferredWidth: root.slotWidth
        Layout.fillWidth: true
        text: root.label
        type: root.state === "queued" ? "tonal" : (root.state === "failed" ? "outlined" : "filled")
        icon.name: root.state === "failed" ? "refresh" : (root.state === "update" ? "upgrade" : "download")
        loading: root.state === "planning" || root.state === "working"
        enabled: root.ready && !backend.busy && (root.state === "install" || root.state === "failed" || root.state === "update")
                 && !transactions.busy && transactions.available
        Accessible.name: root.mine && root.state !== "install"
                         ? qsTr("%1, %2").arg(root.appName).arg(root.label) : root.label
        onClicked: root.state === "update" ? root.updateRequested() : root.installRequested()
    }

    // Failure stays visible next to Retry with its reason (section 4).
    MeoText {
        visible: root.failed && transactions.errorMessage.length > 0
        Layout.fillWidth: true
        text: transactions.errorMessage
        typeRole: "body"
        typeSize: "small"
        color: MeoTheme.error
        wrapMode: Text.WordWrap
    }

    // Another change holds the lock: say so instead of a dead button.
    MeoText {
        visible: !root.mine && transactions.busy && root.state === "install"
        Layout.fillWidth: true
        text: qsTr("Waiting for another change to finish.")
        typeRole: "body"
        typeSize: "small"
        color: MeoTheme.contentOnSurfaceVariant
        wrapMode: Text.WordWrap
    }
}
