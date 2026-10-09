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
    property string selectedPackageId: ""
    signal searchRequested(string query)
    readonly property var sourceVariants: {
        if (fallbackApp.variants && fallbackApp.variants.length > 0)
            return fallbackApp.variants
        return [{source: fallbackApp.primary_source || fallbackApp.source || "Native",
                 id: fallbackApp.id || fallbackApp.name || "", installed: fallbackApp.installed === true,
                 version: fallbackApp.version || "", url: fallbackApp.url || ""}]
    }
    readonly property bool selectedMatches: packageIdentity().length > 0
        && String(backend.selectedApp.id || backend.selectedApp.name || "") === packageIdentity()
        && sourceKey(backend.selectedApp.primary_source || backend.selectedApp.source || "") === sourceKey(sourceName())
    readonly property var app: {
        const merged = Object.assign({}, fallbackApp, selectedVariant())
        if (selectedMatches)
            Object.assign(merged, backend.selectedApp)
        merged.variants = sourceVariants
        return merged
    }
    readonly property bool selectedInstalled: selectedVariant().installed === true
        || (selectedMatches && backend.selectedApp.installed === true)
    readonly property var screenshots: app.screenshots || []
    readonly property var currentPlan: transactions.installPlan || ({})
    readonly property var currentPlanRequest: currentPlan.request || ({})
    readonly property bool planMatches: String(currentPlanRequest.name || "") === root.packageIdentity()
                                        && sourceKey(currentPlanRequest.source || "") === sourceKey(root.sourceName())
                                        && (!root.installUrl() || String(currentPlanRequest.url || "") === root.installUrl())

    clip: true
    contentWidth: width
    contentHeight: detailColumn.implicitHeight + 40 * MeoTheme.globalScale
    boundsBehavior: Flickable.StopAtBounds

    function appName() { return String(app.name || app.id || qsTr("App details")) }
    function appId() { return String(app.id || app.name || "") }
    function sourceKey(source) {
        const key = String(source).toLowerCase()
        return key === "native" ? "pacman" : key
    }
    function primarySourceName() { return String(fallbackApp.primary_source || fallbackApp.source || "Native") }
    function sourceName() { return selectedSource.length > 0 ? selectedSource : primarySourceName() }
    function selectedVariant() {
        for (let index = 0; index < sourceVariants.length; ++index) {
            const variant = sourceVariants[index]
            if (sourceKey(variant.source || "") === sourceKey(sourceName())
                && (!selectedPackageId || String(variant.id || variant.name || "") === selectedPackageId))
                return variant
        }
        return ({})
    }
    function packageIdentity() {
        const variant = selectedVariant()
        return String(variant.id || variant.name || "")
    }
    function versionText() {
        const variant = selectedVariant()
        return String((selectedMatches ? backend.selectedApp.version : "") || variant.version || "")
    }
    function iconSource() { return String(app.icon || "") }
    function installUrl() {
        const variant = selectedVariant()
        return String(variant.url || (selectedMatches ? backend.selectedApp.url : "") || "")
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
    function chooseSource(source, packageId) {
        const next = String(source || "").trim()
        const nextId = String(packageId || "").trim()
        if (!next || !nextId || (sourceKey(next) === sourceKey(sourceName()) && nextId === packageIdentity()))
            return
        transactions.clearInstallPlan()
        selectedSource = next
        selectedPackageId = nextId
        backend.loadDetails(nextId, next)
    }

    onFallbackAppChanged: {
        selectedSource = ""
        selectedPackageId = ""
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
                    icon: root.selectedInstalled ? "check_circle" : "apps"
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
                    enabled: !!(modelData.id || modelData.name) && !transactions.planning && !transactions.busy
                    isSegmented: true
                    vibrant: true
                    selected: root.sourceKey(modelData.source || "") === root.sourceKey(root.sourceName())
                              && String(modelData.id || modelData.name || "") === root.packageIdentity()
                    onClicked: root.chooseSource(String(modelData.source || ""), String(modelData.id || modelData.name || ""))
                }
            }
        }

        MeoButton {
            visible: root.fallbackApp.external_install_request === true
            text: qsTr("Find other sources")
            type: "text"
            icon.name: "search"
            onClicked: root.searchRequested(String(root.fallbackApp.name || root.packageIdentity()))
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * MeoTheme.globalScale

            MeoButton {
                visible: !!root.selectedInstalled
                Layout.fillWidth: true
                text: qsTr("Open")
                type: "filled"
                icon.name: "open_in_new"
                enabled: !backend.busy
                onClicked: backend.launchApp(root.packageIdentity(), root.sourceName())
            }
            MeoButton {
                visible: !!root.selectedInstalled
                text: qsTr("Open folder")
                type: "tonal"
                icon.name: "folder_open"
                enabled: !backend.busy
                onClicked: backend.locateApp(root.packageIdentity(), root.sourceName())
            }
            MeoButton {
                visible: !!root.selectedInstalled
                Layout.fillWidth: true
                text: qsTr("Remove")
                type: "outlined"
                icon.name: "delete"
                enabled: !backend.busy && !transactions.busy && transactions.available
                onClicked: removeDialog.open()
            }
            MeoButton {
                objectName: "installButton"
                visible: !root.selectedInstalled
                Layout.fillWidth: true
                text: transactions.planning ? qsTr("Preparing…") : qsTr("Install")
                type: "filled"
                icon.name: transactions.planning ? "hourglass_top" : "download"
                enabled: root.packageIdentity().length > 0 && !backend.busy && !transactions.busy
                         && !transactions.planning && transactions.available
                onClicked: transactions.planInstall(root.packageIdentity(), root.sourceName(), root.installUrl())
            }
        }

        Store.InstallPlanReview {
            Layout.fillWidth: true
            visible: !root.selectedInstalled && (transactions.planning || root.planMatches)
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
