pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import MeoUI 1.0

Item {
    id: root
    signal searchRequested(string query)
    signal detailsRequested(var app)

    Component.onCompleted: {
        backend.loadRecommendations()
        backend.loadUpdates()
        backend.loadInstalled(false)
    }

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight + 64 * MeoTheme.globalScale
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: contentColumn
            width: Math.min(parent.width - 48 * MeoTheme.globalScale,
                            1120 * MeoTheme.globalScale)
            x: (parent.width - width) / 2
            y: 28 * MeoTheme.globalScale
            spacing: 22 * MeoTheme.globalScale

            PageHeading {
                Layout.fillWidth: true
                title: qsTr("OmniStore")
                subtitle: qsTr("Apps from your Linux sources, with one native MeoArch interface.")
                icon: "storefront"
            }

            MeoSearchBar {
                Layout.fillWidth: true
                Layout.maximumWidth: 760 * MeoTheme.globalScale
                placeholder: qsTr("Search apps and packages")
                trailingIcon: ""
                visualStyle: "pixel"
                onAccepted: function(query) {
                    if (query.trim().length > 0)
                        root.searchRequested(query.trim())
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 760 * MeoTheme.globalScale ? 3 : 1
                columnSpacing: 10 * MeoTheme.globalScale
                rowSpacing: 10 * MeoTheme.globalScale

                MeoCard {
                    Layout.fillWidth: true
                    Layout.minimumHeight: 112 * MeoTheme.globalScale
                    type: "filled"
                    padding: 16 * MeoTheme.globalScale
                    ColumnLayout {
                        width: parent.width
                        spacing: 4 * MeoTheme.globalScale
                        MeoIcon { icon: "system_update"; size: 26 * MeoTheme.globalScale; color: MeoTheme.primary }
                        MeoText {
                            text: qsTr("%1 updates").arg(backend.updates.length)
                            typeRole: "title"; typeSize: "small"; emphasized: true
                            color: MeoTheme.contentOnSurface
                        }
                        MeoText {
                            text: qsTr("Across enabled package sources")
                            typeRole: "body"; typeSize: "small"
                            color: MeoTheme.contentOnSurfaceVariant
                        }
                    }
                }

                MeoCard {
                    Layout.fillWidth: true
                    Layout.minimumHeight: 112 * MeoTheme.globalScale
                    type: "filled"
                    padding: 16 * MeoTheme.globalScale
                    ColumnLayout {
                        width: parent.width
                        spacing: 4 * MeoTheme.globalScale
                        MeoIcon { icon: "apps"; size: 26 * MeoTheme.globalScale; color: MeoTheme.primary }
                        MeoText {
                            text: qsTr("%1 installed").arg(backend.installedApps.length)
                            typeRole: "title"; typeSize: "small"; emphasized: true
                            color: MeoTheme.contentOnSurface
                        }
                        MeoText {
                            text: qsTr("Managed apps currently detected")
                            typeRole: "body"; typeSize: "small"
                            color: MeoTheme.contentOnSurfaceVariant
                        }
                    }
                }

                MeoCard {
                    Layout.fillWidth: true
                    Layout.minimumHeight: 112 * MeoTheme.globalScale
                    type: "filled"
                    padding: 16 * MeoTheme.globalScale
                    ColumnLayout {
                        width: parent.width
                        spacing: 4 * MeoTheme.globalScale
                        MeoIcon {
                            icon: backend.busy ? "sync" : "verified_user"
                            size: 26 * MeoTheme.globalScale
                            color: MeoTheme.primary
                        }
                        MeoText {
                            text: backend.busy ? backend.busyAction : qsTr("Ready")
                            typeRole: "title"; typeSize: "small"; emphasized: true
                            color: MeoTheme.contentOnSurface
                            elide: Text.ElideRight
                        }
                        MeoText {
                            text: qsTr("Existing OmniStore backend and safety rules")
                            typeRole: "body"; typeSize: "small"
                            color: MeoTheme.contentOnSurfaceVariant
                        }
                    }
                }
            }

            MeoBanner {
                Layout.fillWidth: true
                visible: backend.errorMessage.length > 0
                title: qsTr("OmniStore needs attention")
                text: backend.errorMessage
                icon: "error"
                tone: "error"
            }

            RowLayout {
                Layout.fillWidth: true
                MeoText {
                    text: qsTr("Featured")
                    typeRole: "title"; typeSize: "medium"; emphasized: true
                    color: MeoTheme.contentOnSurface
                }
                Item { Layout.fillWidth: true }
                MeoLoadingIndicator {
                    visible: backend.busyAction === qsTr("recommendations")
                    size: "s"
                }
                MeoIconButton {
                    icon.name: "refresh"
                    type: "tonal"
                    Accessible.name: qsTr("Refresh recommendations")
                    enabled: !backend.busy
                    onClicked: backend.loadRecommendations()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8 * MeoTheme.globalScale

                Repeater {
                    model: backend.featuredApps.length > 0 ? backend.featuredApps
                                                         : backend.trendingApps
                    delegate: AppRow {
                        required property var modelData
                        Layout.fillWidth: true
                        app: modelData
                        onDetailsRequested: function(app) { root.detailsRequested(app) }
                    }
                }

                MeoEmptyState {
                    Layout.fillWidth: true
                    visible: backend.featuredApps.length === 0
                             && backend.trendingApps.length === 0
                             && !backend.busy
                    icon: "explore"
                    title: qsTr("No recommendations yet")
                    description: qsTr("Search for an app, or refresh after your enabled sources are available.")
                }
            }

            MeoText {
                visible: backend.forYouApps.length > 0
                text: qsTr("For you")
                typeRole: "title"; typeSize: "medium"; emphasized: true
                color: MeoTheme.contentOnSurface
            }
            ColumnLayout {
                Layout.fillWidth: true
                visible: backend.forYouApps.length > 0
                spacing: 8 * MeoTheme.globalScale
                Repeater {
                    model: backend.forYouApps
                    delegate: AppRow {
                        required property var modelData
                        Layout.fillWidth: true
                        app: modelData
                        onDetailsRequested: function(app) { root.detailsRequested(app) }
                    }
                }
            }
        }
    }
}
