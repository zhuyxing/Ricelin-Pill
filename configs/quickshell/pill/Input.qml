pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "lib/setInput.js" as SetInput
import "Singletons"

/**
 * 操 INPUT sub-surface: edits the pointer, keyboard and cursor settings that live
 * in the Hyprland Lua modules, writing each change straight back to its source so
 * the choice survives a restart. Pointer and keyboard fields rewrite
 * input.lua and reload Hyprland; sensitivity, repeat rate and repeat delay step
 * through a small −/value/+ control while accel profile and the scroll/numlock
 * switches use the shared segmented and toggle controls. Cursor size and theme
 * apply live through `hyprctl setcursor` with no reload, and persist by rewriting
 * the XCURSOR/HYPRCURSOR env lines and the autostart setcursor call. The theme
 * list is scanned from the installed icon themes that carry a `cursors/` folder.
 * Reached from the settings index; morphs back on the back chevron.
 */
SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: content.implicitHeight
    rows: []

    readonly property string inputPath: Quickshell.env("HOME") + "/.config/hypr/modules/input.lua"
    readonly property string envPath: Quickshell.env("HOME") + "/.config/hypr/modules/env.lua"
    readonly property string autostartPath: Quickshell.env("HOME") + "/.config/hypr/modules/autostart.lua"

    property real sensitivity: 0
    property string accelProfile: "flat"
    property bool naturalScroll: true
    property int repeatRate: 40
    property int repeatDelay: 400
    property bool numlock: true
    property int cursorSize: 24
    property string cursorTheme: "Bibata-Modern-Ice"
    property var cursorThemes: []
    property bool themeOpen: false

    readonly property var accelOptions: [
        { label: "Flat", value: "flat" },
        { label: "Adaptive", value: "adaptive" }
    ]

    onActiveChanged: {
        if (active) {
            inputFile.reload();
            envFile.reload();
            autostartFile.reload();
            seed();
            themeProc.running = true;
        } else {
            themeOpen = false;
            focusRowItem = null;
            kbIndex = -1;
        }
    }

    /**
     * Seeds every control from the live source files. Numbers fall back to the
     * defaults when a field is missing so a partially hand-edited config never
     * leaves a control blank.
     */
    function seed() {
        var inp = inputFile.text();
        var sens = parseFloat(SetInput.getField(inp, "sensitivity"));
        root.sensitivity = isNaN(sens) ? 0 : sens;
        var ap = SetInput.getField(inp, "accel_profile");
        root.accelProfile = ap.length > 0 ? ap : "flat";
        root.naturalScroll = SetInput.getField(inp, "natural_scroll") === "true";
        var rr = parseInt(SetInput.getField(inp, "repeat_rate"), 10);
        root.repeatRate = isNaN(rr) ? 40 : rr;
        var rd = parseInt(SetInput.getField(inp, "repeat_delay"), 10);
        root.repeatDelay = isNaN(rd) ? 400 : rd;
        root.numlock = SetInput.getField(inp, "numlock_by_default") === "true";

        var env = envFile.text();
        var cs = parseInt(SetInput.getField(env, "XCURSOR_SIZE"), 10);
        root.cursorSize = isNaN(cs) ? 24 : cs;
        var ct = SetInput.getField(env, "XCURSOR_THEME");
        root.cursorTheme = ct.length > 0 ? ct : "Bibata-Modern-Ice";
    }

    /**
     * Rewrites one input.lua field to `literal` (already formatted by the caller)
     * and reloads Hyprland so the change takes effect at once.
     */
    function writeInputField(name, literal) {
        var res = SetInput.setField(inputFile.text(), name, literal);
        if (!res.ok)
            return;
        inputWriter.setText(res.text);
        reloadProc.running = true;
    }

    /**
     * Applies a cursor theme/size pair live via `hyprctl setcursor`, then persists
     * it by rewriting the XCURSOR/HYPRCURSOR env lines and the autostart setcursor
     * call. No Hyprland reload is needed for the cursor.
     */
    function applyCursor(theme, size) {
        setcursorProc.theme = theme;
        setcursorProc.size = size;
        setcursorProc.running = true;

        var env = envFile.text();
        var e1 = SetInput.setEnv(env, "XCURSOR_THEME", theme);
        var e2 = SetInput.setEnv(e1.ok ? e1.text : env, "XCURSOR_SIZE", String(size));
        var e3 = SetInput.setEnv(e2.ok ? e2.text : (e1.ok ? e1.text : env), "HYPRCURSOR_SIZE", String(size));
        if (e3.ok || e2.ok || e1.ok)
            envWriter.setText(e3.ok ? e3.text : (e2.ok ? e2.text : e1.text));

        var auto = SetInput.setCursorLine(autostartFile.text(), theme, size);
        if (auto.ok)
            autostartWriter.setText(auto.text);
    }

    function clampSensitivity(v) {
        return Math.max(-1, Math.min(1, Math.round(v * 10) / 10));
    }

    FileView {
        id: inputFile
        path: root.inputPath
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: inputWriter
        path: root.inputPath
        atomicWrites: true
        printErrors: false
    }

    FileView {
        id: envFile
        path: root.envPath
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: envWriter
        path: root.envPath
        atomicWrites: true
        printErrors: false
    }

    FileView {
        id: autostartFile
        path: root.autostartPath
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: autostartWriter
        path: root.autostartPath
        atomicWrites: true
        printErrors: false
    }

    Process {
        id: reloadProc
        command: ["setsid", "-f", "sh", "-c", "sleep 0.4; hyprctl reload"]
    }

    Process {
        id: setcursorProc
        property string theme: ""
        property int size: 24
        command: ["hyprctl", "setcursor", theme, String(size)]
    }

    Process {
        id: themeProc
        command: ["sh", "-c", "for d in /usr/share/icons \"$HOME/.local/share/icons\" \"$HOME/.icons\"; do [ -d \"$d\" ] && for t in \"$d\"/*/; do [ -d \"$t/cursors\" ] && basename \"$t\"; done; done | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n").filter(function (l) { return l.trim().length > 0; });
                root.cursorThemes = lines;
            }
        }
    }

    component Stepper: Row {
        id: step

        property real value: 0
        property string display: ""
        signal stepped(int dir)

        spacing: 6 * root.s

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 26 * root.s
            height: 26 * root.s
            radius: Motion.rSmall * root.s
            color: minusArea.containsMouse ? Theme.frameBg : Theme.tileBg
            border.width: 1
            border.color: Theme.border
            Behavior on color { ColorAnimation { duration: Motion.fast } }

            Text {
                anchors.centerIn: parent
                text: "−"
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 14 * root.s
                font.weight: Font.Bold
            }

            MouseArea {
                id: minusArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: step.stepped(-1)
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 44 * root.s
            horizontalAlignment: Text.AlignHCenter
            text: step.display
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12 * root.s
            font.weight: Font.DemiBold
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 26 * root.s
            height: 26 * root.s
            radius: Motion.rSmall * root.s
            color: plusArea.containsMouse ? Theme.frameBg : Theme.tileBg
            border.width: 1
            border.color: Theme.border
            Behavior on color { ColorAnimation { duration: Motion.fast } }

            Text {
                anchors.centerIn: parent
                text: "+"
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 14 * root.s
                font.weight: Font.Bold
            }

            MouseArea {
                id: plusArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: step.stepped(1)
            }
        }
    }

    component GroupLabel: Text {
        topPadding: 16 * root.s
        bottomPadding: 6 * root.s
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 8.5 * root.s
        font.weight: Font.Bold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.2 * root.s
    }

    component FieldRow: Item {
        id: frow
        property string label: ""
        default property alias control: ctrl.data

        width: parent ? parent.width : 0
        height: 34 * root.s

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: frow.label
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12.5 * root.s
            font.weight: Font.Medium
        }

        Item {
            id: ctrl
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    Column {
        id: content
        z: 100
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0
        height: root.height + root.mBottom * root.s
        clip: true

        SettingsHeader {
            s: root.s
            glyph: "操"
            title: "INPUT"
            showBack: true
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 12 * root.s
            spacing: 0

            GroupLabel { text: "Pointer" }

            FieldRow {
                label: "Sensitivity"
                Stepper {
                    value: root.sensitivity
                    display: root.sensitivity.toFixed(1)
                    onStepped: (dir) => {
                        var next = root.clampSensitivity(root.sensitivity + dir * 0.1);
                        if (next === root.sensitivity)
                            return;
                        root.sensitivity = next;
                        root.writeInputField("sensitivity", String(next));
                    }
                }
            }

            FieldRow {
                label: "Acceleration"
                SettingsSeg {
                    s: root.s
                    options: root.accelOptions
                    value: root.accelProfile
                    onPicked: (v) => {
                        root.accelProfile = v;
                        root.writeInputField("accel_profile", "\"" + v + "\"");
                    }
                }
            }

            FieldRow {
                label: "Natural scroll"
                LinkToggle {
                    s: root.s
                    on: root.naturalScroll
                    onToggled: {
                        root.naturalScroll = !root.naturalScroll;
                        root.writeInputField("natural_scroll", root.naturalScroll ? "true" : "false");
                    }
                }
            }

            GroupLabel { text: "Keyboard" }

            FieldRow {
                label: "Repeat rate"
                Stepper {
                    value: root.repeatRate
                    display: String(root.repeatRate)
                    onStepped: (dir) => {
                        var next = Math.max(1, Math.min(100, root.repeatRate + dir * 5));
                        if (next === root.repeatRate)
                            return;
                        root.repeatRate = next;
                        root.writeInputField("repeat_rate", String(next));
                    }
                }
            }

            FieldRow {
                label: "Repeat delay"
                Stepper {
                    value: root.repeatDelay
                    display: String(root.repeatDelay)
                    onStepped: (dir) => {
                        var next = Math.max(100, Math.min(2000, root.repeatDelay + dir * 50));
                        if (next === root.repeatDelay)
                            return;
                        root.repeatDelay = next;
                        root.writeInputField("repeat_delay", String(next));
                    }
                }
            }

            FieldRow {
                label: "Numlock on boot"
                LinkToggle {
                    s: root.s
                    on: root.numlock
                    onToggled: {
                        root.numlock = !root.numlock;
                        root.writeInputField("numlock_by_default", root.numlock ? "true" : "false");
                    }
                }
            }

            GroupLabel { text: "Cursor" }

            FieldRow {
                label: "Size"
                Stepper {
                    value: root.cursorSize
                    display: String(root.cursorSize)
                    onStepped: (dir) => {
                        var next = Math.max(12, Math.min(96, root.cursorSize + dir));
                        if (next === root.cursorSize)
                            return;
                        root.cursorSize = next;
                        root.applyCursor(root.cursorTheme, next);
                    }
                }
            }

            Item { width: 1; height: 8 * root.s }

            DisplayPicker {
                width: parent.width
                s: root.s
                label: "Theme"
                options: root.cursorThemes.map(function (t) { return { label: t, value: t }; })
                value: root.cursorTheme
                open: root.themeOpen
                onRequestToggle: root.themeOpen = !root.themeOpen
                onPicked: (v) => {
                    root.cursorTheme = v;
                    root.themeOpen = false;
                    root.applyCursor(v, root.cursorSize);
                }
            }

            Item { width: 1; height: 10 * root.s }
        }
    }
}
