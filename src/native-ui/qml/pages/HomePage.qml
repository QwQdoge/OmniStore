pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import MeoUI 1.0
import OmniStore.Native 1.0 as Store

Item {
    id: root
    readonly property MeoWindowMetrics metrics: MeoWindowMetrics { availableWidth: root.width; maxColumns: 3 }
    signal searchRequested(string query)
    signal aiRequested(string mode, string query, var candidates)
    signal exploreRequested()
    signal detailsRequested(var app)

    function featuredModel() {
        if (backend.featuredApps.length > 0)
            return backend.featuredApps.slice(0, 2)
        return backend.trendingApps.slice(0, 2)
    }

    function popularModel() {
        if (backend.trendingApps.length > 0)
            return backend.trendingApps.slice(0, 6)
        return backend.featuredApps.slice(0, 6)
    }

    Component.onCompleted: {
        backend.loadRecommendations()
        backend.loadUpdates()
        backend.loadInstalled(false)
    }

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight + 72 * MeoTheme.globalScale
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: contentColumn
            width: Math.min(parent.width - 48 * MeoTheme.globalScale,
                            1180 * MeoTheme.globalScale)
            x: (parent.width - width) / 2
            y: 28 * MeoTheme.globalScale
            spacing: 26 * MeoTheme.globalScale

            MeoButton {
                visible: !!accountAi.features.recommend
                text: qsTr("AI pick of the day")
                icon.name: "auto_awesome"; type: "tonal"
                enabled: !backend.busy && !accountAi.busy
                onClicked: root.aiRequested("daily", qsTr("Recommend a useful app for today"),
                    backend.featuredApps.concat(backend.trendingApps).concat(backend.forYouApps))
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 18 * MeoTheme.globalScale

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5 * MeoTheme.globalScale
                    MeoText {
                        text: qsTr("Discover software")
                        typeRole: "headline"
                        typeSize: "medium"
                        emphasized: true
                        color: MeoTheme.contentOnSurface
                    }
                    MeoText {
                        Layout.fillWidth: true
                        text: qsTr("Apps and packages from the software sources available on this MeoArch system.")
                        typeRole: "body"
                        typeSize: "medium"
                        color: MeoTheme.contentOnSurfaceVariant
                        wrapMode: Text.WordWrap
                    }
                }

                MeoButton {
                    text: qsTr("Explore all")
                    type: "tonal"
                    icon.name: "explore"
                    onClicked: root.exploreRequested()
                }
            }

            Store.LoadStateBanner {
                Layout.fillWidth: true
                hasData: backend.featuredApps.length > 0 || backend.trendingApps.length > 0
                onRetryRequested: backend.loadRecommendations()
            }

            GridLayout {
                Layout.fillWidth: true
                columns: root.metrics.isCompactWidth || root.metrics.isMediumWidth ? 1 : 3
                columnSpacing: 10 * MeoTheme.globalScale
                rowSpacing: 10 * MeoTheme.globalScale

                MeoCard {
                    Layout.fillWidth: true
                    type: "filled"
                    compact: true
                    padding: 14 * MeoTheme.globalScale
                    RowLayout {
                        width: parent.width
                        spacing: 10 * MeoTheme.globalScale
                        MeoIcon { icon: "apps"; size: 24 * MeoTheme.globalScale; color: MeoTheme.primary }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1 * MeoTheme.globalScale
                            MeoText {
                                text: qsTr("%1 installed").arg(backend.installedApps.length)
                                typeRole: "title"; typeSize: "small"; emphasized: true
                                color: MeoTheme.contentOnSurface
                            }
                            MeoText {
                                text: qsTr("Detected applications")
                                typeRole: "label"; typeSize: "small"
                                color: MeoTheme.contentOnSurfaceVariant
                            }
                        }
                    }
                }

                MeoCard {
                    Layout.fillWidth: true
                    type: "filled"
                    compact: true
                    padding: 14 * MeoTheme.globalScale
                    RowLayout {
                        width: parent.width
                        spacing: 10 * MeoTheme.globalScale
                        MeoIcon { icon: "system_update"; size: 24 * MeoTheme.globalScale; color: MeoTheme.primary }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1 * MeoTheme.globalScale
                            MeoText {
                                text: qsTr("%1 updates").arg(backend.updates.length)
                                typeRole: "title"; typeSize: "small"; emphasized: true
                                color: MeoTheme.contentOnSurface
                            }
                            MeoText {
                                text: qsTr("Across enabled sources")
                                typeRole: "label"; typeSize: "small"
                                color: MeoTheme.contentOnSurfaceVariant
                            }
                        }
                    }
                }

                MeoCard {
                    Layout.fillWidth: true
                    type: "filled"
                    compact: true
                    padding: 14 * MeoTheme.globalScale
                    RowLayout {
                        width: parent.width
                        spacing: 10 * MeoTheme.globalScale
                        MeoIcon {
                            icon: backend.busy ? "sync" : "verified_user"
                            size: 24 * MeoTheme.globalScale
                            color: MeoTheme.primary
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1 * MeoTheme.globalScale
                            MeoText {
                                Layout.fillWidth: true
                                text: backend.busy ? backend.busyAction : qsTr("Ready")
                                typeRole: "title"; typeSize: "small"; emphasized: true
                                color: MeoTheme.contentOnSurface
                                elide: Text.ElideRight
                            }
                            MeoText {
                                text: qsTr("OmniStore package backend")
                                typeRole: "label"; typeSize: "small"
                                color: MeoTheme.contentOnSurfaceVariant
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                MeoText {
                    text: qsTr("Featured")
                    typeRole: "title"
                    typeSize: "medium"
                    emphasized: true
                    color: MeoTheme.contentOnSurface
                }
                Item { Layout.fillWidth: true }
                MeoLoadingIndicator {
                    visible: backend.busyOperation === "recommendations"
                    size: "s"
                }
                MeoIconButton {
                    icon.name: "refresh"
                    type: "tonal"
                    toolTipText: qsTr("Refresh recommendations")
                    enabled: !backend.busy
                    onClicked: backend.loadRecommendations()
                }
            }

            Store.ListSkeleton {
                Layout.fillWidth: true
                active: backend.busyOperation === "recommendations" && root.featuredModel().length === 0
                rows: 3
            }

            GridLayout {
                Layout.fillWidth: true
                columns: root.metrics.supportsTwoPane ? 2 : 1
                uniformCellWidths: true
                columnSpacing: 14 * MeoTheme.globalScale
                rowSpacing: 14 * MeoTheme.globalScale

                Repeater {
                    model: root.featuredModel()
                    delegate: StoreAppCard {
                        required property var modelData
                        Layout.fillWidth: true
                        prominent: true
                        app: modelData
                        onDetailsRequested: function(app) { root.detailsRequested(app) }
                    }
                }
            }

            MeoEmptyState {
                Layout.fillWidth: true
                visible: root.featuredModel().length === 0 && !backend.busy
                icon: "storefront"
                title: qsTr("No featured apps yet")
                description: qsTr("Refresh recommendations or check the software sources enabled in Settings.")
            }

            RowLayout {
                Layout.fillWidth: true
                MeoText {
                    text: qsTr("Popular")
                    typeRole: "title"
                    typeSize: "medium"
                    emphasized: true
                    color: MeoTheme.contentOnSurface
                }
                Item { Layout.fillWidth: true }
                MeoButton {
                    text: qsTr("Browse categories")
                    type: "text"
                    icon.name: "arrow_forward"
                    onClicked: root.exploreRequested()
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: root.metrics.preferredColumns
                uniformCellWidths: true
                columnSpacing: 12 * MeoTheme.globalScale
                rowSpacing: 12 * MeoTheme.globalScale

                Repeater {
                    model: root.popularModel()
                    delegate: StoreAppCard {
                        required property var modelData
                        Layout.fillWidth: true
                        app: modelData
                        onDetailsRequested: function(app) { root.detailsRequested(app) }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: backend.forYouApps.length > 0
                spacing: 12 * MeoTheme.globalScale

                MeoText {
                    text: qsTr("For you")
                    typeRole: "title"
                    typeSize: "medium"
                    emphasized: true
                    color: MeoTheme.contentOnSurface
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: root.metrics.preferredColumns
                    uniformCellWidths: true
                    columnSpacing: 12 * MeoTheme.globalScale
                    rowSpacing: 12 * MeoTheme.globalScale

                    Repeater {
                        model: backend.forYouApps.slice(0, 6)
                        delegate: StoreAppCard {
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
}
