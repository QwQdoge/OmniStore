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

        ListView {
            id: results
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8 * MeoTheme.globalScale
            model: backend.searchResults
            boundsBehavior: Flickable.StopAtBounds

            delegate: AppRow {
                required property var modelData
                width: ListView.view.width
                app: modelData
                onDetailsRequested: function(app) { root.detailsRequested(app) }
            }

            footer: Item { width: 1; height: 20 * MeoTheme.globalScale }
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
