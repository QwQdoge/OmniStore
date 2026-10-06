pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeoUI 1.0

Flickable {
    id: root
    property var fallbackApp: ({})
    readonly property string fallbackIdentity: String(fallbackApp.id || fallbackApp.name || "")
    readonly property string selectedIdentity: String(backend.selectedApp.id || backend.selectedApp.name || "")
    readonly property bool selectedMatches: fallbackIdentity.length > 0
                                            && selectedIdentity === fallbackIdentity
    readonly property var app: selectedMatches ? backend.selectedApp : fallbackApp
    readonly property var screenshots: app.screenshots || []

    clip: true
    contentWidth: width
    contentHeight: detailColumn.implicitHeight + 40 * MeoTheme.globalScale
    boundsBehavior: Flickable.StopAtBounds

    function appName() { return String(app.name || app.id || qsTr("App details")) }
    function appId() { return String(app.id || app.name || "") }
    function sourceName() { return String(app.primary_source || app.source || qsTr("Native")) }
    function versionText() { return String(app.version || "") }
    function iconSource() { return String(app.icon || "") }
    function installUrl() {
        const variants = app.variants || []
        for (let index = 0; index < variants.length; ++index) {
            if (String(variants[index].source || "") === sourceName() && variants[index].url)
                return String(variants[index].url)
        }
        return String(app.url || "")
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
        if (String(app.installed_size || "").length > 0)
            return String(app.installed_size)
        return formatBytes(app.disk_size)
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
                onClicked: backend.launchApp(root.appId(), root.sourceName())
            }
            MeoButton {
                visible: !!root.app.installed
                Layout.fillWidth: true
                text: qsTr("Remove")
                type: "outlined"
                icon.name: "delete"
                enabled: !backend.busy
                onClicked: removeDialog.open()
            }
            MeoButton {
                visible: !root.app.installed
                Layout.fillWidth: true
                text: qsTr("Install")
                type: "filled"
                icon.name: "download"
                enabled: !backend.busy
                onClicked: installDialog.open()
            }
        }

        MeoProgressBar {
            Layout.fillWidth: true
            visible: backend.busyAction === qsTr("app details") && !root.selectedMatches
            indeterminate: true
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
                    MeoText {
                        text: qsTr("Source")
                        typeRole: "label"; typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                    }
                    MeoText {
                        Layout.fillWidth: true
                        text: root.sourceName()
                        typeRole: "title"; typeSize: "small"; emphasized: true
                        color: MeoTheme.contentOnSurface
                        elide: Text.ElideRight
                    }
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
                    MeoText {
                        text: qsTr("Version")
                        typeRole: "label"; typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                    }
                    MeoText {
                        Layout.fillWidth: true
                        text: root.versionText().length > 0 ? root.versionText() : qsTr("Unknown")
                        typeRole: "title"; typeSize: "small"; emphasized: true
                        color: MeoTheme.contentOnSurface
                        elide: Text.ElideRight
                    }
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
                    MeoText {
                        text: qsTr("License")
                        typeRole: "label"; typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                    }
                    MeoText {
                        Layout.fillWidth: true
                        text: String(root.app.license || "")
                        typeRole: "title"; typeSize: "small"; emphasized: true
                        color: MeoTheme.contentOnSurface
                        elide: Text.ElideRight
                    }
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
                    MeoText {
                        text: qsTr("Installed size")
                        typeRole: "label"; typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                    }
                    MeoText {
                        Layout.fillWidth: true
                        text: root.sizeText()
                        typeRole: "title"; typeSize: "small"; emphasized: true
                        color: MeoTheme.contentOnSurface
                        elide: Text.ElideRight
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: (root.app.variants || []).length > 0
            spacing: 8 * MeoTheme.globalScale

            MeoText {
                text: qsTr("Available variants")
                typeRole: "title"
                typeSize: "small"
                emphasized: true
                color: MeoTheme.contentOnSurface
            }

            Repeater {
                model: root.app.variants || []
                delegate: MeoListItem {
                    required property var modelData
                    Layout.fillWidth: true
                    headline: String(modelData.source || qsTr("Source"))
                    supportingText: String(modelData.version || qsTr("Unknown version"))
                                   + (modelData.installed_size ? " · " + String(modelData.installed_size) : "")
                    leadingIcon: modelData.installed ? "check_circle" : "package_2"
                    interactive: false
                    isSegmented: true
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
                MeoText {
                    text: qsTr("Install location")
                    typeRole: "label"; typeSize: "small"
                    color: MeoTheme.contentOnSurfaceVariant
                }
                MeoText {
                    Layout.fillWidth: true
                    text: String(root.app.install_location || "")
                    typeRole: "body"; typeSize: "small"
                    color: MeoTheme.contentOnSurface
                    wrapMode: Text.WrapAnywhere
                }
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
        id: installDialog
        parent: Overlay.overlay
        title: qsTr("Install %1?").arg(root.appName())
        message: qsTr("The existing OmniStore backend will install this app through %1. Authentication and package-manager safeguards remain unchanged.").arg(root.sourceName())
        icon: "download"
        confirmText: qsTr("Install")
        cancelText: qsTr("Cancel")
        onConfirmed: backend.installApp(root.appId(), root.sourceName(), root.installUrl())
    }

    MeoDialog {
        id: removeDialog
        parent: Overlay.overlay
        title: qsTr("Remove %1?").arg(root.appName())
        message: qsTr("The existing OmniStore backend will run the uninstall path for %1. Review Tasks for package-manager output and dependency warnings.").arg(root.sourceName())
        icon: "delete"
        confirmText: qsTr("Remove")
        cancelText: qsTr("Cancel")
        onConfirmed: backend.removeApp(root.appId(), root.sourceName())
    }
}
