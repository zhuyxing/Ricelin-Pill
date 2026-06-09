import QtQuick
import QtQuick.Effects
import "Singletons"

/**
 * Vertical ink-fader. Thin track with a fill that rises from the bottom,
 * a soft tapered top, a draggable knob, a percent readout above and a
 * hand-drawn icon below. Value is normalised 0..1.
 */
Item {
    id: root

    property real s: 1
    property string icon: ""
    property real value: 0.5
    property string valueLabel: ""

    signal moved(real v)
    signal committed(real v)

    readonly property real trackH: 70 * s
    readonly property real trackW: 6 * s

    implicitWidth: 30 * s
    implicitHeight: trackH + 40 * s

    Text {
        id: readout
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        text: root.valueLabel
        color: Theme.subtle
        font.family: "monospace"
        font.pixelSize: 10 * root.s
        font.weight: Font.DemiBold
    }

    Item {
        id: trackArea
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: readout.bottom
        anchors.topMargin: 7 * root.s
        width: 22 * root.s
        height: root.trackH

        Rectangle {
            id: track
            anchors.centerIn: parent
            width: root.trackW
            height: root.trackH
            radius: root.trackW / 2
            color: Theme.trackBg
            border.width: 1
            border.color: Theme.border

            Rectangle {
                id: fill
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 1
                radius: root.trackW / 2
                height: Math.max(0, Math.min(1, root.value)) * (parent.height - 2)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.vermLit }
                    GradientStop { position: 1.0; color: Theme.verm }
                }
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 0.18
                    blurMax: 6
                }
            }
        }

        Rectangle {
            id: knob
            width: 14 * root.s
            height: 14 * root.s
            radius: width / 2
            color: Theme.knob
            border.width: 2
            border.color: Theme.vermLit
            x: (parent.width - width) / 2
            y: (1 - Math.max(0, Math.min(1, root.value))) * (root.trackH - height)

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.45)
                shadowBlur: 0.4
                shadowVerticalOffset: 1 * root.s
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -10 * root.s
            preventStealing: true
            function setFromY(my) {
                var inner = my - 10 * root.s - knob.height / 2;
                var span = root.trackH - knob.height;
                var v = 1 - Math.max(0, Math.min(1, inner / span));
                root.value = v;
                root.moved(v);
            }
            onPressed: (e) => setFromY(e.y)
            onPositionChanged: (e) => { if (pressed) setFromY(e.y); }
            onReleased: root.committed(root.value)
        }
    }

    Item {
        id: iconBox
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: trackArea.bottom
        anchors.topMargin: 9 * root.s
        width: 17 * root.s
        height: 17 * root.s

        Image {
            id: iconImg
            anchors.fill: parent
            source: Qt.resolvedUrl("assets/icons/" + root.icon + ".svg")
            sourceSize.width: 64
            sourceSize.height: 64
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            visible: false
        }
        MultiEffect {
            anchors.fill: iconImg
            source: iconImg
            colorization: 1.0
            colorizationColor: Theme.iconDim
        }
    }
}
