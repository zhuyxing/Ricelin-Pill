pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "Singletons"

/**
 * 飴 Ame — the shapeshifter. One molten-glass bead that is the shell's only
 * glowing element. It rests calmly (a 2.5% breathing scale over ~8s) and has no
 * music, audio or physics coupling whatsoever — every motion is a deterministic,
 * choreographed timeline.
 *
 * When a surface opens, closes or moves its anchor far enough, the bead runs the
 * full shapeshift over `Motion.shapeshift` ms: anticipation stretch, a remnant
 * droplet pinching off at the origin, a quadratic-bezier flight with a tapered
 * liquid streak, a three-droplet landing splash, then an easeOutBack settle into
 * the per-surface form. Small target moves (seam progress, mixer focus, hover
 * width) glide directly over `Motion.glide` ms with the form intact.
 *
 * Forms: "rest"/"hover" rest bead, "caret" blinking launcher capsule, "seam"
 * media bead, "ring" calendar ring, "dock" plain bead (mixer/power/link), "off"
 * hidden. The body renders on a QtQuick Canvas: a FrameAnimation drives 60fps
 * repaint only while the timeline, splash or remnant is live or the caret is
 * blinking; otherwise a 12fps Timer ticks the slow inner swirl arcs so the
 * idle cost stays minimal for a shell that runs 24/7.
 */
