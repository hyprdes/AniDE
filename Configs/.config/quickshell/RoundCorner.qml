import QtQuick

Canvas {
    id: root
    property int cornerSize: 24
    property color fillColor: "#05070b"
    property real fillAlpha: 0.28
    property color strokeColor: "#b8f2ff"
    property real strokeAlpha: 0.38
    property real strokeWidth: 1.3
    // "top-left" | "top-right" | "bottom-left" | "bottom-right"
    property string corner: "top-left"

    width: cornerSize
    height: cornerSize
    antialiasing: true
    smooth: true

    function cssRgba(c, a) {
        var r = Math.round((c.r !== undefined ? c.r : 0.02) * 255);
        var g = Math.round((c.g !== undefined ? c.g : 0.03) * 255);
        var b = Math.round((c.b !== undefined ? c.b : 0.05) * 255);
        var alpha = Math.max(0.0, Math.min(1.0, a));
        return "rgba(" + r + "," + g + "," + b + "," + alpha.toFixed(3) + ")";
    }

    onFillColorChanged: requestPaint()
    onFillAlphaChanged: requestPaint()
    onStrokeColorChanged: requestPaint()
    onStrokeAlphaChanged: requestPaint()
    onCornerSizeChanged: requestPaint()
    onCornerChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        ctx.fillStyle = cssRgba(root.fillColor, root.fillAlpha);
        ctx.beginPath();

        if (root.corner === "top-left") {
            ctx.moveTo(0, 0);
            ctx.lineTo(width, 0);
            ctx.arc(width, height, width, -Math.PI / 2, Math.PI, true);
        } else if (root.corner === "top-right") {
            ctx.moveTo(width, 0);
            ctx.lineTo(0, 0);
            ctx.arc(0, height, width, -Math.PI / 2, 0, false);
        } else if (root.corner === "bottom-left") {
            ctx.moveTo(0, height);
            ctx.lineTo(width, height);
            ctx.arc(width, 0, width, Math.PI / 2, Math.PI, false);
        } else if (root.corner === "bottom-right") {
            ctx.moveTo(width, height);
            ctx.lineTo(0, height);
            ctx.arc(0, 0, width, Math.PI / 2, 0, true);
        }

        ctx.closePath();
        ctx.fill();

        // Luminous frosted inner arc tracing the rounded screen corner (like the frame border in image-4)
        if (root.strokeWidth > 0) {
            ctx.beginPath();
            ctx.lineWidth = root.strokeWidth;
            ctx.strokeStyle = cssRgba(root.strokeColor, root.strokeAlpha);
            var r = Math.max(1, width - root.strokeWidth * 0.5);
            if (root.corner === "top-left") {
                ctx.arc(width, height, r, -Math.PI / 2, Math.PI, true);
            } else if (root.corner === "top-right") {
                ctx.arc(0, height, r, -Math.PI / 2, 0, false);
            } else if (root.corner === "bottom-left") {
                ctx.arc(width, 0, r, Math.PI / 2, Math.PI, false);
            } else if (root.corner === "bottom-right") {
                ctx.arc(0, 0, r, Math.PI / 2, 0, true);
            }
            ctx.stroke();
        }
    }
}
