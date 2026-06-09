pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

/**
 * Live audio spectrum for the rest visualizer. Runs `cava` (raw ascii output)
 * only while an MPRIS player is playing and exposes the per-bar levels (0..1)
 * so every pill instance can share one capture. Stops cava when nothing plays.
 */
Singleton {
    id: root

    readonly property int bars: 9
    property var values: []

    readonly property bool rawActive: {
        var l = Mpris.players.values;
        for (var i = 0; i < l.length; i++)
            if (l[i] && l[i].isPlaying)
                return true;
        return false;
    }

    /**
     * Playback state with release hysteresis: short audio gaps (seeks, track
     * changes, brief pauses) keep `active` true so consumers don't flicker
     * between wake and sleep states.
     */
    readonly property bool active: rawActive || holdTimer.running

    onRawActiveChanged: {
        if (rawActive)
            holdTimer.stop();
        else
            holdTimer.restart();
    }

    onActiveChanged: if (!active) values = []

    Timer {
        id: holdTimer
        interval: 1500
    }

    Process {
        running: root.active
        command: ["cava", "-p", Quickshell.shellPath("assets/cava.conf")]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (!line || line.length === 0)
                    return;
                var parts = line.split(";");
                var out = [];
                for (var i = 0; i < root.bars; i++) {
                    var v = parseInt(parts[i]);
                    out.push(isNaN(v) ? 0 : Math.max(0, Math.min(1, v / 100)));
                }
                root.values = out;
            }
        }
    }
}
