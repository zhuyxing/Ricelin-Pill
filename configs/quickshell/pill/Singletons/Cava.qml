pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Live audio spectrum for the rest-pill visualizer. A headless cava captures the
 * default sink monitor, so the bars answer to any system sound (music, a
 * background video, a game) instead of one MPRIS player. cava runs the FFT and
 * smoothing; we only parse its raw ascii frames into normalized 0..1 levels.
 *
 * Silence arrives as an all-zero frame every tick, which `active` debounces into
 * a clean play/stop signal so the glyph morph does not flap between tracks.
 */
Singleton {
    id: root

    readonly property int bars: 5
    property var levels: []
    property bool active: false

    readonly property string config: "[general]\n"
        + "bars = " + bars + "\nframerate = 60\nautosens = 1\n"
        + "[input]\nmethod = pipewire\nsource = auto\n"
        + "[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\n"
        + "ascii_max_range = 1000\nbar_delimiter = 59\nframe_delimiter = 10\n"
        + "channels = mono\nmono_option = average\n"
        + "[smoothing]\nnoise_reduction = 0.77\n"

    /**
     * ponytail: cava runs whenever the feature is on. Gate running on a live
     * pipewire playback stream if idle CPU ever shows up as a problem.
     */
    Process {
        running: Flags.musicViz
        command: ["sh", "-c", "printf '%s' \"$1\" | cava -p /dev/stdin", "_", root.config]
        onRunningChanged: if (!running && Flags.musicViz) running = true
        stdout: SplitParser {
            onRead: (line) => {
                if (!line)
                    return;
                const parts = line.split(";");
                const out = [];
                let peak = 0;
                for (let i = 0; i < root.bars; i++) {
                    const v = (parseInt(parts[i]) || 0) / 1000;
                    out.push(v);
                    if (v > peak)
                        peak = v;
                }
                root.levels = out;
                if (peak > 0.02) {
                    root.active = true;
                    idle.restart();
                }
            }
        }
    }

    /** Short debounce so inter-track gaps do not snap the morph back to the clock. */
    Timer {
        id: idle
        interval: 450
        onTriggered: root.active = false
    }
}
