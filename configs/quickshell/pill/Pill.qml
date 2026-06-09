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
    property bool forcePinned: false

    readonly property bool held: pinned || forcePinned
    readonly property bool mixerOpen: surface === "mixer"
    readonly property bool calendarOpen: surface === "calendar"
    readonly property bool surfaceOpen: surface.length > 0
    readonly property bool expanded: surfaceOpen || held || hovered

    readonly property real restW: 160 * s
    readonly property real restH: 38 * s
    readonly property real hoverPad: 18 * s
    readonly property real hoverW: hoverRow.implicitWidth + 2 * hoverPad
    readonly property real hoverH: 50 * s
    readonly property real mixerW: 372 * s
    readonly property real mixerH: 206 * s
    readonly property real calendarW: 318 * s
    readonly property real calendarH: 262 * s
    readonly property real restCorner: 18 * s
    readonly property real openCorner: 22 * s

    readonly property string mode: calendarOpen ? "calendar"
        : (mixerOpen ? "mixer" : (expanded ? "hover" : "rest"))

    signal requestSurface(string name)
    signal requestClose()

    /**
     * Forward an arrow-key nudge to the open mixer's hovered fader. Returns true
     * when the mixer is open and a hovered fader consumed the step.
     */
    function mixerStep(deltaPct) {
        return pill.mixerOpen ? mixer.stepHovered(deltaPct) : false;
    }

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

    property real morphRadius: (mixerOpen || calendarOpen) ? openCorner : restCorner

    width: mode === "calendar" ? calendarW
        : mode === "mixer" ? mixerW
        : mode === "hover" ? hoverW : restW
    height: mode === "calendar" ? calendarH
        : mode === "mixer" ? mixerH
        : mode === "hover" ? hoverH : restH

    Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
    Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
    Behavior on morphRadius { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }

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
        opacity: (pill.expanded && !pill.surfaceOpen) ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        readonly property bool live: pill.expanded && !pill.surfaceOpen

        Row {
            id: hoverRow
            anchors.centerIn: parent
            spacing: 15 * pill.s

            Workspaces {
                id: ws
                anchors.verticalCenter: parent.verticalCenter
                width: implicitWidth
                screenName: pill.screenName
                s: pill.s
                dotActive: 9 * pill.s
                dotIdle: 6 * pill.s
                gap: 9 * pill.s
                enabled: hover.live
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 16 * pill.s
                color: Theme.hair
                opacity: 0.7
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: hoverClock.implicitWidth
                height: hoverClock.implicitHeight

                Column {
                    id: hoverClock
                    anchors.centerIn: parent
                    spacing: 1 * pill.s
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: clock.hhmm
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 22 * pill.s
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
                    anchors.centerIn: parent
                    width: hoverClock.implicitWidth + 22 * pill.s
                    height: hoverClock.implicitHeight + 10 * pill.s
                    enabled: hover.live
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pill.requestSurface("calendar")
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 16 * pill.s
                color: Theme.hair
                opacity: 0.7
            }

            Row {
                id: statusRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12 * pill.s

                Tray {
                    anchors.verticalCenter: parent.verticalCenter
                    s: pill.s
                    barWindow: pill.barWindow
                    enabled: hover.live
                }

                Shape {
                    id: dndIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Store.dnd
                    width: 16 * pill.s
                    height: 16 * pill.s
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: Theme.vermLit
                        strokeWidth: 1.5 * pill.s
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        startX: 5.2 * pill.s; startY: 12.2 * pill.s
                        PathLine { x: 12.2 * pill.s; y: 12.2 * pill.s }
                        PathLine { x: 12.2 * pill.s; y: 7.2 * pill.s }
                        PathCubic {
                            control1X: 12.2 * pill.s; control1Y: 5.4 * pill.s
                            control2X: 11.2 * pill.s; control2Y: 4.0 * pill.s
                            x: 9.5 * pill.s; y: 3.5 * pill.s
                        }
                    }
                    ShapePath {
                        strokeColor: Theme.vermLit
                        strokeWidth: 1.5 * pill.s
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        startX: 6.8 * pill.s; startY: 13.6 * pill.s
                        PathLine { x: 9.2 * pill.s; y: 13.6 * pill.s }
                    }
                    ShapePath {
                        strokeColor: Theme.vermLit
                        strokeWidth: 1.6 * pill.s
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        startX: 3.2 * pill.s; startY: 2.8 * pill.s
                        PathLine { x: 13.0 * pill.s; y: 13.4 * pill.s }
                    }
                }

                Item {
                    id: mixerIcon
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16 * pill.s
                    height: 16 * pill.s

                    readonly property color stroke: mixerArea.containsMouse ? Theme.vermLit : Theme.faint

                    Repeater {
                        model: [
                            { x: 4, knob: 5 },
                            { x: 8, knob: 10 },
                            { x: 12, knob: 6 }
                        ]
                        delegate: Shape {
                            id: fader
                            required property var modelData
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeColor: mixerIcon.stroke
                                strokeWidth: 1.6 * pill.s
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                startX: fader.modelData.x * pill.s
                                startY: 2.5 * pill.s
                                PathLine { x: fader.modelData.x * pill.s; y: 13.5 * pill.s }
                            }
                            ShapePath {
                                strokeColor: mixerIcon.stroke
                                strokeWidth: 1.6 * pill.s
                                fillColor: Theme.cardBot
                                joinStyle: ShapePath.RoundJoin
                                startX: (fader.modelData.x - 1.7) * pill.s
                                startY: fader.modelData.knob * pill.s
                                PathArc { x: (fader.modelData.x + 1.7) * pill.s; y: fader.modelData.knob * pill.s; radiusX: 1.7 * pill.s; radiusY: 1.7 * pill.s }
                                PathArc { x: (fader.modelData.x - 1.7) * pill.s; y: fader.modelData.knob * pill.s; radiusX: 1.7 * pill.s; radiusY: 1.7 * pill.s }
                            }
                        }
                    }

                    MouseArea {
                        id: mixerArea
                        anchors.fill: parent
                        anchors.margins: -6 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("mixer")
                    }
                }
            }
        }
    }

    Mixer {
        id: mixer
        anchors.fill: parent
        anchors.topMargin: 13 * pill.s
        anchors.leftMargin: 14 * pill.s
        anchors.rightMargin: 14 * pill.s
        anchors.bottomMargin: 12 * pill.s
        s: pill.s
        active: pill.mixerOpen
        enabled: pill.mixerOpen
        opacity: pill.mixerOpen ? 1 : 0
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
        enabled: pill.calendarOpen
        opacity: pill.calendarOpen ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
    }
}
