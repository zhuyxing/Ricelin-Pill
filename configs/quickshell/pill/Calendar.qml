pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Singletons"

/**
 * Calendar surface content: a header with the month/year label and prev/next
 * navigation, weekday headers and a 6x7 day grid with the live current date
 * carrying the warm accent fill. Mirrors the Mixer's role — it fills the lower
 * body of the morphing pill rather than living in its own window. The view date
 * is reset to the real "today" (via SystemClock) every time the surface opens.
 */
Item {
    id: root

    property real s: 1
    property bool active: false

    readonly property var loc: Qt.locale("en_US")

    property date today: sysClock.date
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    function firstWeekdayOffset(year, month) {
        var d = new Date(year, month, 1).getDay();
        return (d + 6) % 7;
    }

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    function isToday(day) {
        return day === today.getDate()
            && viewMonth === today.getMonth()
            && viewYear === today.getFullYear();
    }

    function shiftMonth(delta) {
        var m = viewMonth + delta;
        var y = viewYear;
        while (m < 0) { m += 12; y -= 1; }
        while (m > 11) { m -= 12; y += 1; }
        viewMonth = m;
        viewYear = y;
    }

    function resetToday() {
        today = sysClock.date;
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
    }

    onActiveChanged: if (active) resetToday()

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 24 * root.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "暦"
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 16 * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.loc.standaloneMonthName(root.viewMonth, Locale.LongFormat)
                    + " " + root.viewYear
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.0 * root.s
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2 * root.s

            Repeater {
                model: [-1, 1]

                Rectangle {
                    id: nav
                    required property int modelData
                    width: 22 * root.s
                    height: 22 * root.s
                    radius: 6 * root.s
                    color: navArea.containsMouse ? Theme.slotBg : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: nav.modelData < 0 ? "‹" : "›"
                        color: Theme.vermLit
                        font.family: Theme.font
                        font.pixelSize: 15 * root.s
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: navArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.shiftMonth(nav.modelData)
                    }
                }
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: header.bottom
        anchors.topMargin: 9 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.hair
    }

    Row {
        id: weekdays
        anchors.top: divider.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right

        Repeater {
            model: 7

            Item {
                id: wd
                required property int index
                width: weekdays.width / 7
                height: 16 * root.s

                Text {
                    anchors.centerIn: parent
                    text: root.loc.standaloneDayName((wd.index + 1) % 7, Locale.NarrowFormat)
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.Medium
                    font.letterSpacing: 0.5 * root.s
                }
            }
        }
    }

    Grid {
        id: grid
        anchors.top: weekdays.bottom
        anchors.topMargin: 4 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        columns: 7
        rowSpacing: 2 * root.s
        columnSpacing: 0

        Repeater {
            model: 42

            Item {
                id: cell
                required property int index
                width: grid.width / 7
                height: 24 * root.s

                readonly property int dayNum: index - root.firstWeekdayOffset(root.viewYear, root.viewMonth) + 1
                readonly property bool inMonth: dayNum >= 1 && dayNum <= root.daysInMonth(root.viewYear, root.viewMonth)
                readonly property bool current: inMonth && root.isToday(dayNum)

                Rectangle {
                    anchors.centerIn: parent
                    width: 22 * root.s
                    height: 22 * root.s
                    radius: 6 * root.s
                    visible: cell.current

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.vermLit }
                        GradientStop { position: 1.0; color: Theme.vermDeep }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: cell.inMonth
                    text: cell.dayNum
                    color: cell.current ? Theme.bright : Theme.cream
                    opacity: cell.current ? 1.0 : 0.85
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: cell.current ? Font.DemiBold : Font.Normal
                    font.features: { "tnum": 1 }
                }
            }
        }
    }
}
