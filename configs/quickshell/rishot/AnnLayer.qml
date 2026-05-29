import QtQuick

Item {
    id: canvas

    required property int sx
    required property int sy
    property var model: null
    property var draft: null
    property int revision: 0

    function rects() {
        var out = [];
        var src = model ? model.items.slice() : [];
        if (draft) src.push(draft);
        for (var i = 0; i < src.length; i++) {
            var a = src[i];
            if (a.type !== "rect" || !a.points || a.points.length < 2) continue;
            var p0 = a.points[0], p1 = a.points[1];
            out.push({
                x: Math.min(p0.x, p1.x) - sx,
                y: Math.min(p0.y, p1.y) - sy,
                w: Math.abs(p1.x - p0.x),
                h: Math.abs(p1.y - p0.y),
                color: a.color,
                width: a.width,
                filled: a.filled === true
            });
        }
        return out;
    }

    Repeater {
        model: { canvas.revision; return canvas.rects(); }
        Rectangle {
            required property var modelData
            x: modelData.x; y: modelData.y
            width: modelData.w; height: modelData.h
            color: modelData.filled ? modelData.color : "transparent"
            border.color: modelData.color
            border.width: modelData.width
            antialiasing: true
        }
    }
}
