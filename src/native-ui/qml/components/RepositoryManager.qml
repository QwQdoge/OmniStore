pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeoUI 1.0

ColumnLayout {
    id: root
    spacing: 12 * MeoTheme.globalScale

    property string pendingRemoveType: ""
    property string pendingRemoveIdentity: ""
    property string pendingRemoveName: ""

    function repositoryRows() {
        const rows = []
        const sourceMap = repoBridge.repositories || ({})
        const types = ["flatpak", "pacman", "appimage"]
        for (let typeIndex = 0; typeIndex < types.length; ++typeIndex) {
            const type = types[typeIndex]
            const items = sourceMap[type] || []
            for (let index = 0; index < items.length; ++index) {
                const item = items[index] || ({})
                rows.push({
                    "type": type,
                    "name": String(item.name || item.url || qsTr("Unnamed source")),
                    "url": String(item.url || ""),
                    "managed": type !== "pacman" || !!item.managed
                })
            }
        }
        return rows
    }

    function typeLabel(type) {
        if (type === "flatpak") return qsTr("Flatpak remote")
        if (type === "pacman") return qsTr("Pacman repository")
        return qsTr("AppImage feed")
    }

    function typeIcon(type) {
        if (type === "flatpak") return "package_2"
        if (type === "pacman") return "inventory_2"
        return "deployed_code"
    }

    function removeIdentity(item) {
        return item.type === "appimage" ? item.url : item.name
    }

    function clearAddForm() {
        repoName.text = ""
        repoUrl.text = ""
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10 * MeoTheme.globalScale
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2 * MeoTheme.globalScale
            MeoText {
                text: qsTr("Custom repositories")
                typeRole: "title"
                typeSize: "medium"
                emphasized: true
                color: MeoTheme.contentOnSurface
            }
            MeoText {
                Layout.fillWidth: true
                text: qsTr("Flatpak remotes, OmniStore-managed Pacman repositories, and AppImage feed URLs use the existing Python repository manager and validation rules.")
                typeRole: "body"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
                wrapMode: Text.WordWrap
            }
        }
        MeoIconButton {
            icon.name: "refresh"
            type: "tonal"
            Accessible.name: qsTr("Refresh custom repositories")
            enabled: !repoBridge.busy
            onClicked: repoBridge.refresh()
        }
    }

    MeoProgressBar {
        Layout.fillWidth: true
        visible: repoBridge.busy
        indeterminate: true
    }

    MeoBanner {
        Layout.fillWidth: true
        visible: repoBridge.errorMessage.length > 0
        title: qsTr("Repository action failed")
        text: repoBridge.errorMessage
        icon: "error"
        tone: "error"
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.repositoryRows().length > 0
        spacing: 8 * MeoTheme.globalScale

        Repeater {
            model: root.repositoryRows()
            delegate: MeoCard {
                id: repositoryCard
                required property var modelData
                Layout.fillWidth: true
                type: "filled"
                compact: true
                padding: 14 * MeoTheme.globalScale

                RowLayout {
                    width: parent.width
                    spacing: 12 * MeoTheme.globalScale
                    MeoShape {
                        Layout.preferredWidth: 44 * MeoTheme.globalScale
                        Layout.preferredHeight: 44 * MeoTheme.globalScale
                        type: "squircle"
                        radius: 15 * MeoTheme.globalScale
                        color: MeoTheme.secondaryContainer
                        MeoIcon {
                            anchors.centerIn: parent
                            icon: root.typeIcon(repositoryCard.modelData.type)
                            size: 23 * MeoTheme.globalScale
                            color: MeoTheme.contentOnSecondaryContainer
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2 * MeoTheme.globalScale
                        RowLayout {
                            Layout.fillWidth: true
                            MeoText {
                                Layout.fillWidth: true
                                text: repositoryCard.modelData.name
                                typeRole: "title"
                                typeSize: "small"
                                emphasized: true
                                color: MeoTheme.contentOnSurface
                                elide: Text.ElideRight
                            }
                            MeoText {
                                text: root.typeLabel(repositoryCard.modelData.type)
                                typeRole: "label"
                                typeSize: "small"
                                color: MeoTheme.primary
                            }
                        }
                        MeoText {
                            Layout.fillWidth: true
                            text: repositoryCard.modelData.url.length > 0
                                  ? repositoryCard.modelData.url : qsTr("URL unavailable")
                            typeRole: "body"
                            typeSize: "small"
                            color: MeoTheme.contentOnSurfaceVariant
                            elide: Text.ElideMiddle
                        }
                        MeoText {
                            visible: repositoryCard.modelData.type === "pacman"
                                     && !repositoryCard.modelData.managed
                            text: qsTr("Detected from pacman.conf · not owned by OmniStore, so removal is disabled")
                            typeRole: "label"
                            typeSize: "small"
                            color: MeoTheme.contentOnSurfaceVariant
                            wrapMode: Text.WordWrap
                        }
                    }
                    MeoButton {
                        visible: repositoryCard.modelData.managed
                        text: qsTr("Remove")
                        type: "text"
                        icon.name: "delete"
                        enabled: !repoBridge.busy
                        onClicked: {
                            root.pendingRemoveType = repositoryCard.modelData.type
                            root.pendingRemoveIdentity = root.removeIdentity(repositoryCard.modelData)
                            root.pendingRemoveName = repositoryCard.modelData.name
                            removeDialog.open()
                        }
                    }
                }
            }
        }
    }

    MeoEmptyState {
        Layout.fillWidth: true
        visible: root.repositoryRows().length === 0 && !repoBridge.busy
        icon: "database"
        title: qsTr("No custom repositories")
        description: qsTr("Official Meo repositories are managed by the update channel and are intentionally not removable here.")
    }

    MeoCard {
        Layout.fillWidth: true
        type: "filled"
        padding: 18 * MeoTheme.globalScale

        ColumnLayout {
            width: parent.width
            spacing: 10 * MeoTheme.globalScale

            MeoText {
                text: qsTr("Add repository")
                typeRole: "title"
                typeSize: "small"
                emphasized: true
                color: MeoTheme.contentOnSurface
            }
            MeoText {
                Layout.fillWidth: true
                text: qsTr("Pacman repositories require HTTPS. Names use OmniStore's safe repository-name format; the backend validates the URL again before changing anything.")
                typeRole: "body"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
                wrapMode: Text.WordWrap
            }

            MeoExposedDropdown {
                id: repoType
                Layout.fillWidth: true
                label: qsTr("Repository type")
                model: [
                    { "label": qsTr("Flatpak remote"), "value": "flatpak" },
                    { "label": qsTr("Pacman repository"), "value": "pacman" },
                    { "label": qsTr("AppImage feed"), "value": "appimage" }
                ]
                textRole: "label"
                valueRole: "value"
                currentValue: "flatpak"
            }

            MeoTextField {
                id: repoName
                Layout.fillWidth: true
                label: repoType.currentValue === "appimage"
                       ? qsTr("Feed label") : qsTr("Repository name")
                placeholder: qsTr("example-repo")
                leadingIcon: "label"
                maxLength: 128
                showCounter: true
                supportingText: qsTr("Letters, numbers, @ . _ + : - only")
            }

            MeoTextField {
                id: repoUrl
                Layout.fillWidth: true
                label: qsTr("Repository URL")
                placeholder: repoType.currentValue === "pacman"
                             ? "https://example.org/$repo/os/$arch"
                             : "https://example.org/repository"
                leadingIcon: "link"
                maxLength: 2048
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                MeoButton {
                    text: qsTr("Add repository")
                    type: "filled"
                    icon.name: "add"
                    enabled: !repoBridge.busy
                             && repoName.text.trim().length > 0
                             && repoUrl.text.trim().length > 0
                    onClicked: addDialog.open()
                }
            }
        }
    }

    MeoDialog {
        id: addDialog
        parent: Overlay.overlay
        title: qsTr("Add %1?").arg(repoName.text.trim())
        message: qsTr("OmniStore will pass this source to the existing repository manager. Pacman changes may request system authentication; Flatpak uses the user remote scope.")
        icon: "add"
        confirmText: qsTr("Add repository")
        cancelText: qsTr("Cancel")
        onConfirmed: {
            repoBridge.addRepository(String(repoType.currentValue || "flatpak"),
                                     repoName.text.trim(), repoUrl.text.trim())
            root.clearAddForm()
        }
    }

    MeoDialog {
        id: removeDialog
        parent: Overlay.overlay
        title: qsTr("Remove %1?").arg(root.pendingRemoveName)
        message: root.pendingRemoveType === "pacman"
                 ? qsTr("Only Pacman repositories owned by OmniStore can be removed. The backend will persist the change and apply it through the existing privileged helper.")
                 : qsTr("This source will be removed through OmniStore's existing repository manager.")
        icon: "delete"
        confirmText: qsTr("Remove")
        cancelText: qsTr("Cancel")
        onConfirmed: repoBridge.removeRepository(root.pendingRemoveType,
                                                 root.pendingRemoveIdentity)
    }
}
