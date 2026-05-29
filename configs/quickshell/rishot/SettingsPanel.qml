// rishot — inline settings panel revealed when the toolbar gear expands. Shows the current
// screenshot hotkey (parsed from rishot.lua) and a Record button. Record -> listens for the next
// key chord -> maps it to a Hyprland keyname (lib/keymap.js) -> rewrites rishot.lua -> hyprctl reload
// -> updates the label live. Matches the Vermilion glass aesthetic; vermilion accent while listening.
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "lib/keymap.js" as Keymap

Item {
    id: panel
    property string luaPath: ""          // absolute path to rishot.lua
    property string hotkey: "—"          // current bind string, parsed from the file
    property bool listening: false       // true while waiting for a key chord

    readonly property color glassBorder: "#313a4d"
    readonly property color vermilion: "#e0563b"
    readonly property color idle: "#c4ccda"

    implicitWidth: content.implicitWidth + 16
    implicitHeight: content.implicitHeight

    // ---- read current hotkey on load ----
    FileView {
        id: reader
        path: panel.luaPath
        onLoaded: { var b = Keymap.parseBind(text()); if (b) panel.hotkey = b; }
    }

    // ---- write rewritten file, then reload Hyprland on success ----
    FileView {
        id: writer
        path: panel.luaPath
        atomicWrites: true
        onSaved: reloadProc.running = true
        onSaveFailed: (err) => console.log("rishot: rishot.lua write failed: " + err)
    }

    Process {
        id: reloadProc
        command: ["hyprctl", "reload"]
        onExited: (code) => console.log("rishot: hyprctl reload exit " + code)
    }

    // Commit a captured chord: update label, rewrite file, reload.
    function applyBind(bind) {
        panel.hotkey = bind;
        panel.listening = false;
        writer.setText(Keymap.luaFile(bind));
    }

    RowLayout {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        x: 8
        spacing: 10

        Text {
            text: "Hotkey: " + panel.hotkey
            color: panel.idle
            font.family: "JetBrains Mono"
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
        }

        Rectangle {
            id: recBtn
            Layout.preferredHeight: 28
            Layout.preferredWidth: recLabel.implicitWidth + 24
            radius: 6
            color: panel.listening ? panel.vermilion
                : (recHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06))
            border.color: panel.listening ? panel.vermilion : panel.glassBorder
            border.width: 1

            Text {
                id: recLabel
                anchors.centerIn: parent
                text: panel.listening ? "Press a key…" : "Record"
                color: panel.listening ? "#ffffff" : panel.idle
                font.family: "JetBrains Mono"
                font.pixelSize: 13
            }

            HoverHandler { id: recHover }
            TapHandler {
                onTapped: {
                    panel.listening = !panel.listening;
                    if (panel.listening) keyCatcher.forceActiveFocus();
                }
            }
        }
    }

    // Focused key sink, active only while listening. Captures the next complete chord.
    Item {
        id: keyCatcher
        focus: panel.listening
        Keys.onPressed: (e) => {
            if (!panel.listening) return;
            e.accepted = true;
            if (e.key === Qt.Key_Escape) { panel.listening = false; return; }
            var bind = Keymap.bindString(e.key, e.modifiers, e.text);
            if (bind !== null) panel.applyBind(bind);   // else: bare modifier, keep listening
        }
    }
}
