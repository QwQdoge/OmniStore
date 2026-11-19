import QtQuick
import MeoUI 1.0
// Present only on a Meo desktop. Everywhere else this file fails to load and
// Main.qml keeps MeoUI's built-in palette (light/dark follows the OS).
import Meo.System 1.0

Item {
    id: root
    signal changed()

    SystemPalette { id: desktopPalette }

    function sync() {
        const lightScheme = typeof MaterialColors.currentScheme === "function"
            ? MaterialColors.currentScheme(false) : MaterialColors.schemeFor(desktopPalette.highlight, false)
        const darkScheme = typeof MaterialColors.currentScheme === "function"
            ? MaterialColors.currentScheme(true) : MaterialColors.schemeFor(desktopPalette.highlight, true)
        MeoTheme.applyDynamicColorSchemes(lightScheme, darkScheme, "kde-" + MaterialColors.sourceId())
    }

    Connections {
        target: MaterialColors
        ignoreUnknownSignals: true
        function onSchemeChanged() { root.sync(); root.changed() }
    }
}
