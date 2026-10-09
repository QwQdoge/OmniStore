pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import MeoUI 1.0
import OmniStore.Native 1.0 as Store

Item {
    id: root
    signal detailsRequested(var app)

    property string activeCategory: ""
    property string activeCategoryQuery: ""

    function browseCategory(category, label) {
        root.activeCategory = label
        root.activeCategoryQuery = category
        backend.search("category:" + category)
    }

    Component.onCompleted: backend.loadRecommendations()

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
            spacing: 20 * MeoTheme.globalScale

            Store.PageHeading {
                Layout.fillWidth: true
                title: qsTr("Explore")
                subtitle: qsTr("Browse software across the sources available on this system.")
                icon: "explore"
            }

            MeoText {
                text: qsTr("Categories")
                typeRole: "title"
                typeSize: "medium"
                emphasized: true
                color: MeoTheme.contentOnSurface
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 820 * MeoTheme.globalScale ? 4 : 2
                columnSpacing: 10 * MeoTheme.globalScale
                rowSpacing: 10 * MeoTheme.globalScale

                MeoButton { Layout.fillWidth: true; text: qsTr("Development"); type: root.activeCategory === qsTr("Development") ? "filled" : "tonal"; icon.name: "code"; enabled: !backend.busy; onClicked: root.browseCategory("Development", qsTr("Development")) }
                MeoButton { Layout.fillWidth: true; text: qsTr("Games"); type: root.activeCategory === qsTr("Games") ? "filled" : "tonal"; icon.name: "sports_esports"; enabled: !backend.busy; onClicked: root.browseCategory("Game", qsTr("Games")) }
                MeoButton { Layout.fillWidth: true; text: qsTr("Internet"); type: root.activeCategory === qsTr("Internet") ? "filled" : "tonal"; icon.name: "language"; enabled: !backend.busy; onClicked: root.browseCategory("Network", qsTr("Internet")) }
                MeoButton { Layout.fillWidth: true; text: qsTr("Media"); type: root.activeCategory === qsTr("Media") ? "filled" : "tonal"; icon.name: "play_circle"; enabled: !backend.busy; onClicked: root.browseCategory("AudioVideo", qsTr("Media")) }
                MeoButton { Layout.fillWidth: true; text: qsTr("Office"); type: root.activeCategory === qsTr("Office") ? "filled" : "tonal"; icon.name: "description"; enabled: !backend.busy; onClicked: root.browseCategory("Office", qsTr("Office")) }
                MeoButton { Layout.fillWidth: true; text: qsTr("Graphics"); type: root.activeCategory === qsTr("Graphics") ? "filled" : "tonal"; icon.name: "palette"; enabled: !backend.busy; onClicked: root.browseCategory("Graphics", qsTr("Graphics")) }
                MeoButton { Layout.fillWidth: true; text: qsTr("System"); type: root.activeCategory === qsTr("System") ? "filled" : "tonal"; icon.name: "settings_applications"; enabled: !backend.busy; onClicked: root.browseCategory("System", qsTr("System")) }
                MeoButton { Layout.fillWidth: true; text: qsTr("Utilities"); type: root.activeCategory === qsTr("Utilities") ? "filled" : "tonal"; icon.name: "build"; enabled: !backend.busy; onClicked: root.browseCategory("Utility", qsTr("Utilities")) }
            }

            MeoProgressBar {
                Layout.fillWidth: true
                visible: backend.busyAction === qsTr("search")
                indeterminate: true
            }

            MeoBanner {
                Layout.fillWidth: true
                visible: backend.errorMessage.length > 0 && !backend.busy
                title: qsTr("Could not load software")
                text: backend.errorMessage
                icon: "error"
                tone: "error"
            }

            RowLayout {
                Layout.fillWidth: true
                MeoText {
                    text: root.activeCategory.length > 0 ? root.activeCategory : qsTr("Recommended")
                    typeRole: "title"
                    typeSize: "medium"
                    emphasized: true
                    color: MeoTheme.contentOnSurface
                }
                Item { Layout.fillWidth: true }
                MeoIconButton {
                    icon.name: "refresh"
                    type: "tonal"
                    Accessible.name: qsTr("Refresh")
                    enabled: !backend.busy
                    onClicked: {
                        if (root.activeCategoryQuery.length > 0)
                            backend.search("category:" + root.activeCategoryQuery)
                        else
                            backend.loadRecommendations()
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 980 * MeoTheme.globalScale ? 3
                         : width >= 620 * MeoTheme.globalScale ? 2 : 1
                columnSpacing: 12 * MeoTheme.globalScale
                rowSpacing: 12 * MeoTheme.globalScale

                Repeater {
                    model: root.activeCategory.length > 0
                           ? backend.searchResults
                           : (backend.trendingApps.length > 0
                              ? backend.trendingApps
                              : backend.featuredApps)
                    delegate: StoreAppCard {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        app: modelData
                        onDetailsRequested: function(app) { root.detailsRequested(app) }
                    }
                }
            }

            MeoEmptyState {
                Layout.fillWidth: true
                visible: !backend.busy
                         && (root.activeCategory.length > 0
                             ? backend.searchResults.length === 0
                             : backend.trendingApps.length === 0
                               && backend.featuredApps.length === 0)
                icon: "explore"
                title: root.activeCategory.length > 0
                       ? qsTr("Nothing found in this category")
                       : qsTr("Nothing to explore yet")
                description: qsTr("Check your enabled software sources or try again after refreshing metadata.")
            }
        }
    }
}
