import QtQuick
import QtTest
import "../qml/pages" as Pages

Item {
    width: 1000
    height: 720

    ListModel {
        id: applications
        ListElement {
            name: "OmniStore"
            sourceName: "Pacman"
            sizeText: "4.0 MiB"
        }
    }

    Pages.LibraryPage {
        id: libraryPage
        width: 700
        height: 560
        usageSummary: ({
            "available": true,
            "applicationCount": 1,
            "knownSizeText": "4.0 MiB",
            "sourceCount": 1,
            "error": ""
        })
        applicationModel: applications
    }

    Pages.DiscoverUnavailablePage {
        id: discoverPage
        x: 720
        width: 260
        height: 560
    }

    TestCase {
        name: "NativeShell"
        when: windowShown

        function test_libraryUsesTheReadOnlySummaryAndBorderlessFilledSurface() {
            verify(libraryPage.hasAvailableUsage)
            compare(libraryPage.applicationCount, 1)
            const summary = findChild(libraryPage, "nativeLibraryReadOnlySummary")
            verify(summary !== null)
            compare(summary.type, "filled")
        }

        function test_libraryDescribesItsReadOnlyPurposeToAssistiveTechnology() {
            compare(libraryPage.Accessible.role, Accessible.Pane)
            compare(libraryPage.Accessible.name, "Installed library")
            verify(libraryPage.Accessible.description.indexOf("read-only") !== -1)
        }

        function test_discoveryExplicitlyExistsAsAnUnavailablePhase() {
            verify(discoverPage.visible)
            compare(discoverPage.objectName, "nativeDiscoverUnavailablePage")
            compare(discoverPage.Accessible.role, Accessible.Pane)
            compare(discoverPage.Accessible.name, "Discover")
            verify(discoverPage.Accessible.description.indexOf("Catalog") !== -1)
        }
    }
}
