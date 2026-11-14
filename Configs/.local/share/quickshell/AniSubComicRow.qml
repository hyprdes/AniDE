// AniSub wallpaper-widget comic list row (Comic). File-based component so it
// stays resolvable inside Repeater delegates / Variants templates (immune to
// the QML inline-component "X is not a type" quirk), like LisaGlassIcon & friends.
// GPL-3.0-or-later; see CREDITS.md.
import QtQuick

Rectangle {
    id: comicRow
    property var themePalette: null
    property string coverSource: ""
    property string rowName: ""
    property string rowUrl: ""
    signal activated()

    function mix(c, a) {
        var r = Math.round((c && c.r !== undefined ? c.r : 0.85) * 255);
        var g = Math.round((c && c.g !== undefined ? c.g : 0.92) * 255);
        var b = Math.round((c && c.b !== undefined ? c.b : 0.96) * 255);
        var alpha = Math.max(0.0, Math.min(1.0, a));
        return "rgba(" + r + "," + g + "," + b + "," + alpha.toFixed(3) + ")";
    }

    width: 284
    height: 58
    radius: 10
    color: mix(themePalette ? themePalette.hvrBg : null, 0.55)
    border.width: 2
    border.color: mix(themePalette ? themePalette.borderColor : null, 0.75)

    Image {
        id: coverImage
        visible: false
        x: 6
        y: 6
        width: 34
        height: 46
        source: comicRow.coverSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Canvas {
        id: coverCanvas
        x: 6
        y: 6
        width: 34
        height: 46
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.save();
            ctx.beginPath();
            ctx.roundRect(0, 0, 34, 46, 6, 6);
            ctx.clip();
            if (coverImage.status === Image.Ready && comicRow.coverSource !== "") {
                ctx.drawImage(coverImage, 0, 0, 34, 46);
            } else {
                ctx.fillStyle = comicRow.mix(themePalette ? themePalette.accentSecondary : null, 0.5);
                ctx.fillRect(0, 0, 34, 46);
            }
            ctx.restore();
        }
        Connections {
            target: coverImage
            function onStatusChanged() {
                coverCanvas.requestPaint();
            }
        }
    }

    Text {
        x: 50
        y: 10
        width: 224
        text: comicRow.rowName
        color: themePalette ? themePalette.mainFg : "#2434e0"
        font.pixelSize: 11
        font.bold: true
        elide: Text.ElideRight
    }

    Text {
        x: 50
        y: 30
        width: 224
        text: comicRow.rowUrl
        color: themePalette ? themePalette.subFg : "#5b62c4"
        font.pixelSize: 8
        elide: Text.ElideMiddle
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: comicRow.activated()
    }
}
