// AniSub wallpaper-widget poster tile (Movie). File-based component so it stays
// resolvable inside Repeater delegates / Variants templates (immune to the QML
// inline-component "X is not a type" quirk), like LisaGlassIcon & friends.
// GPL-3.0-or-later; see CREDITS.md.
import QtQuick

Rectangle {
    id: posterTile
    property var themePalette: null
    property string posterSource: ""
    property string posterName: ""
    signal activated()

    function mix(c, a) {
        var r = Math.round((c && c.r !== undefined ? c.r : 0.85) * 255);
        var g = Math.round((c && c.g !== undefined ? c.g : 0.92) * 255);
        var b = Math.round((c && c.b !== undefined ? c.b : 0.96) * 255);
        var alpha = Math.max(0.0, Math.min(1.0, a));
        return "rgba(" + r + "," + g + "," + b + "," + alpha.toFixed(3) + ")";
    }

    width: 88
    height: 124
    radius: 12
    color: mix(themePalette ? themePalette.layer2Bg : null, 0.92)
    border.width: 2
    border.color: themePalette ? themePalette.borderColor : "#2233dd"

    Image {
        id: posterImage
        visible: false
        anchors.fill: parent
        source: posterTile.posterSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Canvas {
        id: posterCanvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.save();
            ctx.beginPath();
            ctx.roundRect(0, 0, width, height, 12, 12);
            ctx.clip();
            if (posterImage.status === Image.Ready && posterTile.posterSource !== "") {
                ctx.drawImage(posterImage, 0, 0, width, height);
            } else {
                ctx.fillStyle = posterTile.mix(themePalette ? themePalette.accentSecondary : null, 0.5);
                ctx.fillRect(0, 0, width, height);
                ctx.fillStyle = posterTile.mix(themePalette ? themePalette.mainFg : null, 0.7);
                ctx.font = "26px sans-serif";
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.fillText("▶", width / 2, height / 2);
            }
            ctx.restore();
        }
        Connections {
            target: posterImage
            function onStatusChanged() {
                posterCanvas.requestPaint();
            }
        }
    }

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: 4
        }
        height: 26
        radius: 8
        color: posterTile.mix(themePalette ? themePalette.barBg : null, 0.88)

        Text {
            anchors.fill: parent
            anchors.margins: 4
            text: posterTile.posterName
            color: themePalette ? themePalette.mainFg : "#2434e0"
            font.pixelSize: 8
            font.bold: true
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignVCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: posterTile.activated()
    }
}
