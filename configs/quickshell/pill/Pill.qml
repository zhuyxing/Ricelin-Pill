pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import "Singletons"

/**
 * The washi pill body — a single element that carries every state. Its width and
 * height are driven by `state` (rest, hover/pinned, mixer, calendar) and settled
 * with a critically-damped, no-overshoot easing, so each surface grows out of the
 * pill in place rather than appearing as a separate window. The four surfaces are
 * absolutely stacked and cross-fade, exactly as the approved prototype does.
 *
 * Hover is read by a passive HoverHandler and pin by a passive TapHandler, so
 * neither blocks pointer events from the interactive surfaces stacked above them:
 * workspace dots, the clock target, tray icons and the mixer faders all receive
 * their own clicks and drags directly.
 */
Item {
    id: pill

    property real s: 1
    property string screenName: ""
    property var barWindow
    property string surface: ""

    property bool hovered: false
    property bool pinned: false

    readonly property bool mixerOpen: surface === "mixer"
    readonly property bool calendarOpen: surface === "calendar"
    readonly property bool surfaceOpen: surface.length > 0
    readonly property bool expanded: surfaceOpen || pinned || hovered

    readonly property real restW: 160 * s
    readonly property real restH: 38 * s
    readonly property real hoverW: Math.max(470 * s, ws.implicitWidth + 290 * s)
    readonly property real hoverH: 54 * s
    readonly property real mixerW: 438 * s
    readonly property real mixerH: 244 * s
    readonly property real calendarW: 318 * s
    readonly property real calendarH: 262 * s
    readonly property real restCorner: 18 * s
    readonly property real openCorner: 22 * s

    readonly property string mode: calendarOpen ? "calendar"
        : (mixerOpen ? "mixer" : (expanded ? "hover" : "rest"))

    signal requestSurface(string name)
    signal requestClose()

    onSurfaceOpenChanged: if (surfaceOpen) pinned = false

    QtObject {
        id: clock
        readonly property var loc: Qt.locale("en_US")
        readonly property var now: sysClock.date
        readonly property string hhmm: Qt.formatTime(now, "HH:mm")
        readonly property string date: loc.toString(now, "ddd d MMM")
    }

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    property real cometFrac: 0

    NumberAnimation {
        target: pill
        property: "cometFrac"
        from: 0
        to: 1
        duration: 60000
        loops: Animation.Infinite
        running: !pill.expanded
    }

    property real morphRadius: restCorner

    width: restW
    height: restH

    states: [
        State { name: "rest"; PropertyChanges { pill.width: pill.restW; pill.height: pill.restH; pill.morphRadius: pill.restCorner } },
        State { name: "hover"; PropertyChanges { pill.width: pill.hoverW; pill.height: pill.hoverH; pill.morphRadius: pill.restCorner } },
        State { name: "mixer"; PropertyChanges { pill.width: pill.mixerW; pill.height: pill.mixerH; pill.morphRadius: pill.openCorner } },
        State { name: "calendar"; PropertyChanges { pill.width: pill.calendarW; pill.height: pill.calendarH; pill.morphRadius: pill.openCorner } }
    ]
    state: mode

    transitions: Transition {
        NumberAnimation {
            properties: "width,height,morphRadius"
            duration: 420
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: pill.morphRadius
        border.width: 1
        border.color: Theme.border
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.5)
            shadowBlur: 0.7
            shadowVerticalOffset: 3 * pill.s
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.leftMargin: body.radius * 0.6
            anchors.rightMargin: body.radius * 0.6
            height: 1
            color: Theme.sheen
        }
    }

    Shape {
        id: comet
        anchors.fill: parent
        anchors.margins: 1
        visible: opacity > 0.01
        opacity: pill.expanded ? 0 : 1
        preferredRendererType: Shape.CurveRenderer
        Behavior on opacity { NumberAnimation { duration: 180 } }

        readonly property real perim: 2 * (width - 2 * pill.restCorner) + 2 * (height - 2 * pill.restCorner) + 2 * Math.PI * pill.restCorner
        readonly property real seg: 0.16

        ShapePath {
            strokeColor: Theme.vermLit
            strokeWidth: 2 * pill.s
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            strokeStyle: ShapePath.DashLine
            dashPattern: [comet.seg * comet.perim / (2 * pill.s), (1 - comet.seg) * comet.perim / (2 * pill.s)]
            dashOffset: -pill.cometFrac * comet.perim / (2 * pill.s)

            startX: pill.restCorner
            startY: 1
            PathLine { x: comet.width - pill.restCorner; y: 1 }
            PathArc { x: comet.width - 1; y: pill.restCorner; radiusX: pill.restCorner - 1; radiusY: pill.restCorner - 1 }
            PathLine { x: comet.width - 1; y: comet.height - pill.restCorner }
            PathArc { x: comet.width - pill.restCorner; y: comet.height - 1; radiusX: pill.restCorner - 1; radiusY: pill.restCorner - 1 }
            PathLine { x: pill.restCorner; y: comet.height - 1 }
            PathArc { x: 1; y: comet.height - pill.restCorner; radiusX: pill.restCorner - 1; radiusY: pill.restCorner - 1 }
            PathLine { x: 1; y: pill.restCorner }
            PathArc { x: pill.restCorner; y: 1; radiusX: pill.restCorner - 1; radiusY: pill.restCorner - 1 }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.5
            blurMax: 12
        }
    }

    HoverHandler {
        id: hoverHandler
        onHoveredChanged: pill.hovered = hovered
    }

    TapHandler {
        enabled: !pill.surfaceOpen
        gesturePolicy: TapHandler.WithinBounds
        onTapped: pill.pinned = !pill.pinned
    }

    Item {
        id: rest
        anchors.fill: parent
        opacity: pill.expanded ? 0 : 1
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Row {
            anchors.centerIn: parent
            spacing: 9 * pill.s
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "時"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 15 * pill.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: clock.hhmm
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 16 * pill.s
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }
    }

    Item {
        id: hover
        anchors.fill: parent
        anchors.leftMargin: 20 * pill.s
        anchors.rightMargin: 20 * pill.s
        opacity: (pill.expanded && !pill.surfaceOpen) ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Workspaces {
            id: ws
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            screenName: pill.screenName
            s: pill.s
            enabled: pill.expanded && !pill.surfaceOpen
        }

        Column {
            id: hoverClock
            anchors.centerIn: parent
            spacing: 1 * pill.s
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: clock.hhmm
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 20 * pill.s
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: clock.date
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 9.5 * pill.s
                font.weight: Font.Medium
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.2 * pill.s
            }
        }

        MouseArea {
            anchors.centerIn: hoverClock
            width: hoverClock.width + 22 * pill.s
            height: hoverClock.height + 10 * pill.s
            enabled: pill.expanded && !pill.surfaceOpen
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.requestSurface("calendar")
        }

        Row {
            id: statusRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 11 * pill.s

            Tray {
                anchors.verticalCenter: parent.verticalCenter
                s: pill.s
                barWindow: pill.barWindow
                enabled: pill.expanded && !pill.surfaceOpen
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Store.dnd ? "静" : "音"
                color: Store.dnd ? Theme.vermLit : Theme.faint
                font.family: Theme.font
                font.pixelSize: 13 * pill.s
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "調"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 13 * pill.s

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6 * pill.s
                    enabled: pill.expanded && !pill.surfaceOpen
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pill.requestSurface("mixer")
                }
            }
        }
    }

    Mixer {
        id: mixer
        anchors.fill: parent
        anchors.topMargin: 16 * pill.s
        anchors.leftMargin: 18 * pill.s
        anchors.rightMargin: 18 * pill.s
        anchors.bottomMargin: 16 * pill.s
        s: pill.s
        active: pill.mixerOpen
        opacity: pill.mixerOpen ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
    }

    Calendar {
        id: calendar
        anchors.fill: parent
        anchors.topMargin: 16 * pill.s
        anchors.leftMargin: 18 * pill.s
        anchors.rightMargin: 18 * pill.s
        anchors.bottomMargin: 16 * pill.s
        s: pill.s
        active: pill.calendarOpen
        opacity: pill.calendarOpen ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
    }
}
