import QtQuick
import "Singletons"

/**
 * Compact audio spectrum: a row of bars whose heights follow the shared Cava
 * levels, centred vertically and eased so the motion stays smooth. Sized to sit
 * inside the rest pill beside the clock while media plays.
 */
Row {
    id: root

    property real s: 1
    property real maxH: 11 * s
    property real minH: 2 * s

    spacing: 2 * s

    Repeater {
        model: Cava.bars

        delegate: Rectangle {
            required property int index
            width: 2.4 * root.s
            anchors.verticalCenter: parent.verticalCenter
            radius: width / 2
            color: Theme.vermLit
            height: Math.max(root.minH, (index < Cava.values.length ? Cava.values[index] : 0) * root.maxH)
            Behavior on height { NumberAnimation { duration: 85; easing.type: Easing.OutQuad } }
        }
    }
}
