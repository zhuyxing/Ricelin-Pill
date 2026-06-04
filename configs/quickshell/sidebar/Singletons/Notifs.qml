pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    property bool dnd: false
    property var seenIds: ({})
    property var arrivalMs: ({})
    property var popups: []
    property int tick: 0

    readonly property var tracked: server.trackedNotifications.values
    readonly property int count: tracked.length

    readonly property int unread: {
        var u = 0;
        for (var i = 0; i < tracked.length; i++)
            if (!seenIds[tracked[i].id]) u++;
        return u;
    }

    readonly property var groups: {
        var map = {};
        var order = [];
        for (var i = tracked.length - 1; i >= 0; i--) {
            var n = tracked[i];
            var app = (n.appName && n.appName.length) ? n.appName : "System";
            if (map[app] === undefined) { map[app] = []; order.push(app); }
            map[app].push(n);
        }
        return order.map(function(a) { return { app: a, items: map[a] }; });
    }

    function markAllSeen() {
        var m = {};
        for (var i = 0; i < tracked.length; i++) m[tracked[i].id] = true;
        root.seenIds = m;
    }

    function clearAll() {
        var l = tracked.slice();
        for (var i = 0; i < l.length; i++) l[i].dismiss();
        root.popups = [];
    }

    function removePopup(n) {
        root.popups = root.popups.filter(function(p) { return p !== n; });
    }

    function ageLabel(n) {
        void root.tick;
        var t = arrivalMs[n.id];
        if (!t) return "";
        var m = Math.floor((Date.now() - t) / 60000);
        if (m < 1) return "now";
        if (m < 60) return m + "m";
        return Math.floor(m / 60) + "h";
    }

    function progressOf(n) {
        var h = n.hints || {};
        if (h["value"] === undefined) return -1;
        return Math.max(0, Math.min(100, Number(h["value"])));
    }

    Timer {
        interval: 30000
        running: root.count > 0
        repeat: true
        onTriggered: root.tick++
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: function(n) {
            n.tracked = true;
            var a = root.arrivalMs;
            a[n.id] = Date.now();
            root.arrivalMs = a;
            n.closed.connect(function() { root.removePopup(n); });
            var critical = n.urgency === NotificationUrgency.Critical;
            if (!root.dnd || critical)
                root.popups = root.popups.concat([n]).slice(-3);
        }
    }
}
