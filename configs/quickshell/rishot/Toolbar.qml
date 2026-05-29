import QtQuick
import QtQuick.Layouts

Item {
    id: tb
    implicitWidth: glass.implicitWidth
    implicitHeight: glass.implicitHeight

    property string activeTool: "rect"
    property bool canUndo: false
    property bool canRedo: false
    property bool settingsOpen: false

    readonly property real gearCenterX: gear.x + row.x + gear.width / 2

    signal toolPicked(string tool)
    signal undoRequested()
    signal redoRequested()
    signal copyRequested()
    signal saveRequested()
    signal settingsRequested()

    readonly property color glassBg: Qt.rgba(20 / 255, 24 / 255, 34 / 255, 0.92)
    readonly property color glassBorder: "#313a4d"
    readonly property color vermilion: "#e0563b"
    readonly property color idle: "#c4ccda"
    readonly property color sep: "#313a4d"

    readonly property var tools: [
        { id: "rect",    glyph: "▭", implemented: true },
        { id: "ellipse", glyph: "◯", implemented: false },
        { id: "line",    glyph: "╱", implemented: false },
        { id: "arrow",   glyph: "↗", implemented: false },
        { id: "pen",     glyph: "✎", implemented: false },
        { id: "text",    glyph: "T", implemented: false },
        { id: "marker",  glyph: "▰", implemented: false },
        { id: "blur",    glyph: "▒", implemented: false }
    ]

    Rectangle {
        id: glass
        anchors.fill: parent
        radius: 10
        color: tb.glassBg
        border.color: tb.glassBorder
        border.width: 1
        implicitWidth: row.implicitWidth + 12
        implicitHeight: row.implicitHeight + 12

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: tb.tools
                IconButton {
                    required property var modelData
                    label: modelData.glyph
                    active: tb.activeTool === modelData.id
                    dim: !modelData.implemented
                    onClicked: { if (modelData.implemented) tb.toolPicked(modelData.id); }
                }
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: tb.sep; Layout.leftMargin: 3; Layout.rightMargin: 3 }

            IconButton { label: "↶"; dim: !tb.canUndo; onClicked: { if (tb.canUndo) tb.undoRequested(); } }
            IconButton { label: "↷"; dim: !tb.canRedo; onClicked: { if (tb.canRedo) tb.redoRequested(); } }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: tb.sep; Layout.leftMargin: 3; Layout.rightMargin: 3 }

            IconButton { label: "⧉"; onClicked: tb.copyRequested() }
            IconButton { label: "▤"; onClicked: tb.saveRequested() }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: tb.sep; Layout.leftMargin: 3; Layout.rightMargin: 3 }

            IconButton {
                id: gear
                label: "⚙"
                active: tb.settingsOpen
                onClicked: { tb.settingsOpen = !tb.settingsOpen; tb.settingsRequested(); }
            }
        }
    }
}
