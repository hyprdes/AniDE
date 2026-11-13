// LisaGlassIcon: @lisa.p.ng 4-layer glassmorphic duo-tone icon (image-10.png error-state icon set)
// Layer 1: vibrant orange-coral offset backing shape | Layer 2: frosted indigo-violet glass + warm bleed
// Layer 3: crisp white specular rim arc + corner spark | Layer 4: snow-white foreground glyph
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

    implicitWidth: 28
    implicitHeight: 28

    // Layer 1 — vibrant orange-coral offset backing shape
    Rectangle {
        x: iconRoot.width * 0.16
        y: iconRoot.height * 0.15
        width: iconRoot.width * 0.82
        height: iconRoot.height * 0.78
        radius: width * 0.36
        rotation: -8
        color: iconRoot.accentColor
    }

    // Layer 2 — frosted indigo-violet glass foreground + warm orange inner refraction bleed
    Item {
        x: 0
        y: iconRoot.height * 0.04
        width: iconRoot.width * 0.92
        height: iconRoot.height * 0.88

        Rectangle {
            width: parent.width * 0.92
            height: parent.height * 0.92
            radius: width * 0.36
            rotation: -6
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#e6686de0" }
                GradientStop { position: 0.55; color: "#e6454d9c" }
                GradientStop { position: 1.0; color: "#e6353d8c" }
            }
        }
        Rectangle {
            x: parent.width * 0.10
            y: parent.height * 0.56
            width: parent.width * 0.42
            height: parent.height * 0.32
            radius: width * 0.5
            rotation: -10
            color: "#4d662209"
        }
        Rectangle {
            x: parent.width * 0.16
            y: parent.height * 0.60
            width: parent.width * 0.30
            height: parent.height * 0.22
            radius: width * 0.5
            rotation: -10
            color: "#33662209"
        }
    }

    // Layer 3 — crisp rounded pure-white specular rim arc along the outer curve
    Canvas {
        id: rimCanvas
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = "#ffffff";
            ctx.lineWidth = Math.max(1.6, iconRoot.width * 0.07);
            ctx.lineCap = "round";
            ctx.beginPath();
            var s = iconRoot.arcStart * Math.PI / 180;
            var e = (iconRoot.arcStart + iconRoot.arcSweep) * Math.PI / 180;
            ctx.arc(iconRoot.width * 0.46, iconRoot.height * 0.5, iconRoot.width * 0.44, s, e);
            ctx.stroke();
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    // tiny white + corner spark
    Text {
        x: iconRoot.width * iconRoot.sparkX - width / 2
        y: iconRoot.height * iconRoot.sparkY - height / 2
        rotation: iconRoot.sparkRot
        text: iconRoot.sparkSize > 0.1 ? "+" : ""
        font.pixelSize: iconRoot.width * iconRoot.sparkSize * 2.2
        font.bold: true
        color: "#ffffff"
    }

    // Layer 4 — snow-white foreground glyph
    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: iconRoot.height * 0.04
        text: iconRoot.glyph
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: iconRoot.width * iconRoot.glyphScale
        font.bold: true
        color: "#ffffff"
    }
}
