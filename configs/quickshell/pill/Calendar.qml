pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import "Singletons"

/**
 * Calendar surface: a weather glance, the month grid, and an event editor that
 * grows out to the right when a day is picked.
 *
 * The centre is the month grid (header with month/year and prev/next nav, weekday
 * row, day cells sized to exactly the rows the month needs). Today keeps its warm
 * frame and the Ame ring; a day that holds a stored event marks its number warm
 * with a small ember dot. To the left, when Weather.ready, a slim panel shows the
 * current temperature, the condition kanji and city, and the next few hours. To
 * the right, selecting a day slides open an editor listing that day's events with
 * a delete tap and an add form (start, end, title).
 *
 * The date math (offset/monthLen/rows/today/shiftMonth/resetToday) is unchanged;
 * the grid is wrapped, not rewritten. implicitWidth sums the visible panels so the
 * pill morphs wider as the editor opens; implicitHeight still drives the height
 * down to the live row count. View date resets to the real today on every open,
 * and Ame keeps targeting today via ameForm/amePoint.
 */
PillSurface {
    id: root

    mTop: 16
    mLeft: 18
    mRight: 18
    mBottom: 16

    readonly property var loc: Qt.locale("en_US")

    readonly property date today: sysClock.date
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()

    readonly property int offset: firstWeekdayOffset(viewYear, viewMonth)
    readonly property int monthLen: daysInMonth(viewYear, viewMonth)
    readonly property int rows: Math.ceil((offset + monthLen) / 7)

    readonly property real cellH: 24 * s
    readonly property real rowGap: 2 * s

    readonly property real gridW: 282 * s
    readonly property real weatherW: 152 * s
    readonly property real editorW: 196 * s
    readonly property real gutter: 16 * s

    readonly property bool weatherShown: Weather.ready
    readonly property bool editorShown: selectedDate.length > 0

    /** "YYYY-MM-DD" of the day whose editor is open, "" when none is selected. */
    property string selectedDate: ""

    /** The weather panel and the editor each add their column plus a divider gutter only when visible. */
    implicitWidth: gridW
        + (weatherShown ? weatherW + gutter : 0)
        + (editorShown ? editorW + gutter : 0)

    implicitHeight: grid.y + rows * cellH + (rows - 1) * rowGap

    readonly property bool todayVisible: viewMonth === today.getMonth()
        && viewYear === today.getFullYear()
    readonly property int todayIndex: offset + today.getDate() - 1
    readonly property real cellW: grid.width / 7
    readonly property real todayX: gridPane.x + grid.x + (todayIndex % 7 + 0.5) * cellW
    readonly property real todayY: gridPane.y + grid.y + (Math.floor(todayIndex / 7) + 0.5) * (cellH + rowGap) - rowGap / 2

    ameForm: todayVisible ? "ring" : "dock"
    amePoint: todayVisible ? Qt.point(todayX, todayY) : Qt.point(gridPane.x + grid.x + grid.width / 2, height / 2)

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

    /** "YYYY-MM-DD" for a day number in the viewed month, zero-padded for keys. */
    function dateKey(day) {
        var m = viewMonth + 1;
        var mm = m < 10 ? "0" + m : "" + m;
        var dd = day < 10 ? "0" + day : "" + day;
        return viewYear + "-" + mm + "-" + dd;
    }

    function shiftMonth(delta) {
        var m = viewMonth + delta;
        var y = viewYear;
        while (m < 0) { m += 12; y -= 1; }
        while (m > 11) { m -= 12; y += 1; }
        viewMonth = m;
        viewYear = y;
        selectedDate = "";
    }

    function resetToday() {
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
        selectedDate = "";
    }

    /** Toggle a day's editor: re-clicking the open day closes it. */
    function selectDay(day) {
        var key = dateKey(day);
        selectedDate = (selectedDate === key) ? "" : key;
    }

    onActiveChanged: if (active) resetToday()

    Item {
        id: weather
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.weatherShown ? root.weatherW : 0
        clip: true
        visible: width > 1
        opacity: root.weatherShown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

        Column {
            id: wxCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 6 * root.s
            spacing: 9 * root.s

            Row {
                spacing: 9 * root.s

                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32 * root.s
                    height: 32 * root.s
                    name: Weather.glyphFor(Weather.codeNow, Weather.isDay)
                    color: Theme.todayWarm
                    stroke: 1.9
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Text {
                        text: Weather.tempNow + "°"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 26 * root.s
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                    Text {
                        text: Weather.labelFor(Weather.codeNow)
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: Font.Medium
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 8 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.city
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.8 * root.s
                    elide: Text.ElideRight
                    visible: Weather.city.length > 0
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3 * root.s

                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 11 * root.s
                        height: 11 * root.s
                        name: "droplet"
                        color: Theme.faint
                        stroke: 1.6
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Weather.humidity + "%"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                    }
                }
            }

            Rectangle {
                width: wxCol.width
                height: 1
                color: Theme.hairSoft
            }

            Row {
                width: wxCol.width

                Repeater {
                    model: Weather.daily.slice(0, 4)

                    Column {
                        id: dayCol
                        required property var modelData
                        width: wxCol.width / 4
                        spacing: 5 * root.s

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dayCol.modelData.day
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 9 * root.s
                            font.weight: Font.DemiBold
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.5 * root.s
                        }
                        GlyphIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 15 * root.s
                            height: 15 * root.s
                            name: Weather.glyphFor(dayCol.modelData.code, true)
                            color: Theme.subtle
                            stroke: 1.7
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dayCol.modelData.temp + "°"
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 11 * root.s
                            font.weight: Font.Medium
                            font.features: { "tnum": 1 }
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 2 * root.s

                            GlyphIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 9 * root.s
                                height: 9 * root.s
                                name: "droplet"
                                color: Theme.faint
                                stroke: 1.6
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: dayCol.modelData.rh + "%"
                                color: Theme.faint
                                font.family: Theme.font
                                font.pixelSize: 8.5 * root.s
                                font.weight: Font.Medium
                                font.features: { "tnum": 1 }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: weatherSeam
        anchors.left: weather.right
        anchors.leftMargin: root.gutter / 2
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Theme.hair
        visible: root.weatherShown
        opacity: weather.opacity
    }

    Item {
        id: gridPane
        anchors.left: root.weatherShown ? weather.right : parent.left
        anchors.leftMargin: root.weatherShown ? root.gutter : 0
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.gridW

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
                    visible: Flags.showGlyphs
                    text: "暦"
                    color: Theme.cream
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
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
                        radius: Motion.rSmall * root.s
                        color: navArea.containsMouse ? Theme.frameBg : "transparent"
                        border.width: navArea.containsMouse ? 1 : 0
                        border.color: Theme.frameBorder

                        GlyphIcon {
                            anchors.centerIn: parent
                            width: 16 * root.s
                            height: 16 * root.s
                            name: nav.modelData < 0 ? "chevron-left" : "chevron-right"
                            color: navArea.containsMouse ? Theme.cream : Theme.iconDim
                            stroke: 1.8
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
                    readonly property bool weekend: index >= 5
                    width: weekdays.width / 7
                    height: 16 * root.s

                    Text {
                        anchors.centerIn: parent
                        text: root.loc.standaloneDayName((wd.index + 1) % 7, Locale.NarrowFormat)
                        color: wd.weekend ? Theme.faint : Theme.dim
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
            y: weekdays.y + weekdays.height + 4 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            columns: 7
            rowSpacing: root.rowGap
            columnSpacing: 0

            Repeater {
                model: root.rows * 7

                Item {
                    id: cell
                    required property int index
                    readonly property int weekday: index % 7
                    readonly property bool weekend: weekday >= 5
                    width: grid.width / 7
                    height: root.cellH

                    readonly property int dayNum: index - root.offset + 1
                    readonly property bool inMonth: dayNum >= 1 && dayNum <= root.monthLen
                    readonly property bool current: inMonth && root.isToday(dayNum)
                    readonly property string dayKey: inMonth ? root.dateKey(dayNum) : ""
                    readonly property bool hasEvent: inMonth && Events.hasEvents(cell.dayKey)
                    readonly property bool picked: inMonth && root.selectedDate === cell.dayKey
                    readonly property int ghostNum: dayNum < 1
                        ? root.daysInMonth(root.viewYear, root.viewMonth - 1) + dayNum
                        : dayNum - root.monthLen

                    Rectangle {
                        anchors.centerIn: parent
                        width: 22 * root.s
                        height: 22 * root.s
                        radius: Motion.rSmall * root.s
                        color: cellArea.containsMouse && cell.inMonth && !cell.current
                            ? Qt.rgba(0.94, 0.88, 0.84, 0.04) : "transparent"
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 24 * root.s
                        height: 24 * root.s
                        radius: Motion.rSmall * root.s
                        visible: cell.current || cell.picked
                        color: cell.picked && !cell.current ? Qt.alpha(Theme.vermLit, 0.12) : Theme.frameBg
                        border.width: 1
                        border.color: cell.picked ? Qt.alpha(Theme.vermLit, 0.55) : Theme.frameBorder
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.inMonth ? cell.dayNum : cell.ghostNum
                        color: cell.inMonth
                            ? (cell.current ? Theme.todayWarm
                                : (cell.hasEvent ? Theme.flameGlow
                                    : (cell.weekend ? Theme.subtle : Theme.cream)))
                            : Theme.ghost
                        opacity: cell.inMonth && !cell.current && !cell.weekend && !cell.hasEvent ? 0.85 : 1.0
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: cell.current || cell.hasEvent ? Font.DemiBold : Font.Normal
                        font.features: { "tnum": 1 }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.verticalCenter
                        anchors.topMargin: 9 * root.s
                        visible: cell.hasEvent && !cell.current
                        width: 3 * root.s
                        height: 3 * root.s
                        radius: width / 2
                        color: Theme.flameGlow
                    }

                    MouseArea {
                        id: cellArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: cell.inMonth
                        cursorShape: cell.inMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (cell.inMonth) root.selectDay(cell.dayNum)
                    }
                }
            }
        }

        MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: grid.bottom
            anchors.bottom: parent.bottom
            enabled: root.editorShown
            onClicked: root.selectedDate = ""
        }
    }

    Rectangle {
        id: editorSeam
        anchors.left: gridPane.right
        anchors.leftMargin: root.gutter / 2
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Theme.hair
        visible: root.editorShown
        opacity: editor.opacity
    }

    Item {
        id: editor
        anchors.left: gridPane.right
        anchors.leftMargin: root.gutter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.editorShown ? root.editorW : 0
        clip: true
        visible: width > 1
        opacity: root.editorShown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

        /** Parsed events for the open day; empty until a day is picked. */
        readonly property var dayEvents: root.selectedDate.length > 0
            ? Events.forDate(root.selectedDate) : []

        /** "Mon 9 Jun" heading for the open day, parsed back from the key. */
        readonly property string heading: {
            if (root.selectedDate.length === 0)
                return "";
            var p = root.selectedDate.split("-");
            var d = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
            return root.loc.toString(d, "ddd d MMM");
        }

        property string startVal: ""
        property string endVal: ""
        property string titleVal: ""

        function clearForm() {
            startVal = "";
            endVal = "";
            titleVal = "";
            startField.text = "";
            endField.text = "";
            titleField.text = "";
        }

        /** A time is kept only when it reads as HH:MM, otherwise it drops to an all-day blank. */
        function cleanTime(t) {
            var v = t.trim();
            return /^\d{1,2}:\d{2}$/.test(v) ? v : "";
        }

        /** Add the form's event when a title is set, then reset the inputs. */
        function commit() {
            if (titleVal.trim().length === 0)
                return;
            Events.add(root.selectedDate, editor.cleanTime(startVal), editor.cleanTime(endVal), titleVal.trim());
            clearForm();
            titleField.forceActiveFocus();
        }

        onWidthChanged: if (width < 1) clearForm()

        Text {
            id: edHeading
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            text: editor.heading
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12 * root.s
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.8 * root.s
            elide: Text.ElideRight
        }

        Rectangle {
            id: edDivider
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: edHeading.bottom
            anchors.topMargin: 7 * root.s
            height: 1
            color: Theme.hair
        }

        Column {
            id: edList
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: edDivider.bottom
            anchors.topMargin: 8 * root.s
            spacing: 4 * root.s

            Text {
                visible: editor.dayEvents.length === 0
                text: "Nothing yet"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.Medium
                font.italic: true
            }

            Repeater {
                model: editor.dayEvents

                Rectangle {
                    id: evRow
                    required property var modelData
                    width: edList.width
                    height: 30 * root.s
                    radius: Motion.rSmall * root.s
                    color: evArea.hovered ? Theme.frameBg : "transparent"

                    readonly property string span: {
                        var t = evRow.modelData.time || "";
                        var e = evRow.modelData.endTime || "";
                        if (t.length === 0)
                            return "all day";
                        return e.length > 0 ? t + "–" + e : t;
                    }

                    HoverHandler { id: evArea }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 8 * root.s
                        anchors.right: evDel.left
                        anchors.rightMargin: 6 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1 * root.s

                        Text {
                            text: evRow.modelData.text
                            width: parent.width
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 11 * root.s
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        Text {
                            text: evRow.span
                            color: Theme.flameGlow
                            font.family: Theme.font
                            font.pixelSize: 9 * root.s
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }
                    }

                    Item {
                        id: evDel
                        anchors.right: parent.right
                        anchors.rightMargin: 7 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16 * root.s
                        height: 16 * root.s
                        opacity: evArea.hovered ? 1 : 0.32
                        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                        GlyphIcon {
                            anchors.fill: parent
                            name: "close"
                            color: delArea.containsMouse ? Theme.vermLit : Theme.iconDim
                            stroke: 1.6
                        }

                        MouseArea {
                            id: delArea
                            anchors.fill: parent
                            anchors.margins: -5 * root.s
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Events.remove(evRow.modelData.id)
                        }
                    }
                }
            }
        }

        Column {
            id: edForm
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 7 * root.s

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.hair
            }

            Row {
                spacing: 8 * root.s

                Item {
                    width: (edForm.width - 8 * root.s) / 2
                    height: 26 * root.s

                    TextField {
                        id: startField
                        anchors.fill: parent
                        background: null
                        padding: 0
                        leftPadding: 2 * root.s
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 13 * root.s
                        font.features: { "tnum": 1 }
                        placeholderText: "09:00"
                        placeholderTextColor: Theme.faint
                        inputMethodHints: Qt.ImhPreferNumbers
                        selectByMouse: true
                        selectionColor: Theme.verm
                        onTextChanged: editor.startVal = text
                        Keys.onReturnPressed: editor.commit()
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: Theme.faint
                        opacity: startField.activeFocus ? 0.7 : 0.2
                        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                    }
                }

                Item {
                    width: (edForm.width - 8 * root.s) / 2
                    height: 26 * root.s

                    TextField {
                        id: endField
                        anchors.fill: parent
                        background: null
                        padding: 0
                        leftPadding: 2 * root.s
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 13 * root.s
                        font.features: { "tnum": 1 }
                        placeholderText: "until"
                        placeholderTextColor: Theme.faint
                        inputMethodHints: Qt.ImhPreferNumbers
                        selectByMouse: true
                        selectionColor: Theme.verm
                        onTextChanged: editor.endVal = text
                        Keys.onReturnPressed: editor.commit()
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: Theme.faint
                        opacity: endField.activeFocus ? 0.7 : 0.2
                        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                    }
                }
            }

            Row {
                spacing: 8 * root.s

                Item {
                    width: edForm.width - addBtn.width - 8 * root.s
                    height: 28 * root.s

                    TextField {
                        id: titleField
                        anchors.fill: parent
                        background: null
                        padding: 0
                        leftPadding: 2 * root.s
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 13 * root.s
                        placeholderText: "what's on"
                        placeholderTextColor: Theme.faint
                        selectByMouse: true
                        selectionColor: Theme.verm
                        onTextChanged: editor.titleVal = text
                        Keys.onReturnPressed: editor.commit()
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: Theme.faint
                        opacity: titleField.activeFocus ? 0.7 : 0.2
                        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                    }
                }

                Rectangle {
                    id: addBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28 * root.s
                    height: 28 * root.s
                    radius: Motion.rSmall * root.s
                    readonly property bool armed: editor.titleVal.trim().length > 0
                    color: addArea.containsMouse && armed ? Qt.alpha(Theme.vermLit, 0.22)
                        : (armed ? Qt.alpha(Theme.vermLit, 0.12) : Theme.frameBg)
                    border.width: 1
                    border.color: armed ? Qt.alpha(Theme.vermLit, 0.5) : Theme.frameBorder
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: addBtn.armed ? Theme.vermLit : Theme.iconDim
                        font.family: Theme.font
                        font.pixelSize: 18 * root.s
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: addArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: editor.commit()
                    }
                }
            }
        }
    }
}
