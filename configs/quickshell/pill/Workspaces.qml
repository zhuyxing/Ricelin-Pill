pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "Singletons"

/**
 * Live workspace dots for one monitor. Every workspace Hyprland reports on this
 * output is a dot — no numbers, no icons. The active one is a larger filled
 * vermillion dot; the rest are small and dim, brightening on hover. Clicking a
 * dot focuses that workspace via the native Hyprland-lua dispatcher. The set and
 * the active marker track the live Hyprland model, with no hardcoded ranges.
 */
Item {
    id: workspaces

    property string screenName: ""
    property real s: 1

    readonly property var list: {
        var out = [];
        var all = Hyprland.workspaces.values;
        for (var i = 0; i < all.length; i++) {
            var w = all[i];
            if (w && w.monitor && w.monitor.name === workspaces.screenName)
                out.push(w);
        }
        out.sort(function (a, b) { return a.id - b.id; });
        return out;
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4 * workspaces.s

        Repeater {
            model: workspaces.list

            delegate: Item {
                id: slot

                required property var modelData

                Layout.preferredWidth: 14 * workspaces.s
                Layout.preferredHeight: 22 * workspaces.s

                Rectangle {
                    anchors.centerIn: parent
                    width: (slot.modelData.active ? 8 : 6) * workspaces.s
                    height: width
                    radius: width / 2
                    color: slot.modelData.active ? Theme.vermLit
                        : (slot.modelData.urgent ? Theme.verm : Theme.cream)
                    opacity: slot.modelData.active ? 1.0
                        : (slot.modelData.urgent ? 0.9 : (area.containsMouse ? 0.7 : 0.32))
                    Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch('hl.dsp.focus({workspace="' + slot.modelData.name + '"})')
                }
            }
        }
    }
}
