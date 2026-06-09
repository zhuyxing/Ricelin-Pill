import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "Singletons"

/**
 * Mixer surface content: header with DND / Keep-Awake chips and a row of four
 * vertical ink-faders wired to real hardware (brightness via ddcutil, vibrance
 * via nvibrant, volume and mic via Pipewire). Designed to fill the lower body
 * of the morphing pill.
 */
Item {
    id: root

    property real s: 1
    property bool active: false

    property int brightness: 75
    property int vibrance: 40

    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin/nvibrant-value"

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    function applyBrightness(pct) {
        var p = Math.max(5, Math.min(100, Math.round(pct)));
        Quickshell.execDetached(["bash", "-c", "timeout 3 ddcutil setvcp 10 " + p + " --bus 3 --noverify & timeout 3 ddcutil setvcp 10 " + p + " --bus 4 --noverify & wait"]);
    }

    function applyVibrance(pct) {
        var raw = Math.round(Math.max(0, Math.min(100, pct)) * 1023 / 100);
        Quickshell.execDetached(["nvibrant", String(raw), "0", String(raw)]);
    }

    function saveVibrance(pct) {
        Quickshell.execDetached(["bash", "-c", "mkdir -p \"$(dirname '" + root.stateFile + "')\" && echo " + Math.round(pct) + " > '" + root.stateFile + "'"]);
    }

    onActiveChanged: if (active) brRead.running = true

    Component.onCompleted: {
        var v = parseInt((vibState.text() || "40").trim());
        root.vibrance = isNaN(v) ? 40 : v;
    }

    PwObjectTracker {
        objects: [root.sink, root.source].filter(Boolean)
    }

    Process {
        id: brRead
        command: ["timeout", "3", "ddcutil", "getvcp", "10", "--bus", "3", "--brief"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var m = this.text.match(/C\s+(\d+)\s+/);
                if (m)
                    root.brightness = parseInt(m[1]);
            }
        }
    }

    FileView {
        id: vibState
        path: root.stateFile
        blockLoading: true
        printErrors: false
    }

    component Chip: Rectangle {
        id: chip
        property string glyph: ""
        property string label: ""
        property bool on: false
        signal toggled()

        radius: 9 * root.s
        implicitHeight: 24 * root.s
        width: chipRow.implicitWidth + 18 * root.s
        height: implicitHeight
        color: chip.on ? Theme.accent16 : Theme.tileBg
        border.width: 1
        border.color: chip.on ? Theme.accent45 : Theme.border

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6 * root.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.glyph
                color: chip.on ? Theme.vermLit : Theme.subtle
                font.family: Theme.font
                font.pixelSize: 12 * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: chip.on ? Theme.cream : Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
                font.weight: Font.DemiBold
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.on
                width: 5 * root.s
                height: 5 * root.s
                radius: width / 2
                color: Theme.vermLit
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.vermLit
                    shadowBlur: 0.9
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.toggled()
        }
    }

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 26 * root.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.s
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "調"
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 16 * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "MIXER"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7 * root.s
            Chip {
                glyph: "静"
                label: "Do Not Disturb"
                on: Store.dnd
                onToggled: Store.dnd = !Store.dnd
            }
            Chip {
                glyph: "覚"
                label: "Keep Awake"
                on: Store.keepAwake
                onToggled: Store.keepAwake = !Store.keepAwake
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: header.bottom
        anchors.topMargin: 11 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.hair
    }

    Row {
        anchors.top: divider.bottom
        anchors.topMargin: 14 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 130 * root.s
        spacing: 0

        VFader {
            width: parent.width / 4
            s: root.s
            icon: "sun"
            value: root.brightness / 100
            valueLabel: root.brightness + "%"
            onMoved: (v) => root.brightness = Math.round(v * 100)
            onCommitted: (v) => root.applyBrightness(v * 100)
        }
        VFader {
            width: parent.width / 4
            s: root.s
            icon: "monitor"
            value: root.vibrance / 100
            valueLabel: root.vibrance + "%"
            onMoved: (v) => root.vibrance = Math.round(v * 100)
            onCommitted: (v) => { root.applyVibrance(v * 100); root.saveVibrance(v * 100); }
        }
        VFader {
            width: parent.width / 4
            s: root.s
            icon: "speaker"
            value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
            valueLabel: Math.round((root.sink && root.sink.audio ? root.sink.audio.volume : 0) * 100) + "%"
            onMoved: (v) => { if (root.sink && root.sink.audio) root.sink.audio.volume = v; }
        }
        VFader {
            id: micFader
            width: parent.width / 4
            s: root.s
            icon: (root.source && root.source.audio && root.source.audio.muted) ? "mic-off" : "mic"
            value: root.source && root.source.audio ? root.source.audio.volume : 0
            valueLabel: (root.source && root.source.audio && root.source.audio.muted)
                ? "off"
                : (Math.round((root.source && root.source.audio ? root.source.audio.volume : 0) * 100) + "%")
            onMoved: (v) => { if (root.source && root.source.audio) root.source.audio.volume = v; }

            MouseArea {
                anchors.top: parent.bottom
                anchors.topMargin: -22 * root.s
                anchors.horizontalCenter: parent.horizontalCenter
                width: 24 * root.s
                height: 22 * root.s
                cursorShape: Qt.PointingHandCursor
                onClicked: { if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted; }
            }
        }
    }
}
