pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import MeoUI 1.0

Flickable {
    id: root
    property string requestMode: "daily"
    property string query: ""
    property var candidates: []
    property bool showPayload: false
    signal detailsRequested(var app)
    clip: true
    contentWidth: width
    contentHeight: column.implicitHeight + 32 * MeoTheme.globalScale
    ColumnLayout {
        id: column
        width: parent.width - 32 * MeoTheme.globalScale
        x: 16 * MeoTheme.globalScale
        spacing: 12 * MeoTheme.globalScale
        MeoText {
            Layout.fillWidth: true
            text: qsTr("Uses the system AI connections saved in Meo Settings. OmniStore never receives your API key. Review what will be sent before each request.")
            typeRole: "body"; typeSize: "medium"; wrapMode: Text.WordWrap
        }
        MeoButton {
            text: qsTr("Refresh system AI connections")
            icon.name: "refresh"; type: "tonal"
            enabled: !accountAi.busy && !accountAi.consent.requestId
            onClicked: accountAi.refreshConnections()
        }
        Repeater {
            model: accountAi.connections
            delegate: MeoListItem {
                required property var modelData
                Layout.fillWidth: true
                headline: String(modelData.displayName || modelData.provider || "AI")
                supportingText: String(modelData.defaultModel || "")
                overline: String(modelData.endpoint || "")
                leadingIcon: "auto_awesome"
                interactive: true
                selected: accountAi.connectionId === String(modelData.id || "")
                enabled: !accountAi.busy && !accountAi.consent.requestId
                onClicked: accountAi.connectionId = String(modelData.id || "")
            }
        }
        MeoBanner {
            Layout.fillWidth: true
            visible: accountAi.errorMessage.length > 0
            title: qsTr("System AI unavailable")
            text: accountAi.errorMessage; tone: "warning"; icon: "info"
        }
        MeoBanner {
            Layout.fillWidth: true
            visible: accountAi.rememberedConsent
            title: qsTr("AI catalog advice is always allowed")
            text: qsTr("Applies only to this connection and model, for OmniStore searches, recommendations and package analysis. Package changes still require confirmation.")
            tone: "info"; icon: "verified_user"
        }
        MeoButton {
            visible: accountAi.rememberedConsent
            text: qsTr("Revoke saved AI permission")
            type: "outlined"
            enabled: !accountAi.busy && !accountAi.consent.requestId
            onClicked: accountAi.revokeRememberedConsent()
        }
        MeoButton {
            Layout.fillWidth: true
            text: accountAi.rememberedConsent ? qsTr("Ask AI") : qsTr("Prepare AI request")
            icon.name: "auto_awesome"
            enabled: accountAi.connectionId.length > 0 && !accountAi.busy && !accountAi.consent.requestId
            onClicked: accountAi.prepare(root.requestMode, root.query, root.candidates)
        }
        MeoProgressBar { Layout.fillWidth: true; visible: accountAi.busy; indeterminate: true }
        MeoCard {
            Layout.fillWidth: true
            visible: !!accountAi.consent.requestId
            type: "outlined"
            ColumnLayout {
                width: parent.width
                MeoText {
                    Layout.fillWidth: true
                    text: qsTr("Allow this AI request?")
                    typeRole: "title"; typeSize: "medium"
                }
                MeoText {
                    Layout.fillWidth: true
                    text: String(accountAi.consent.providerName || "") + "\n"
                          + String(accountAi.consent.destination || "") + "\n"
                          + String(accountAi.consent.model || "") + "\n"
                          + qsTr("Software search, recommendations and package analysis") + "\n"
                          + qsTr("Your request and package metadata") + " · "
                          + qsTr("%1 characters").arg(accountAi.consent.promptCharacters || 0)
                    typeRole: "body"; typeSize: "small"; wrapMode: Text.WrapAnywhere
                }
                MeoButton {
                    text: root.showPayload ? qsTr("Hide request contents") : qsTr("Show request contents")
                    type: "text"
                    onClicked: root.showPayload = !root.showPayload
                }
                MeoText {
                    Layout.fillWidth: true
                    visible: root.showPayload
                    text: String(accountAi.requestSummary.systemPrompt || "") + "\n\n"
                          + String(accountAi.requestSummary.userPrompt || "")
                    typeRole: "body"; typeSize: "small"; wrapMode: Text.WrapAnywhere
                }
                RowLayout {
                    MeoButton { text: qsTr("Cancel"); type: "outlined"; onClicked: accountAi.decide(false) }
                    MeoButton { text: qsTr("Allow once"); type: "filled"; onClicked: accountAi.decide(true, false) }
                    MeoButton { text: qsTr("Always allow this type"); type: "tonal"; onClicked: accountAi.decide(true, true) }
                }
            }
        }
        MeoText {
            Layout.fillWidth: true
            visible: accountAi.resultText.length > 0
            text: accountAi.resultText
            typeRole: "body"; typeSize: "medium"; wrapMode: Text.WordWrap
        }
        Repeater {
            model: accountAi.recommendedApps
            delegate: MeoListItem {
                required property var modelData
                Layout.fillWidth: true
                headline: String(modelData.name || modelData.id || "")
                overline: String(modelData.primary_source || modelData.source || "") + " · " + String(modelData.id || "")
                supportingText: String(modelData.aiReason || "")
                leadingIcon: "auto_awesome"; interactive: true
                onClicked: root.detailsRequested(modelData)
            }
        }
    }
}
