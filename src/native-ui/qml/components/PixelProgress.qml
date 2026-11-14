import QtQuick
import MeoUI 1.0

// Segmented pixel-style progress bar. `value` is a real 0..1 fraction from the
// backend; when `indeterminate` is set it shows a marching block window
// instead of pretending to know the percentage.
Item {
    id: root

    property real value: 0
    property bool indeterminate: false
    property bool failed: false
    property bool done: false
    property int blockSize: Math.round(10 * MeoTheme.globalScale)
    property int blockGap: Math.max(2, Math.round(2 * MeoTheme.globalScale))
    readonly property int blockCount: Math.max(8, Math.floor((width + blockGap) / (blockSize + blockGap)))
    readonly property color fillColor: failed ? MeoTheme.error : MeoTheme.primary
    // Smoothed value so blocks fill steadily between 250 ms polls.
    property real shown: 0
    property real marchPos: 0

    implicitHeight: blockSize
    height: implicitHeight
    Accessible.role: Accessible.ProgressBar
    Accessible.name: indeterminate ? qsTr("Working") : qsTr("%1%").arg(Math.round(value * 100))

    onValueChanged: shown = Math.max(0, Math.min(1, value))
    Component.onCompleted: shown = Math.max(0, Math.min(1, value))
    Behavior on shown { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

    NumberAnimation on marchPos {
        running: root.indeterminate && root.visible
        from: -4
        to: root.blockCount
        duration: 1400
        loops: Animation.Infinite
    }

    Row {
        spacing: root.blockGap
        Repeater {
            model: root.blockCount
            delegate: Rectangle {
                id: block
                required property int index
                width: root.blockSize
                height: root.blockSize
                radius: 0
                antialiasing: false
                color: fill > 0 ? root.fillColor : MeoTheme.secondaryContainer
                readonly property real cell: root.shown * root.blockCount
                readonly property real fill: root.indeterminate
                    ? ((index >= root.marchPos && index < root.marchPos + 4) ? 1 : 0)
                    : root.done ? 1 : Math.max(0, Math.min(1, cell - index))
                opacity: fill > 0 ? (0.4 + 0.6 * fill) : 1
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
        }
    }
}
