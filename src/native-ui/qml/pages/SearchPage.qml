pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import MeoUI 1.0

Item {
    id: root
    property string initialQuery: ""
    signal detailsRequested(var app)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28 * MeoTheme.globalScale
        spacing: 14 * MeoTheme.globalScale

        PageHeading {
            Layout.fillWidth: true
            title: qsTr("Search")
            subtitle: qsTr("Search all enabled OmniStore sources. Results keep their real source and variant metadata.")
            icon: "search"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * MeoTheme.globalScale

            MeoSearchBar {
                id: searchBar
                Layout.fillWidth: true
                Layout.maximumWidth: 780 * MeoTheme.globalScale
                text: root.initialQuery
                placeholder: qsTr("App or package name")
                trailingIcon: ""
                visualStyle: "pixel"
                onAccepted: function(query) {
                    if (query.trim().length > 0)
                        backend.search(query.trim())
                }
            }
            MeoButton {
                text: qsTr("Search")
                type: "filled"
                icon.name: "search"
                enabled: searchBar.text.trim().length > 0 && !backend.busy
                onClicked: backend.search(searchBar.text.trim())
            }
        }

        MeoProgressBar {
            Layout.fillWidth: true
            visible: backend.busyAction === qsTr("search")
            indeterminate: true
        }

        MeoBanner {
            Layout.fillWidth: true
            visible: backend.errorMessage.length > 0 && !backend.busy
            title: qsTr("Search failed")
            text: backend.errorMessage
            icon: "error"
            tone: "error"
        }

        GridView {
            id: results
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: backend.searchResults.length > 0
            clip: true
            model: backend.searchResults
            boundsBehavior: Flickable.StopAtBounds
            cellWidth: width >= 680 * MeoTheme.globalScale ? width / 2 : width
            cellHeight: 238 * MeoTheme.globalScale

            delegate: Item {
                required property var modelData
                width: results.cellWidth
                height: results.cellHeight

                StoreAppCard {
                    anchors.fill: parent
                    anchors.rightMargin: 10 * MeoTheme.globalScale
                    anchors.bottomMargin: 10 * MeoTheme.globalScale
                    app: parent.modelData
                    onDetailsRequested: function(app) { root.detailsRequested(app) }
                }
            }
        }

        MeoEmptyState {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: backend.searchResults.length === 0 && !backend.busy
            icon: searchBar.text.trim().length > 0 ? "search_off" : "search"
            title: searchBar.text.trim().length > 0 ? qsTr("No results") : qsTr("Find an app")
            description: searchBar.text.trim().length > 0
                         ? qsTr("Try another name, or check enabled sources in Settings.")
                         : qsTr("Search Pacman, AUR, Flatpak and any other enabled OmniStore sources from one place.")
        }
    }

    onInitialQueryChanged: {
        if (initialQuery.trim().length > 0)
            backend.search(initialQuery.trim())
    }
}
