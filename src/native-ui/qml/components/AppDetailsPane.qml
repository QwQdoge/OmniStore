pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeoUI 1.0
import OmniStore.Native 1.0 as Store

Flickable {
    id: root
    property var fallbackApp: ({})
    property string selectedSource: ""
    readonly property string fallbackIdentity: String(fallbackApp.id || fallbackApp.name || "")
    readonly property string selectedIdentity: String(backend.selectedApp.id || backend.selectedApp.name || "")
    readonly property bool selectedMatches: fallbackIdentity.length > 0
                                            && selectedIdentity === fallbackIdentity
    readonly property var app: {
        if (!selectedMatches)
            return fallbackApp
        const merged = Object.assign({}, fallbackApp, backend.selectedApp)
        if (!backend.selectedApp.variants || backend.selectedApp.variants.length === 0)
            merged.variants = fallbackApp.variants || []
        if (fallbackApp.installed === true)
            merged.installed = true
        return merged
    }
    readonly property var screenshots: app.screenshots || []
    readonly property var currentPlan: transactions.installPlan || ({})
    readonly property var currentPlanRequest: currentPlan.request || ({})
    readonly property bool planMatches: String(currentPlanRequest.name || "") === root.packageIdentity()
                                        && String(currentPlanRequest.source || "") === root.sourceName()

    clip: true
    contentWidth: width
    contentHeight: detailColumn.implicitHeight + 40 * MeoTheme.globalScale
    boundsBehavior: Flickable.StopAtBounds

    function appName() { return String(app.name || app.id || qsTr("App details")) }
    function appId() { return String(app.id || app.name || "") }
    function primarySourceName() { return String(app.primary_source || app.source || qsTr("Native")) }
    function sourceName() { return selectedSource.length > 0 ? selectedSource : primarySourceName() }
    function selectedVariant() {
        const variants = app.variants || []
        const source = sourceName()
        for (let index = 0; index < variants.length; ++index) {
            if (String(variants[index].source || "") === source)
                return variants[index]
        }
        return ({})
    }
    function packageIdentity() {
        const variant = selectedVariant()
        return String(variant.id || variant.name || app.id || app.name || "")
    }
    function versionText() {
        const variant = selectedVariant()
        return String(variant.version || app.version || "")
    }
    function iconSource() { return String(app.icon || "") }
    function installUrl() {
        const variant = selectedVariant()
        return String(variant.url || app.url || "")
    }
    function formatBytes(value) {
        const bytes = Number(value)
        if (!Number.isFinite(bytes) || bytes <= 0)
            return ""
        const units = [qsTr("B"), qsTr("KB"), qsTr("MB"), qsTr("GB"), qsTr("TB")]
        let amount = bytes
        let index = 0
        while (amount >= 1024 && index < units.length - 1) {
            amount /= 1024
            ++index
        }
        return (index === 0 ? Math.round(amount) : amount.toFixed(amount >= 10 ? 1 : 2)) + " " + units[index]
    }
    function sizeText() {
        const variant = selectedVariant()
        if (String(variant.installed_size || "").length > 0)
            return String(variant.installed_size)
        if (variant.disk_size)
            return formatBytes(variant.disk_size)
        if (String(app.installed_size || "").length > 0)
            return String(app.installed_size)
        return formatBytes(app.disk_size)
    }
    function chooseSource(source) {
        const next = String(source || "").trim()
        if (next.length === 0 || next === root.sourceName())
            return
        transactions.clearInstallPlan()
        selectedSource = next
    }

    onFallbackIdentityChanged: {
        selectedSource = ""
        transactions.clearInstallPlan()
    }

    ColumnLayout {
        id: detailColumn
        width: parent.width - 36 * MeoTheme.globalScale
        x: 18 * MeoTheme.globalScale
        spacing: 20 * MeoTheme.globalScale

        RowLayout {
            Layout.fillWidth: true
            spacing: 16 * MeoTheme.globalScale

            MeoShape {
                Layout.preferredWidth: 92 * MeoTheme.globalScale
                Layout.preferredHeight: 92 * MeoTheme.globalScale
                type: "squircle"
                radius: 28 * MeoTheme.globalScale
                color: MeoTheme.primaryContainer
                clip: true

                Image {
                    id: appIcon
                    anchors.fill: parent
                    anchors.margins: 8 * MeoTheme.globalScale
                    source: root.iconSource()
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectFit
                    visible: source.toString().length > 0 && status === Image.Ready
                }
                MeoIcon {
                    anchors.centerIn: parent
                    visible: !appIcon.visible
                    icon: root.app.installed ? "check_circle" : "apps"
                    size: 42 * MeoTheme.globalScale
                    color: MeoTheme.contentOnPrimaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4 * MeoTheme.globalScale

                MeoText {
                    Layout.fillWidth: true
                    text: root.appName()
                    typeRole: "headline"
                    typeSize: "small"
                    emphasized: true
                    color: MeoTheme.contentOnSurface
                    wrapMode: Text.WordWrap
                }
                MeoText {
                    Layout.fillWidth: true
                    text: root.sourceName() + (root.versionText().length > 0 ? " · " + root.versionText() : "")
                    typeRole: "label"
                    typeSize: "medium"
                    color: MeoTheme.primary
                    elide: Text.ElideRight
                }
                MeoText {
                    Layout.fillWidth: true
                    visible: !!root.app.developer
                    text: String(root.app.developer || "")
                    typeRole: "body"
                    typeSize: "small"
                    color: MeoTheme.contentOnSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }

        MeoBanner {
            Layout.fillWidth: true
            visible: root.fallbackApp.external_install_request === true
            title: qsTr("External installation request")
            text: qsTr("Another application requested this package. Review its source and installation plan before confirming. Nothing has been installed.")
            icon: "info"
            tone: "info"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * MeoTheme.globalScale

            MeoButton {
                visible: !!root.app.installed
                Layout.fillWidth: true
                text: qsTr("Open")
                type: "filled"
                icon.name: "open_in_new"
                enabled: !backend.busy
                onClicked: backend.launchApp(root.packageIdentity(), root.sourceName())
            }
            MeoButton {
                visible: !!root.app.installed
                text: qsTr("Open folder")
                type: "tonal"
                icon.name: "folder_open"
                enabled: !backend.busy
                onClicked: backend.locateApp(root.packageIdentity(), root.sourceName())
            }
            MeoButton {
                visible: !!root.app.installed
                Layout.fillWidth: true
                text: qsTr("Remove")
                type: "outlined"
                icon.name: "delete"
                enabled: !backend.busy && !transactions.busy && transactions.available
                onClicked: removeDialog.open()
            }
            MeoButton {
                visible: !root.app.installed
                Layout.fillWidth: true
                text: transactions.planning ? qsTr("Preparing…") : qsTr("Install")
                type: "filled"
                icon.name: transactions.planning ? "hourglass_top" : "download"
                enabled: !backend.busy && !transactions.busy
                         && !transactions.planning && transactions.available
                onClicked: transactions.planInstall(root.packageIdentity(), root.sourceName(), root.installUrl())
            }
        }

        Store.InstallPlanReview {
            Layout.fillWidth: true
            visible: !root.app.installed && (transactions.planning || root.planMatches)
            plan: root.planMatches ? transactions.installPlan : ({})
            planning: transactions.planning
            errorMessage: transactions.errorMessage
            onConfirmRequested: transactions.applyInstallPlan()
            onCancelRequested: transactions.clearInstallPlan()
        }

        MeoBanner {
            Layout.fillWidth: true
            visible: !transactions.available && !transactions.busy
            title: qsTr("Transaction service unavailable")
            text: transactions.errorMessage.length > 0
                  ? transactions.errorMessage
                  : qsTr("Install, remove and update actions require the OmniStore background transaction service.")
            icon: "cloud_off"
            tone: "warning"
        }

        MeoBanner {
            Layout.fillWidth: true
            visible: transactions.available && transactions.errorMessage.length > 0
                     && !transactions.busy && !transactions.planning
            title: qsTr("Package action unavailable")
            text: transactions.errorMessage
            icon: "error"
            tone: "error"
        }

        MeoProgressBar {
            Layout.fillWidth: true
            visible: (backend.busyAction === qsTr("app details") && !root.selectedMatches)
                     || transactions.busy
            indeterminate: transactions.busy ? transactions.progress < 0 : true
            value: transactions.progress >= 0 ? transactions.progress : 0
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.screenshots.length > 0
            spacing: 10 * MeoTheme.globalScale

            MeoText {
                text: qsTr("Screenshots")
                typeRole: "title"
                typeSize: "small"
                emphasized: true
                color: MeoTheme.contentOnSurface
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: 190 * MeoTheme.globalScale
                orientation: ListView.Horizontal
                spacing: 10 * MeoTheme.globalScale
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.screenshots

                delegate: MeoCard {
                    required property var modelData
                    width: Math.min(320 * MeoTheme.globalScale, ListView.view.width * 0.78)
                    height: ListView.view.height
                    padding: 0
                    type: "filled"
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: String(modelData || "")
                        asynchronous: true
                        cache: true
                        fillMode: Image.PreserveAspectCrop
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8 * MeoTheme.globalScale

            MeoText {
                text: qsTr("About")
                typeRole: "title"
                typeSize: "small"
                emphasized: true
                color: MeoTheme.contentOnSurface
            }
            MeoText {
                Layout.fillWidth: true
                text: String(root.app.description || qsTr("No description is available for this package."))
                typeRole: "body"
                typeSize: "medium"
                color: MeoTheme.contentOnSurfaceVariant
                wrapMode: Text.WordWrap
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: width >= 500 * MeoTheme.globalScale ? 2 : 1
            columnSpacing: 10 * MeoTheme.globalScale
            rowSpacing: 10 * MeoTheme.globalScale

            MeoCard {
                Layout.fillWidth: true
                type: "filled"
                compact: true
                padding: 14 * MeoTheme.globalScale
                ColumnLayout {
                    width: parent.width
                    spacing: 3 * MeoTheme.globalScale
                    MeoText { text: qsTr("Source"); typeRole: "label"; typeSize: "small"; color: MeoTheme.contentOnSurfaceVariant }
                    MeoText { Layout.fillWidth: true; text: root.sourceName(); typeRole: "title"; typeSize: "small"; emphasized: true; color: MeoTheme.contentOnSurface; elide: Text.ElideRight }
                }
            }

            MeoCard {
                Layout.fillWidth: true
                type: "filled"
                compact: true
                padding: 14 * MeoTheme.globalScale
                ColumnLayout {
                    width: parent.width
                    spacing: 3 * MeoTheme.globalScale
                    MeoText { text: qsTr("Version"); typeRole: "label"; typeSize: "small"; color: MeoTheme.contentOnSurfaceVariant }
                    MeoText { Layout.fillWidth: true; text: root.versionText().length > 0 ? root.versionText() : qsTr("Unknown"); typeRole: "title"; typeSize: "small"; emphasized: true; color: MeoTheme.contentOnSurface; elide: Text.ElideRight }
                }
            }

            MeoCard {
                Layout.fillWidth: true
                visible: String(root.app.license || "").length > 0
                type: "filled"
                compact: true
                padding: 14 * MeoTheme.globalScale
                ColumnLayout {
                    width: parent.width
                    spacing: 3 * MeoTheme.globalScale
                    MeoText { text: qsTr("License"); typeRole: "label"; typeSize: "small"; color: MeoTheme.contentOnSurfaceVariant }
                    MeoText { Layout.fillWidth: true; text: String(root.app.license || ""); typeRole: "title"; typeSize: "small"; emphasized: true; color: MeoTheme.contentOnSurface; elide: Text.ElideRight }
                }
            }

            MeoCard {
                Layout.fillWidth: true
                visible: root.sizeText().length > 0
                type: "filled"
                compact: true
                padding: 14 * MeoTheme.globalScale
                ColumnLayout {
                    width: parent.width
                    spacing: 3 * MeoTheme.globalScale
                    MeoText { text: qsTr("Installed size"); typeRole: "label"; typeSize: "small"; color: MeoTheme.contentOnSurfaceVariant }
                    MeoText { Layout.fillWidth: true; text: root.sizeText(); typeRole: "title"; typeSize: "small"; emphasized: true; color: MeoTheme.contentOnSurface; elide: Text.ElideRight }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: (root.app.variants || []).length > 0
            spacing: 8 * MeoTheme.globalScale

            MeoText {
                text: qsTr("Choose source")
                typeRole: "title"
                typeSize: "small"
                emphasized: true
                color: MeoTheme.contentOnSurface
            }
            MeoText {
                Layout.fillWidth: true
                visible: (root.app.variants || []).length > 1
                text: qsTr("The selected package and source are used for the installation plan. Trust, availability and permissions are checked again before you can install.")
                typeRole: "body"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: root.app.variants || []
                delegate: MeoListItem {
                    required property var modelData
                    Layout.fillWidth: true
                    headline: String(modelData.source || qsTr("Source"))
                    overline: String(modelData.id || modelData.name || "")
                    supportingText: String(modelData.version || qsTr("Unknown version"))
                                   + (modelData.installed_size ? " · " + String(modelData.installed_size) : "")
                    leadingIcon: modelData.installed ? "check_circle" : "package_2"
                    interactive: true
                    enabled: !transactions.planning && !transactions.busy
                    isSegmented: true
                    vibrant: true
                    selected: String(modelData.source || "") === root.sourceName()
                    onClicked: root.chooseSource(String(modelData.source || ""))
                }
            }
        }

        MeoCard {
            Layout.fillWidth: true
            visible: String(root.app.install_location || "").length > 0
            type: "outlined"
            compact: true
            padding: 14 * MeoTheme.globalScale
            ColumnLayout {
                width: parent.width
                spacing: 4 * MeoTheme.globalScale
                MeoText { text: qsTr("Install location"); typeRole: "label"; typeSize: "small"; color: MeoTheme.contentOnSurfaceVariant }
                MeoText { Layout.fillWidth: true; text: String(root.app.install_location || ""); typeRole: "body"; typeSize: "small"; color: MeoTheme.contentOnSurface; wrapMode: Text.WrapAnywhere }
            }
        }

        MeoBanner {
            Layout.fillWidth: true
            visible: backend.errorMessage.length > 0
            title: qsTr("Details unavailable")
            text: backend.errorMessage
            icon: "error"
            tone: "error"
        }
    }

    MeoDialog {
        id: removeDialog
        parent: Overlay.overlay
        title: qsTr("Remove %1?").arg(root.appName())
        message: qsTr("OmniStore will hand this uninstall to its background transaction service through %1. Package-manager safeguards remain unchanged.").arg(root.sourceName())
        icon: "delete"
        confirmText: qsTr("Remove")
        cancelText: qsTr("Cancel")
        onConfirmed: transactions.removeApp(root.packageIdentity(), root.sourceName())
    }
}