Item {
    id: root

    property real s: 1
    property real pillW: 160
    property real pillH: 38
    property point point: Qt.point(0, 0)
    property string form: "rest"
    property real heat: 0

    visible: form !== "off"

    readonly property real restR: 5 * s
    readonly property real heatScale: 1 - 0.4 * heat
    readonly property real flightThreshold: 30 * s

    property real bx: 0
    property real by: 0
    property string activeForm: "rest"

    property real prog: 1
    property string phase: "idle"
    property point fromPoint: Qt.point(0, 0)
    property point ctrlPoint: Qt.point(0, 0)
    property real flightAng: 0
    property real flightDist: 0
    property real remnant: 0
    property point remnantPoint: Qt.point(0, 0)
    property real swirl: 0

    property real glideT: 1
    property point glideFrom: Qt.point(0, 0)
    property point glideTo: Qt.point(0, 0)

    readonly property bool timelineLive: prog < 1 || remnant > 0
    readonly property bool gliding: glideT < 1
    readonly property bool blinking: activeForm === "caret"
    readonly property bool busy: timelineLive || gliding

    function clamp01(u) { return Math.max(0, Math.min(1, u)); }
    function smoothstep(u) { return u * u * (3 - 2 * u); }
    function easeInOutQuint(u) { return u < 0.5 ? 16 * u * u * u * u * u : 1 - Math.pow(-2 * u + 2, 5) / 2; }
    function easeOutBack(u) { const c = 1.70158; return 1 + (c + 1) * Math.pow(u - 1, 3) + c * Math.pow(u - 1, 2); }

    function bez(a, c, b, u) {
        const v = 1 - u;
        return Qt.point(v * v * a.x + 2 * v * u * c.x + u * u * b.x,
                        v * v * a.y + 2 * v * u * c.y + u * u * b.y);
    }

    function startFlight(target, targetForm) {
        fromPoint = Qt.point(bx, by);
        const dx = target.x - bx;
        const dy = target.y - by;
        const dd = Math.hypot(dx, dy) || 1;
        flightDist = dd;
        flightAng = Math.atan2(dy, dx);
        let px = -dy / dd;
        let py = dx / dd;
        if (py > 0) { px = -px; py = -py; }
        ctrlPoint = Qt.point((bx + target.x) / 2 + px * dd * 0.22,
                             (by + target.y) / 2 + py * dd * 0.22);
        remnantPoint = Qt.point(bx, by);
        remnant = dd > root.flightThreshold ? 1 : 0;
        activeForm = targetForm;
        glideAnim.stop();
        glideT = 1;
        flightAnim.restart();
        if (remnant > 0)
            remnantAnim.restart();
    }

    function startGlide(target) {
        glideFrom = Qt.point(bx, by);
        glideTo = target;
        glideT = 0;
        glideAnim.restart();
    }

    function retarget() {
        const dx = point.x - bx;
        const dy = point.y - by;
        const dd = Math.hypot(dx, dy);
        if (form !== activeForm || dd > root.flightThreshold)
            startFlight(point, form);
        else if (dd > 0.5)
            startGlide(point);
        else {
            bx = point.x;
            by = point.y;
        }
    }

    onPointChanged: if (root.visible) retarget()
    onFormChanged: {
        if (!root.visible) { activeForm = form; return; }
        retarget();
    }

    Component.onCompleted: {
        bx = point.x;
        by = point.y;
        activeForm = form;
    }

    NumberAnimation {
        id: flightAnim
        target: root
        property: "prog"
        from: 0
        to: 1
        duration: Motion.shapeshift
        easing.type: Easing.Linear
    }

    NumberAnimation {
        id: remnantAnim
        target: root
        property: "remnant"
        from: 1
        to: 0
        duration: 350
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: glideAnim
        target: root
        property: "glideT"
        from: 0
        to: 1
        duration: Motion.glide
        easing.type: Easing.OutCubic
    }

    onProgChanged: {
        const P_ANTIC = 0.146;
        const P_FLY = 0.658;
        if (prog < P_ANTIC) {
            phase = "antic";
            bx = fromPoint.x;
            by = fromPoint.y;
        } else if (prog < P_FLY) {
            phase = "fly";
            const u = easeInOutQuint((prog - P_ANTIC) / (P_FLY - P_ANTIC));
            const p = bez(fromPoint, ctrlPoint, point, u);
            bx = p.x;
            by = p.y;
        } else {
            phase = "settle";
            bx = point.x;
            by = point.y;
        }
    }

    onGlideTChanged: if (gliding || glideT === 1) {
        bx = glideFrom.x + (glideTo.x - glideFrom.x) * glideT;
        by = glideFrom.y + (glideTo.y - glideFrom.y) * glideT;
        if (glideT >= 1) {
            bx = glideTo.x;
            by = glideTo.y;
        }
    }

    FrameAnimation {
        running: root.visible && (root.busy || root.blinking)
        onTriggered: {
            root.swirl += frameTime * 0.5;
            canvas.requestPaint();
        }
    }

    Timer {
        running: root.visible && !root.busy && !root.blinking
        interval: 83
        repeat: true
        onTriggered: {
            root.swirl += 0.083 * 0.5;
            canvas.requestPaint();
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        antialiasing: true

        readonly property real breathe: 1 + 0.0125 * Math.sin(root.swirl * 0.32)

        function bead(ctx, x, y, R, stretch, ang, alpha) {
            ctx.save();
            if (alpha !== undefined)
                ctx.globalAlpha = alpha;
            ctx.translate(x, y);
            ctx.rotate(ang);
            ctx.scale(1 + stretch, 1 / (1 + stretch * 0.55));
            ctx.rotate(-ang);
            const hg = ctx.createRadialGradient(-R * 0.32, -R * 0.38, 0, 0, 0, R);
            hg.addColorStop(0, "#f0795a");
            hg.addColorStop(0.55, Theme.vermLit);
            hg.addColorStop(0.92, Theme.verm);
            hg.addColorStop(1, "#7e2812");
            ctx.beginPath();
            ctx.arc(0, 0, R, 0, 7);
            ctx.fillStyle = hg;
            ctx.fill();
            ctx.save();
            ctx.beginPath();
            ctx.arc(0, 0, R, 0, 7);
            ctx.clip();
            ctx.globalAlpha = (alpha === undefined ? 1 : alpha) * 0.35;
            for (let k = 0; k < 2; k++) {
                ctx.beginPath();
                ctx.arc(0, 0, R * (0.45 + k * 0.22),
                        root.swirl * (0.5 + k * 0.25) + k * 2.6,
                        root.swirl * (0.5 + k * 0.25) + k * 2.6 + 2.4);
                ctx.strokeStyle = k ? "#8a2c14" : "#ffb38a";
                ctx.lineWidth = 1.6 * root.s;
                ctx.stroke();
            }
            ctx.restore();
            ctx.beginPath();
            ctx.ellipse(-R * 0.34 - R * 0.30, -R * 0.42 - R * 0.18, R * 0.60, R * 0.36);
            ctx.fillStyle = "rgba(255,246,240,0.6)";
            ctx.fill();
            ctx.beginPath();
            ctx.arc(0, 0, Math.max(0.5, R - 0.8 * root.s), Math.PI * 0.25, Math.PI * 0.75);
            ctx.strokeStyle = "rgba(255,217,194,0.45)";
            ctx.lineWidth = 1.2 * root.s;
            ctx.stroke();
            ctx.restore();
        }

        function underGlow(ctx, x, y) {
            const ug = ctx.createRadialGradient(x, y + 3 * root.s, 0, x, y + 3 * root.s, 22 * root.s);
            ug.addColorStop(0, Qt.rgba(Theme.flameGlow.r, Theme.flameGlow.g, Theme.flameGlow.b, 0.2));
            ug.addColorStop(1, Qt.rgba(Theme.flameGlow.r, Theme.flameGlow.g, Theme.flameGlow.b, 0));
            ctx.fillStyle = ug;
            ctx.fillRect(x - 22 * root.s, y - 19 * root.s, 44 * root.s, 44 * root.s);
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (!root.visible)
                return;

            const S = root.s;
            const bx = root.bx;
            const by = root.by;
            const baseR = root.restR;

            if (root.remnant > 0 && root.phase !== "antic") {
                const rr = baseR * 0.5 * root.remnant;
                if (rr > 0.4 * S)
                    bead(ctx, root.remnantPoint.x + (1 - root.remnant) * 6 * S, root.remnantPoint.y,
                         rr, 0, 0, root.remnant * 0.9);
            }

            if (root.phase === "antic") {
                const q = root.clamp01(root.prog / 0.146);
                const pull = root.smoothstep(q) * 0.55;
                bead(ctx, bx, by, baseR, pull, root.flightAng);
                return;
            }

            if (root.phase === "fly") {
                const q = (root.prog - 0.146) / (0.658 - 0.146);
                const u = root.easeInOutQuint(root.clamp01(q));
                const tail = Math.max(0, u - 0.26 * Math.sin(Math.PI * Math.min(1, q * 1.4)));
                const NSEG = 15;
                for (let i = 0; i < NSEG; i++) {
                    const u1 = tail + (u - tail) * (i / NSEG);
                    const u2 = tail + (u - tail) * ((i + 1) / NSEG);
                    const a2 = root.bez(root.fromPoint, root.ctrlPoint, root.point, u1);
                    const b2 = root.bez(root.fromPoint, root.ctrlPoint, root.point, u2);
                    const fI = i / NSEG;
                    ctx.beginPath();
                    ctx.moveTo(a2.x, a2.y);
                    ctx.lineTo(b2.x, b2.y);
                    ctx.strokeStyle = fI > 0.6 ? Theme.vermLit : Theme.verm;
                    ctx.lineWidth = (0.8 + 6.5 * fI * fI) * S;
                    ctx.lineCap = "round";
                    ctx.globalAlpha = 0.12 + 0.55 * fI;
                    ctx.stroke();
                }
                ctx.globalAlpha = 1;
                const speed = Math.sin(Math.PI * root.clamp01(q));
                const d1 = root.bez(root.fromPoint, root.ctrlPoint, root.point, Math.min(1, u + 0.01));
                const tang = Math.atan2(d1.y - by, d1.x - bx);
                bead(ctx, bx, by, baseR * 1.62, speed * 1.0, tang);
                return;
            }

            const settling = root.phase === "settle";
            const q = settling ? root.clamp01((root.prog - 0.658) / (1 - 0.658)) : 1;
            const e = settling ? root.easeOutBack(q) : 1;
            const fadeIn = settling ? root.smoothstep(root.clamp01(q * 1.8)) : 1;

            if (settling && q < 0.55) {
                const sq = q / 0.55;
                const hop = Math.sin(Math.PI * sq);
                const angles = [-2.35, -1.57, -0.79];
                for (let i = 0; i < 3; i++) {
                    const sa = angles[i];
                    const sr = 13 * S * hop;
                    const sx2 = bx + Math.cos(sa) * sr;
                    const sy2 = by + Math.sin(sa) * sr * 1.25;
                    ctx.beginPath();
                    ctx.arc(sx2, sy2, (2.2 - 0.9 * sq) * S, 0, 7);
                    ctx.fillStyle = Theme.vermLit;
                    ctx.globalAlpha = hop * 0.85;
                    ctx.fill();
                }
                ctx.globalAlpha = 1;
            }

            const f = root.activeForm;

            if (f === "caret") {
                underGlow(ctx, bx, by);
                const blink = settling ? 1 : (0.35 + 0.65 * (0.5 + 0.5 * Math.sin(root.swirl * 5.7)));
                const hgt = 15 * S * e;
                const wdt = (2.5 + 6 * (1 - fadeIn)) * S;
                ctx.globalAlpha = blink;
                ctx.beginPath();
                ctx.roundedRect(bx - wdt / 2, by - hgt / 2, wdt, Math.max(2 * S, hgt), Math.min(wdt, hgt) / 2, Math.min(wdt, hgt) / 2);
                const cg = ctx.createLinearGradient(0, by - 8 * S, 0, by + 8 * S);
                cg.addColorStop(0, Theme.flameCore);
                cg.addColorStop(1, Theme.vermLit);
                ctx.fillStyle = cg;
                ctx.fill();
                ctx.globalAlpha = 1;
                return;
            }

            if (f === "seam") {
                underGlow(ctx, bx, by);
                const R = (3.5 + 1.5 * (1 - fadeIn)) * S;
                const sg2 = ctx.createRadialGradient(bx, by, 0, bx, by, 12 * S);
                sg2.addColorStop(0, Qt.rgba(1, 0.851, 0.761, 0.9 * fadeIn));
                sg2.addColorStop(0.5, Qt.rgba(1, 0.604, 0.392, 0.4 * fadeIn));
                sg2.addColorStop(1, Qt.rgba(1, 0.604, 0.392, 0));
                ctx.fillStyle = sg2;
                ctx.fillRect(bx - 12 * S, by - 12 * S, 24 * S, 24 * S);
                bead(ctx, bx, by, R * (settling ? (0.8 + 0.2 * e) : 1), 0, 0);
                return;
            }

            if (f === "ring") {
                const R = (baseR + 6 * S) + 5 * S * root.smoothstep(fadeIn) * e;
                ctx.globalAlpha = 1;
                ctx.beginPath();
                ctx.arc(bx, by, Math.max(2 * S, R), 0, 7);
                ctx.strokeStyle = Theme.vermLit;
                ctx.lineWidth = Math.max(1.6 * S, (7 - 4.8 * fadeIn) * S);
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(bx, by, Math.max(2 * S, R), -1.2, 0.4);
                ctx.strokeStyle = Qt.rgba(1, 0.851, 0.761, 0.7 * fadeIn);
                ctx.lineWidth = 1.4 * S;
                ctx.stroke();
                if (fadeIn < 0.6)
                    bead(ctx, bx, by, baseR * (1 - fadeIn), 0, 0, 1 - fadeIn * 1.5);
                return;
            }

            underGlow(ctx, bx, by);
            const land = settling ? (0.7 + 0.3 * e) : 1;
            const breathe = (f === "rest") ? canvas.breathe : 1;
            const r = baseR * breathe * land * (f === "dock" ? root.heatScale : 1);
            bead(ctx, bx, by, r, settling ? (1 - q) * 0.4 : 0, root.flightAng);
        }
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        blurEnabled: true
        blur: 0.34
        blurMax: 8
    }
}
