pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "Singletons"

/**
 * 相 APPEARANCE sub-surface: the clock format and seconds, the Japanese-glyph
 * toggle that gates every surface header, the palette mode (static flame, dynamic
 * per-wallpaper, or a manually chosen hue), the UI scale and a reduce-motion
 * switch. Reached from the settings index and morphs back to it on an empty click
 * or the back chevron.
 *
 * Manual palette mode reveals a rainbow hue strip and a dark/light choice; moving
 * either rebuilds the rice colour set from that hue through wallcolors.py --hue
 * and reloads Hyprland and the terminal, debounced so a drag does not spawn a
 * build per pixel.
 */
SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: content.implicitHeight

    property string hueArg: String(Math.round(Flags.manualHue))
    property string modeArg: Flags.manualDark ? "dark" : "light"

    function applyManual() {
        hueArg = String(Math.round(Flags.manualHue));
        modeArg = Flags.manualDark ? "dark" : "light";
        applyTimer.restart();
    }

    Timer {
        id: applyTimer
        interval: 260
        repeat: false
        onTriggered: paletteProc.running = true
    }

    Process {
        id: paletteProc
        command: ["sh", "-c",
            "python3 \"$HOME/.config/hypr/scripts/wallcolors.py\" --hue \"$1\" \"$2\" && hyprctl reload >/dev/null 2>&1; busctl --user call com.mitchellh.ghostty /com/mitchellh/ghostty org.gtk.Actions Activate \"sava{sv}\" reload-config 0 0 >/dev/null 2>&1 || true",
            "sh", root.hueArg, root.modeArg]
    }

    Connections {
        target: Flags
        function onManualHueChanged() {
            if (Flags.paletteMode === "manual")
                root.applyManual();
        }
    }

    rows: [
        { item: timeRow, kind: "seg", vals: [false, true], get: function () { return Flags.time12h; }, set: function (v) { Flags.time12h = v; } },
        { item: secRow, kind: "toggle", get: function () { return Flags.clockSeconds; }, set: function (v) { Flags.clockSeconds = v; } },
        { item: glyphRow, kind: "toggle", get: function () { return Flags.showGlyphs; }, set: function (v) { Flags.showGlyphs = v; } },
        { item: paletteRow, kind: "seg", vals: ["static", "dynamic", "manual"], get: function () { return Flags.paletteMode; }, set: function (v) { Flags.paletteMode = v; if (v === "manual") root.applyManual(); } },
        { item: scaleRow, kind: "seg", vals: [0.9, 1.0, 1.1, 1.25], get: function () { return Flags.uiScale; }, set: function (v) { Flags.uiScale = v; } },
        { item: motionRow, kind: "toggle", get: function () { return Flags.reduceMotion; }, set: function (v) { Flags.reduceMotion = v; } },
        { item: fontRow, kind: "nav", surface: "fontpicker" }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "相"
            title: "APPEARANCE"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: timeRow
            surface: root
            name: "Time format"
            sub: "24-hour stays the default"

            SettingsSeg {
                s: root.s
                options: [{ label: "24H", value: false }, { label: "12H", value: true }]
                value: Flags.time12h
                onPicked: (v) => Flags.time12h = v
            }
        }

        SettingsRow {
            id: secRow
            surface: root
            name: "Clock seconds"
            sub: "Show :SS in the pill clock"

            LinkToggle {
                s: root.s
                on: Flags.clockSeconds
                onToggled: Flags.clockSeconds = !Flags.clockSeconds
            }
        }

        SettingsRow {
            id: glyphRow
            surface: root
            name: "Japanese glyphs"
            sub: "Kanji on surface headers (蓄 BATTERY…). Off swaps for plain labels."

            LinkToggle {
                s: root.s
                on: Flags.showGlyphs
                onToggled: Flags.showGlyphs = !Flags.showGlyphs
            }
        }

        SettingsRow {
            id: paletteRow
            surface: root
            name: "Palette"
            sub: "Static flame · Dynamic per wallpaper · Manual your hue"

            SettingsSeg {
                s: root.s
                options: [{ label: "Static", value: "static" }, { label: "Dynamic", value: "dynamic" }, { label: "Manual", value: "manual" }]
                value: Flags.paletteMode
                onPicked: (v) => { Flags.paletteMode = v; if (v === "manual") root.applyManual(); }
            }
        }

        /**
         * Manual hue editor, folded shut unless the palette is on Manual. Holds a
         * rainbow strip with a draggable thumb, a live swatch of the resolved
         * accent, and a dark/light choice. The strip is mouse-driven and stays out
         * of the keyboard row registry.
         */
        Item {
            id: manualSection
            width: parent.width
            height: Flags.paletteMode === "manual" ? manualCol.implicitHeight : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

            Column {
                id: manualCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12 * root.s
                anchors.rightMargin: 12 * root.s
                topPadding: 4 * root.s
                bottomPadding: 16 * root.s
                spacing: 14 * root.s

                Item {
                    width: parent.width
                    height: 14 * root.s

                    Rectangle {
                        id: hueStrip
                        anchors.fill: parent
                        radius: 7 * root.s
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.hsla(0.0, 0.7, 0.5, 1) }
                            GradientStop { position: 1 / 6; color: Qt.hsla(1 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 2 / 6; color: Qt.hsla(2 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 3 / 6; color: Qt.hsla(3 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 4 / 6; color: Qt.hsla(4 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 5 / 6; color: Qt.hsla(5 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 1.0; color: Qt.hsla(1.0, 0.7, 0.5, 1) }
                        }

                        Rectangle {
                            id: hueThumb
                            width: 16 * root.s
                            height: 16 * root.s
                            radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            x: (Flags.manualHue / 359) * (hueStrip.width - width)
                            color: Qt.hsla(Flags.manualHue / 360, 0.7, 0.5, 1)
                            border.width: 2.5 * root.s
                            border.color: Theme.cream
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            function setHue(mx) {
                                Flags.manualHue = Math.round(Math.max(0, Math.min(1, mx / hueStrip.width)) * 359);
                            }
                            onPressed: (mouse) => setHue(mouse.x)
                            onPositionChanged: (mouse) => setHue(mouse.x)
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 12 * root.s

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34 * root.s
                        height: 34 * root.s
                        radius: 9 * root.s
                        color: Qt.hsla(Flags.manualHue / 360, 0.5, Flags.manualDark ? 0.5 : 0.62, 1)
                        border.width: 1
                        border.color: Theme.border
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3 * root.s

                        Text {
                            text: "Accent hue"
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: Math.round(Flags.manualHue) + "° · " + (Flags.manualDark ? "dark surfaces" : "light surfaces")
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 10.5 * root.s
                            font.features: { "tnum": 1 }
                        }
                    }

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x
                        height: tone.implicitHeight

                        SettingsSeg {
                            id: tone
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            s: root.s
                            options: [{ label: "Dark", value: true }, { label: "Light", value: false }]
                            value: Flags.manualDark
                            onPicked: (v) => { Flags.manualDark = v; root.applyManual(); }
                        }
                    }
                }
            }
        }

        SettingsRow {
            id: scaleRow
            surface: root
            name: "UI scale"
            sub: "Density of the whole pill"

            SettingsSeg {
                s: root.s
                options: [{ label: "90%", value: 0.9 }, { label: "100%", value: 1.0 }, { label: "110%", value: 1.1 }, { label: "125%", value: 1.25 }]
                value: Flags.uiScale
                onPicked: (v) => Flags.uiScale = v
            }
        }

        SettingsRow {
            id: motionRow
            surface: root
            name: "Reduce motion"
            sub: "Snappier transitions, less float"

            LinkToggle {
                s: root.s
                on: Flags.reduceMotion
                onToggled: Flags.reduceMotion = !Flags.reduceMotion
            }
        }

        SettingsRow {
            id: fontRow
            surface: root
            name: "Font"
            sub: Flags.uiFont.length > 0 ? Flags.uiFont : "Inter"
            last: true

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === fontRow ? Theme.cream : Theme.iconDim
                stroke: 1.9
            }
        }
    }
}
