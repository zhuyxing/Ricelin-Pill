import QtQuick
import Quickshell

Item {
    id: clock

    property real s: 1
    property var barWindow

    readonly property color cream: "#e6d6cb"
    readonly property color dim: "#8a7d74"

    readonly property var deLocale: Qt.locale("de_DE")

    implicitWidth: layout.implicitWidth
    implicitHeight: parent ? parent.height : 34 * s

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    Row {
        id: layout
        anchors.centerIn: parent
        spacing: 9 * clock.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(sysClock.date, "HH:mm")
            color: clock.cream
            font.family: "Inter"
            font.pixelSize: 13 * clock.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 13 * clock.s
            color: Qt.rgba(150 / 255, 172 / 255, 212 / 255, 0.16)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: sysClock.date.toLocaleDateString(clock.deLocale, "ddd dd MMM").toUpperCase()
            color: clock.dim
            font.family: "Inter"
            font.pixelSize: 10 * clock.s
            font.weight: Font.Medium
            font.letterSpacing: 1.2 * clock.s
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: calendar.open = !calendar.open
    }

    Calendar {
        id: calendar
        s: clock.s
        anchorWindow: clock.barWindow
    }
}
