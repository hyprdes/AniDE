// FrameBump: a tongue that grows out of a straight frame edge and blends into
// it through concave shoulders (the notch on top, the title tab at the bottom).
// Same trick as RoundCorner: one filled Canvas path in the frame color, no
// outline, so the joint with the edge is seamless.
// File-based component (not inline): immune to QML inline-component ordering quirks ("X is not a type").
import QtQuick

Canvas {
    id: root
    property color fillColor: "#f2f2f2"
    property real fillAlpha: 1.0
    // true: hangs down from an edge above it; false: stands on an edge below it
    property bool pointsDown: true
    // radius of the concave curve where the bump meets the edge
    property real shoulder: 10
    // radius of the convex corners at the free end
    property real bodyRadius: 12
    // > 0: each side is one long S-curve this wide (the notch of image-1)
    // instead of a shoulder arc + straight side + corner arc
    property real sweep: 0

    antialiasing: true
    smooth: true

    onFillColorChanged: requestPaint()
    onFillAlphaChanged: requestPaint()
    onPointsDownChanged: requestPaint()
    onShoulderChanged: requestPaint()
    onBodyRadiusChanged: requestPaint()
    onSweepChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        if (root.fillAlpha <= 0.001 || width <= 2 || height <= 2) return;
        var w = width;
        var h = height;
        var s = Math.max(0, Math.min(root.shoulder, h, w / 4));
        var r = Math.max(0, Math.min(root.bodyRadius, h - s, (w - 2 * s) / 2));

        // The path is written for a bump hanging from y = 0; a tab is its mirror image
        if (!root.pointsDown) {
            ctx.translate(0, h);
            ctx.scale(1, -1);
        }

        ctx.fillStyle = Qt.alpha(root.fillColor, root.fillAlpha);
        ctx.beginPath();
        ctx.moveTo(0, 0);
        if (root.sweep > 0) {
            // Both control points lie on the two horizontals, so the curve
            // leaves the edge and reaches the free end without a kink.
            // 0.5 / 0.35 are fitted to the notch outline of image-1: a short
            // concave start, a slanted side, a wide round corner at the free end.
            var sw = Math.min(root.sweep, w / 2);
            var k1 = sw * 0.5;
            var k2 = sw * 0.35;
            ctx.bezierCurveTo(k1, 0, k2, h, sw, h);
            ctx.lineTo(w - sw, h);
            ctx.bezierCurveTo(w - k2, h, w - k1, 0, w, 0);
            ctx.closePath();
            ctx.fill();
            return;
        }
        ctx.arc(0, s, s, -Math.PI / 2, 0, false);               // left shoulder (concave)
        ctx.lineTo(s, h - r);
        ctx.arc(s + r, h - r, r, Math.PI, Math.PI / 2, true);   // left free corner
        ctx.lineTo(w - s - r, h);
        ctx.arc(w - s - r, h - r, r, Math.PI / 2, 0, true);     // right free corner
        ctx.lineTo(w - s, s);
        ctx.arc(w, s, s, Math.PI, Math.PI * 1.5, false);        // right shoulder (concave)
        ctx.closePath();
        ctx.fill();
    }
}
