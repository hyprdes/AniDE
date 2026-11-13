// LisaGlassIcon: @lisa.p.ng 4-layer glassmorphic duo-tone icon (image-10.png error-state icon set)
// Layer 1: vibrant orange-coral organic backing (blob / orbit ring / tilted card)
// Layer 2: thin orange outline echo (signature of the set)
// Layer 3: frosted glass with warm orange -> violet -> deep royal blue gradient + warm inner bleed
// Layer 4: delicate white rim arcs + rounded corner spark
// Layer 5: snow-white foreground glyph
// File-based component (not inline): immune to QML inline-component ordering quirks ("X is not a type").
import QtQuick

Item {
    id: iconRoot
    property string glyph: ""
    property real glyphScale: 0.50
    property color accentColor: "#ff4f18"
    property real arcStart: -205
    property real arcSweep: 95
    property real sparkX: 0.82
    property real sparkY: 0.16
    property real sparkSize: 0.13
    property real sparkRot: 0
    // 0 = offset organic blob, 1 = orbit ring, 2 = tilted backing card
    property int variant: 0

    implicitWidth: 28
    implicitHeight: 28

    onVariantChanged: art.requestPaint()
    onAccentColorChanged: art.requestPaint()
    onArcStartChanged: art.requestPaint()
    onArcSweepChanged: art.requestPaint()
    onSparkXChanged: art.requestPaint()
    onSparkYChanged: art.requestPaint()
    onSparkSizeChanged: art.requestPaint()
    onSparkRotChanged: art.requestPaint()

    Canvas {
        id: art
        anchors.fill: parent
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var w = width;
            var h = height;
            if (w <= 2 || h <= 2) return;

            // organic squircle-blob path (superellipse)
            function blob(cx, cy, rx, ry, rot, n) {
                var steps = 72;
                ctx.save();
                ctx.translate(cx, cy);
                ctx.rotate(rot * Math.PI / 180);
                ctx.beginPath();
                for (var i = 0; i <= steps; i++) {
                    var t = i / steps * Math.PI * 2;
                    var ct = Math.cos(t);
                    var st = Math.sin(t);
                    var x = rx * Math.sign(ct) * Math.pow(Math.abs(ct), 2 / n);
                    var y = ry * Math.sign(st) * Math.pow(Math.abs(st), 2 / n);
                    if (i === 0) ctx.moveTo(x, y);
                    else ctx.lineTo(x, y);
                }
                ctx.closePath();
                ctx.restore();
            }

            var cx = w * 0.485;
            var cy = h * 0.52;

            // ── Layer 1: vibrant orange-coral backing ──
            ctx.fillStyle = iconRoot.accentColor;
            if (iconRoot.variant === 1) {
                // orbit ring crossing behind the glass + soft backing blob
                blob(cx + w * 0.115, cy + h * 0.115, w * 0.365, h * 0.345, -12, 3.2);
                ctx.fill();
                ctx.save();
                ctx.translate(cx, cy);
                ctx.rotate(-24 * Math.PI / 180);
                ctx.beginPath();
                ctx.ellipse(0, 0, w * 0.485, h * 0.24, 0, 0, Math.PI * 2);
                ctx.lineWidth = w * 0.085;
                ctx.strokeStyle = iconRoot.accentColor;
                ctx.stroke();
                ctx.restore();
            } else if (iconRoot.variant === 2) {
                // tilted rounded backing card
                blob(cx + w * 0.125, cy - h * 0.095, w * 0.415, h * 0.345, 20, 5.4);
                ctx.fill();
            } else {
                // offset organic blob
                blob(cx + w * 0.15, cy + h * 0.13, w * 0.375, h * 0.355, -10, 3.2);
                ctx.fill();
            }

            // ── Layer 2: thin orange outline echo (signature of the set) ──
            ctx.beginPath();
            blob(cx + w * 0.075, cy - h * 0.06, w * 0.455, h * 0.435, -6, 3.4);
            ctx.strokeStyle = iconRoot.accentColor;
            ctx.lineWidth = w * 0.034;
            ctx.lineJoin = "round";
            ctx.stroke();

            // ── Layer 3: frosted glass, warm orange -> violet -> deep royal blue ──
            blob(cx - w * 0.015, cy - h * 0.01, w * 0.405, h * 0.385, -6, 3.4);
            var glass = ctx.createLinearGradient(cx - w * 0.10, cy - h * 0.42, cx + w * 0.10, cy + h * 0.42);
            glass.addColorStop(0.00, "#e77a52");
            glass.addColorStop(0.26, "#b25f92");
            glass.addColorStop(0.58, "#7a55a8");
            glass.addColorStop(1.00, "#2b2fa6");
            ctx.fillStyle = glass;
            ctx.fill();

            // warm orange inner refraction bleed (clipped inside the glass)
            ctx.save();
            blob(cx - w * 0.015, cy - h * 0.01, w * 0.405, h * 0.385, -6, 3.4);
            ctx.clip();
            var bleed = ctx.createRadialGradient(cx + w * 0.02, cy - h * 0.2, w * 0.02, cx + w * 0.02, cy - h * 0.2, w * 0.52);
            bleed.addColorStop(0.0, "rgba(255,106,42,0.55)");
            bleed.addColorStop(0.55, "rgba(255,106,42,0.16)");
            bleed.addColorStop(1.0, "rgba(255,106,42,0)");
            ctx.fillStyle = bleed;
            ctx.fillRect(0, 0, w, h);
            // deep cool base shading
            var shade = ctx.createLinearGradient(0, cy, 0, h);
            shade.addColorStop(0.0, "rgba(20,22,90,0)");
            shade.addColorStop(1.0, "rgba(14,16,72,0.35)");
            ctx.fillStyle = shade;
            ctx.fillRect(0, 0, w, h);
            ctx.restore();

            // ── Layer 4: delicate white rim arcs + chunky corner spark ──
            ctx.lineCap = "round";
            ctx.strokeStyle = "#ffffff";
            var r = w * 0.432;
            var main = iconRoot.arcStart * Math.PI / 180;
            var mainEnd = (iconRoot.arcStart + iconRoot.arcSweep) * Math.PI / 180;
            ctx.lineWidth = w * 0.045;
            ctx.beginPath();
            ctx.arc(cx, cy, r, main, mainEnd);
            ctx.stroke();
            // short secondary rim segment on the opposite edge
            var sec = (iconRoot.arcStart + 158) * Math.PI / 180;
            ctx.lineWidth = w * 0.04;
            ctx.beginPath();
            ctx.arc(cx, cy, r, sec, sec + 0.58);
            ctx.stroke();

            if (iconRoot.sparkSize > 0.1) {
                var sx = w * iconRoot.sparkX;
                var sy = h * iconRoot.sparkY;
                var L = w * iconRoot.sparkSize * 1.95;
                ctx.save();
                ctx.translate(sx, sy);
                ctx.rotate(iconRoot.sparkRot * Math.PI / 180);
                ctx.lineWidth = L * 0.30;
                ctx.beginPath();
                ctx.moveTo(-L / 2, 0);
                ctx.lineTo(L / 2, 0);
                ctx.moveTo(0, -L / 2);
                ctx.lineTo(0, L / 2);
                ctx.stroke();
                ctx.restore();
            }
        }
    }

    // Layer 5 — snow-white foreground glyph
    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: iconRoot.height * 0.03
        text: iconRoot.glyph
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: iconRoot.width * iconRoot.glyphScale
        font.bold: true
        color: "#ffffff"
    }
}
