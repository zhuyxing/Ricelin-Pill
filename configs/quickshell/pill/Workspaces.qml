pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "Singletons"

/**
 * Workspace dots for one monitor. A fixed per-monitor range always shows every
 * dot — DP-1 gets [1,2,3,4,5], HDMI-A-1 gets [6,7,8,9,10] — no numbers, no
 * icons. The active one is a larger filled vermillion dot; the rest are small
 * and dim, brightening on hover. Clicking a dot focuses that workspace via the
 * native Hyprland-lua dispatcher. The active marker tracks the monitor's live
 * active workspace name from the Hyprland model.
 */
Item {
    id: workspaces

    property string screenName: ""
    property real s: 1
    property real dotActive: 8 * s
    property real dotIdle: 6 * s
    property real gap: 4 * s

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

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: workspaces.gap

        Repeater {
            model: workspaces.range

            delegate: Item {
                id: slot

                required property var modelData

                readonly property string wsName: String(modelData)
                readonly property bool isActive: workspaces.activeName === wsName

                Layout.preferredWidth: workspaces.dotActive
                Layout.preferredHeight: Math.max(22 * workspaces.s, workspaces.dotActive)

                Rectangle {
                    anchors.centerIn: parent
                    width: slot.isActive ? workspaces.dotActive : workspaces.dotIdle
                    height: width
                    radius: width / 2
                    color: slot.isActive ? Theme.vermLit : Theme.cream
                    opacity: slot.isActive ? 1.0 : (area.containsMouse ? 0.7 : 0.32)
                    Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch('hl.dsp.focus({workspace="' + slot.wsName + '"})')
                }
            }
        }
    }
}
