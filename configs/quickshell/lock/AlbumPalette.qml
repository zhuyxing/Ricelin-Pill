import QtQuick
import Quickshell.Io
import "Singletons"
import "lib/palette.js" as Pal

Item {
    id: palette

    property string artUrl: ""
    property color accent: Theme.accent
    property bool hasArt: false

    readonly property string artPath: {
        var u = artUrl;
        if (!u || u.length === 0)
            return "";
        if (u.indexOf("file://") === 0)
            return decodeURIComponent(u.substring(7));
        if (u.indexOf("://") >= 0)
            return "";
        return u;
    }

    onArtPathChanged: {
        if (artPath.length === 0) {
            accent = Theme.accent;
            hasArt = false;
        } else {
            extract.start(artPath);
        }
    }

    Process {
        id: extract
        running: false
        command: ["true"]
        function start(path) {
            command = ["bash", "-lc", "magick \"$ART\"[0] -resize 64x64 -depth 8 -colorspace sRGB -quantize sRGB +dither -colors 5 -format '%c' histogram:info: | sort -rn | head -1 | grep -oE '#[0-9A-Fa-f]{6}'"];
            environment = { "ART": path };
            running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                var hex = this.text.trim();
                var c = Pal.clampHex(hex);
                palette.accent = c ? c : Theme.accent;
                palette.hasArt = c ? true : false;
            }
        }
    }

    Behavior on accent {
        ColorAnimation { duration: 600 }
    }
}
