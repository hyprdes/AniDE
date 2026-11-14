// AniSub wallpaper-widget face (Movie + Comic) — radio-style card from image-15.
// Design units 280 x 320; the parent scales it freely (resize grip), so every
// size here is in design units. Layout:
//   white display  : small header, big title, info line, current thumbnail on the edge
//   dial ruler     : one tick per feed item, red needle = current item
//   transport      : previous / open current item / next
// File-based component (same pattern as LisaGlassIcon) so it resolves inside
// Repeater / Variants templates. Colors come in as themePalette (theme.xxx).
// GPL-3.0-or-later; see CREDITS.md.
import QtQuick

Item {
    id: face
    width: 280
    height: 320

    property var themePalette: null
    property string headerText: ""
    property string placeholderText: "Đang tải…"
    property var items: []
    property int currentIndex: 0

    signal openRequested(int index)

    readonly property color cBlue: themePalette ? themePalette.mainFg : "#2434e0"
    readonly property color cWhite: themePalette ? themePalette.surfaceBg : "#ffffff"
    readonly property color cGray: themePalette ? themePalette.subFg : "#5b62c4"
    readonly property color cPink: themePalette ? themePalette.glowColor : "#e8449b"
    readonly property color cBorder: themePalette ? themePalette.borderColor : "#2233dd"
    readonly property color cPale: themePalette ? themePalette.accentSecondary : "#c9d2f7"
    readonly property color cButton: Qt.lighter(cBlue, 1.25)

    readonly property int count: items.length > 0 ? items.length : 1
    readonly property var current: items.length > 0 ? items[Math.min(currentIndex, items.length - 1)] : null

    onItemsChanged: currentIndex = Math.max(0, Math.min(currentIndex, items.length - 1))

    function rgbaStr(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
            + Math.round(c.b * 255) + "," + a + ")";
    }

    // Rounded-rect path built from arcTo (ctx.roundRect is not available on every Qt build)
    function roundPath(ctx, x, y, w, h, r) {
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.lineTo(x + w - r, y);
        ctx.arcTo(x + w, y, x + w, y + r, r);
        ctx.lineTo(x + w, y + h - r);
        ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
        ctx.lineTo(x + r, y + h);
        ctx.arcTo(x, y + h, x, y + h - r, r);
        ctx.lineTo(x, y + r);
        ctx.arcTo(x, y, x + r, y, r);
        ctx.closePath();
    }

    // Body: pale-cobalt wallpaper-synced card, no gradient
    Rectangle {
        id: body
        anchors.fill: parent
        radius: 26
        color: face.cBlue
    }

    // White display panel (top part, rounded all round like image-15)
    Rectangle {
        id: display
        x: 0
        y: 0
        width: face.width
        height: 200
        radius: 26
        color: face.cWhite
        border.width: 2
        border.color: face.cBorder
    }

    Text {
        id: header
        x: 16
        y: 22
        width: face.width - 32
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: face.headerText
        color: face.cGray
        font.pixelSize: 11
    }

    Text {
        id: title
        x: 16
        y: 54
        width: face.width - 32
        height: 36
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: face.current ? face.current.name : face.placeholderText
        color: face.cBlue
        font.pixelSize: 22
        font.bold: true
    }

    Text {
        id: info
        x: 16
        y: 96
        width: face.width - 32
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: face.current ? (face.current.info || "") : ""
        color: face.cGray
        font.pixelSize: 12
    }

    // Current item thumbnail sitting on the white/blue edge (image-15 mascot slot)
    Rectangle {
        id: thumb
        x: (face.width - width) / 2
        y: 164
        width: 44
        height: 44
        radius: 14
        color: face.cWhite
        border.width: 3
        border.color: face.cBlue

        Image {
            id: thumbImage
            visible: false
            anchors.fill: parent
            anchors.margins: 3
            source: face.current && face.current.thumb ? face.current.thumb : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Canvas {
            id: thumbCanvas
            anchors.fill: parent
            anchors.margins: 3

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.save();
                face.roundPath(ctx, 0, 0, width, height, 10);
                ctx.clip();
                if (thumbImage.status === Image.Ready) {
                    ctx.drawImage(thumbImage, 0, 0, width, height);
                } else {
                    ctx.fillStyle = face.rgbaStr(face.cPale, 1);
                    ctx.fillRect(0, 0, width, height);
                }
                ctx.restore();
            }

            Connections {
                target: thumbImage
                function onStatusChanged() { thumbCanvas.requestPaint(); }
                function onSourceChanged() { thumbCanvas.requestPaint(); }
            }
        }
    }

    // Dial ruler: track pans so the current item sits under the needle
    Item {
        id: rulerClip
        x: 0
        y: 222
        width: face.width
        height: 42
        clip: true

        Item {
            id: track
            y: 0
            width: 1
            height: parent.height
            x: -face.currentIndex * 40
            Behavior on x {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            // Tick every 4 design units; label centres at 140 + i*40
            Repeater {
                model: Math.floor(((face.count - 1) * 40 + 280) / 4) + 1

                Rectangle {
                    required property int index
                    readonly property int tx: index * 4
                    x: tx
                    y: 0
                    width: 2
                    height: tx % 40 === 20 ? 22 : (tx % 40 === 0 ? 14 : 8)
                    color: Qt.rgba(1, 1, 1, 0.85)
                }
            }

            Repeater {
                model: face.count

                Text {
                    required property int index
                    x: 140 + index * 40 - width / 2
                    y: 26
                    width: 30
                    horizontalAlignment: Text.AlignHCenter
                    text: face.items.length > 0 ? String(index + 1) : "–"
                    color: Qt.rgba(1, 1, 1, index === face.currentIndex ? 1.0 : 0.55)
                    font.pixelSize: index === face.currentIndex ? 11 : 9
                    font.bold: index === face.currentIndex
                }
            }
        }
    }

    // Red needle (fixed, centre)
    Rectangle {
        id: needle
        x: 139
        y: 218
        width: 2
        height: 24
        radius: 1
        color: face.cPink
    }

    // ── Transport: previous / open current / next ──
    Rectangle {
        id: prevBtn
        x: 12
        y: 270
        width: 72
        height: 40
        radius: 14
        color: prevArea.pressed ? Qt.lighter(face.cBlue, 1.5) : face.cButton

        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var s = Math.min(width, height) * 0.22;
                var cx = width / 2;
                var cy = height / 2;
                ctx.fillStyle = face.rgbaStr(face.cWhite, 1);
                ctx.beginPath();
                ctx.moveTo(cx - 0.8 * s, cy);
                ctx.lineTo(cx + 0.9 * s, cy - s);
                ctx.lineTo(cx + 0.9 * s, cy + s);
                ctx.closePath();
                ctx.fill();
                ctx.fillRect(cx - 1.25 * s, cy - s, 0.3 * s, 2 * s);
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
        }

        MouseArea {
            id: prevArea
            anchors.fill: parent
            onClicked: face.currentIndex = Math.max(0, face.currentIndex - 1)
        }
    }

    Rectangle {
        id: playBtn
        x: 96
        y: 270
        width: 88
        height: 40
        radius: 14
        color: playArea.pressed ? Qt.lighter(face.cBlue, 1.5) : face.cButton

        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var s = Math.min(width, height) * 0.22;
                var cx = width / 2;
                var cy = height / 2;
                ctx.fillStyle = face.rgbaStr(face.cWhite, 1);
                ctx.beginPath();
                ctx.moveTo(cx - 0.7 * s, cy - 1.1 * s);
                ctx.lineTo(cx + 1.0 * s, cy);
                ctx.lineTo(cx - 0.7 * s, cy + 1.1 * s);
                ctx.closePath();
                ctx.fill();
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
        }

        MouseArea {
            id: playArea
            anchors.fill: parent
            onClicked: face.openRequested(face.currentIndex)
        }
    }

    Rectangle {
        id: nextBtn
        x: 196
        y: 270
        width: 72
        height: 40
        radius: 14
        color: nextArea.pressed ? Qt.lighter(face.cBlue, 1.5) : face.cButton

        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var s = Math.min(width, height) * 0.22;
                var cx = width / 2;
                var cy = height / 2;
                ctx.fillStyle = face.rgbaStr(face.cWhite, 1);
                ctx.beginPath();
                ctx.moveTo(cx + 0.8 * s, cy);
                ctx.lineTo(cx - 0.9 * s, cy - s);
                ctx.lineTo(cx - 0.9 * s, cy + s);
                ctx.closePath();
                ctx.fill();
                ctx.fillRect(cx + 0.95 * s, cy - s, 0.3 * s, 2 * s);
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
        }

        MouseArea {
            id: nextArea
            anchors.fill: parent
            onClicked: face.currentIndex = Math.min(face.count - 1, face.currentIndex + 1)
        }
    }
}
