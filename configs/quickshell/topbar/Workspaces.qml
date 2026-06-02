pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Hyprland

Item {
    id: workspaces

    property string screenName: ""
    property real s: 1

    readonly property color verm: "#c0442b"
    readonly property color vermDeep: "#a3371f"
    readonly property color vermLit: "#e0563b"
    readonly property color cream: "#e6d6cb"
    readonly property color white: "#fff6f0"
    readonly property color slotBg: "#2c1f19"
    readonly property color slotBorder: "#3a291f"

    readonly property var iconMap: ({
        "1": "browser",
        "2": "terminal",
        "3": "files",
        "4": "generic",
        "5": "spotify",
        "6": "code",
        "7": "discord",
        "8": "generic",
        "9": "generic",
        "10": "generic"
    })

    readonly property var range: {
        if (screenName === "DP-1") return [1, 2, 3, 4, 5];
        if (screenName === "HDMI-A-1") return [6, 7, 8, 9, 10];
        return [];
    }

    readonly property string activeName: {
        var mons = Hyprland.monitors.values;
        for (var i = 0; i < mons.length; i++)
            if (mons[i].name === screenName)
                return mons[i].activeWorkspace ? mons[i].activeWorkspace.name : "";
        return "";
    }

    function occupied(name) {
        var ws = Hyprland.workspaces.values;
        for (var i = 0; i < ws.length; i++)
            if (ws[i].name === name)
                return ws[i].toplevels && ws[i].toplevels.values.length > 0;
        return false;
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5 * workspaces.s

        Repeater {
            model: workspaces.range

            delegate: Item {
                id: slot

                required property var modelData

                readonly property string wsName: String(modelData)
                readonly property bool isActive: workspaces.activeName === wsName
                readonly property bool isOccupied: workspaces.occupied(wsName)
                readonly property color tint: isActive ? workspaces.white : workspaces.cream
                readonly property real iconOpacity: isActive || isOccupied ? 1.0 : 0.32

                Layout.preferredWidth: 23 * workspaces.s
                Layout.preferredHeight: 23 * workspaces.s

                Rectangle {
                    id: bg
                    anchors.fill: parent
                    radius: 6
                    color: workspaces.slotBg
                    border.width: 1
                    border.color: workspaces.slotBorder

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        visible: slot.isActive
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: workspaces.vermLit }
                            GradientStop { position: 1.0; color: workspaces.vermDeep }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        visible: slot.isActive
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.18)
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    visible: slot.isActive
                    color: workspaces.verm
                    z: -1
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: workspaces.verm
                        shadowBlur: 0.9
                        shadowVerticalOffset: 0
                        shadowHorizontalOffset: 0
                    }
                }

                Image {
                    id: glyph
                    anchors.centerIn: parent
                    width: 14 * workspaces.s
                    height: 14 * workspaces.s
                    sourceSize.width: 96
                    sourceSize.height: 96
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    visible: false
                    source: Qt.resolvedUrl("assets/icons/" + (workspaces.iconMap[slot.wsName] || "generic") + ".svg")
                }

                MultiEffect {
                    anchors.fill: glyph
                    source: glyph
                    colorization: 1.0
                    colorizationColor: slot.tint
                    opacity: slot.iconOpacity
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch('hl.dsp.focus({workspace="' + slot.wsName + '"})')
                }
            }
        }
    }
}
