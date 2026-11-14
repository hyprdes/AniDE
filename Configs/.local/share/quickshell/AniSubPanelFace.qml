// AniSub panel face: a liquid glass card that drops from the top bar (Win+Shift+M).
// Layout follows image-18: a grab handle, a badge row with the date, a search
// pill, the current film as a poster hero with a "Xem" button, a caption pill,
// and a footer with the result counter and a down arrow that moves to the next
// film. Colors come from the bar palette (themePalette), so the panel follows
// the same wallpaper sync as the bar. The parent runs rofi.movie feed,
// feed-search, episodes and play-episode; this file never opens rofi.
// GPL-3.0-or-later; see CREDITS.md.
import QtQuick

Item {
    id: face
    width: 400
    height: 520

    property var themePalette: null
    property var feedItems: []
    property bool feedLoading: false
    property var searchItems: []
    property bool searchLoading: false
    property string searchQuery: ""
    property var episodes: []
    property bool episodesLoading: false

    signal searchSubmitted(string query)
    signal searchCleared()
    signal closeRequested()
    signal episodesRequested(var film)
    signal playEpisode(var film, var ep)

    // Fallbacks are the image-18 green, used only when no palette is bound
    readonly property color cBar: themePalette ? themePalette.barBg : "#5d8839"
    readonly property color cPlate: themePalette ? themePalette.surfaceBg : "#3a5c37"
    readonly property color cInk: themePalette ? themePalette.mainFg : "#fdfff7"
    readonly property color cSub: themePalette ? themePalette.subFg : "#c5d1ad"
    readonly property color cAct: themePalette ? themePalette.actBg : "#adbc66"
    readonly property color cActInk: themePalette ? themePalette.actFg : "#1e2e1a"
    readonly property color cEdge: themePalette ? themePalette.borderColor : "#4d6d39"
    readonly property color cHover: themePalette ? themePalette.hvrBg : "#4d6d39"

    readonly property int pad: 16
    readonly property int posterW: 150
    readonly property int posterH: 200

    readonly property var items: searchQuery !== "" ? searchItems : feedItems
    readonly property bool loading: searchQuery !== "" ? searchLoading : feedLoading
    property int currentIndex: 0
    readonly property var current: items.length > 0 ? items[Math.min(currentIndex, items.length - 1)] : null
    property bool showingEpisodes: false
    property var episodeFilm: null

    onItemsChanged: currentIndex = 0

    function rgbaStr(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
            + Math.round(c.b * 255) + "," + a + ")";
    }

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

    // Cover-fit poster with rounded corners. The Canvas loads the URL itself
    // (loadImage); the hidden Image only supplies the natural size.
    function paintCover(ctx, cv, img, src, w, h, r) {
        ctx.reset();
        ctx.save();
        roundPath(ctx, 0, 0, w, h, r);
        ctx.clip();
        if (src !== "" && cv.isImageLoaded(src) && img && img.implicitWidth > 0 && img.implicitHeight > 0) {
            const sw = img.implicitWidth;
            const sh = img.implicitHeight;
            const s = Math.max(w / sw, h / sh);
            const cw = w / s;
            const ch = h / s;
            ctx.drawImage(src, (sw - cw) / 2, (sh - ch) / 2, cw, ch, 0, 0, w, h);
        } else {
            ctx.fillStyle = rgbaStr(cPlate, 0.6);
            ctx.fillRect(0, 0, w, h);
        }
        ctx.restore();
    }

    // Vector glyphs: search, close, back and down chevrons
    function paintGlyph(ctx, kind, w, h, color) {
        ctx.reset();
        const s = Math.min(w, h) * 0.22;
        const cx = w / 2;
        const cy = h / 2;
        ctx.strokeStyle = color;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.lineWidth = Math.max(1.6, s * 0.5);
        ctx.beginPath();
        if (kind === "search") {
            ctx.arc(cx - 0.3 * s, cy - 0.3 * s, 1.2 * s, 0, 2 * Math.PI);
            ctx.moveTo(cx + 0.7 * s, cy + 0.7 * s);
            ctx.lineTo(cx + 1.6 * s, cy + 1.6 * s);
        } else if (kind === "close") {
            ctx.moveTo(cx - s, cy - s);
            ctx.lineTo(cx + s, cy + s);
            ctx.moveTo(cx + s, cy - s);
            ctx.lineTo(cx - s, cy + s);
        } else if (kind === "back") {
            ctx.moveTo(cx + 0.5 * s, cy - s);
            ctx.lineTo(cx - 0.6 * s, cy);
            ctx.lineTo(cx + 0.5 * s, cy + s);
        } else if (kind === "down") {
            ctx.moveTo(cx - s, cy - 0.5 * s);
            ctx.lineTo(cx, cy + 0.6 * s);
            ctx.lineTo(cx + s, cy - 0.5 * s);
        }
        ctx.stroke();
    }

    function focusInput() {
        input.forceActiveFocus();
    }

    function submitSearch() {
        const q = input.text.trim();
        if (q.length < 2) return;
        searchQuery = q;
        showingEpisodes = false;
        searchSubmitted(q);
    }

    function clearSearch() {
        input.text = "";
        searchQuery = "";
        showingEpisodes = false;
        searchCleared();
    }

    function nextResult() {
        if (items.length > 0) currentIndex = (currentIndex + 1) % items.length;
    }

    function openEpisodes() {
        if (!current) return;
        episodeFilm = current;
        showingEpisodes = true;
        episodesRequested(current);
    }

    function closeEpisodes() {
        showingEpisodes = false;
        episodeFilm = null;
    }

    // ── Liquid glass card: translucent tint, a white sheen and a bright rim.
    // The wallpaper blur comes from Hyprland's layer blur on the quickshell namespace.
    Rectangle {
        id: card
        anchors.fill: parent
        radius: 30
        color: Qt.alpha(face.cBar, 0.40)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.5)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.24) }
                GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.04) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.10) }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: parent.radius - 3
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.14)
        }
    }

    // Grab handle like the sheet in image-18
    Rectangle {
        x: (face.width - width) / 2
        y: 8
        width: 44
        height: 5
        radius: 3
        color: Qt.rgba(1, 1, 1, 0.6)
    }

    // ── Row 1: count badge, title, and the date pill ──
    GlassPlate {
        id: badge
        x: face.pad
        y: 26
        width: 40
        height: 40
        radius: 20

        Text {
            anchors.centerIn: parent
            text: face.items.length
            color: face.cInk
            font.pixelSize: 13
            font.bold: true
        }
    }

    Column {
        x: face.pad + 52
        y: 28
        spacing: 0

        Text {
            text: "ANISUB"
            color: face.cInk
            font.pixelSize: 13
            font.bold: true
        }
        Text {
            text: "Phim · KKPhim"
            color: face.cSub
            font.pixelSize: 10
        }
    }

    GlassPlate {
        id: datePill
        x: face.width - face.pad - width
        y: 26
        width: 128
        height: 40
        radius: 20

        Column {
            anchors.centerIn: parent
            spacing: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(new Date(), "dddd")
                color: face.cSub
                font.pixelSize: 9
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(new Date(), "dd MMM / yyyy")
                color: face.cInk
                font.pixelSize: 12
                font.bold: true
            }
        }
    }

    // ── Row 2: search pill and close button ──
    GlassPlate {
        id: searchPill
        x: face.pad
        y: 80
        width: face.width - face.pad * 2 - 44 - 10
        height: 44
        radius: 22

        Canvas {
            x: 8
            y: 8
            width: 28
            height: 28
            onPaint: face.paintGlyph(getContext("2d"), "search", width, height, face.rgbaStr(face.cInk, 1))
            Component.onCompleted: requestPaint()
        }

        TextInput {
            id: input
            x: 44
            y: 0
            width: searchPill.width - 56
            height: searchPill.height
            verticalAlignment: TextInput.AlignVCenter
            font.pixelSize: 13
            color: face.cInk
            selectByMouse: true
            clip: true
            onAccepted: face.submitSearch()
            Keys.onEscapePressed: {
                if (text !== "") face.clearSearch();
                else face.closeRequested();
            }
        }

        Text {
            x: 44
            width: searchPill.width - 56
            height: searchPill.height
            verticalAlignment: Text.AlignVCenter
            visible: input.text === ""
            text: "Tìm phim… (Enter)"
            color: Qt.alpha(face.cSub, 0.9)
            font.pixelSize: 13
        }
    }

    GlassPlate {
        id: closeBtn
        x: face.width - face.pad - 44
        y: 80
        width: 44
        height: 44
        radius: 22
        pressedLook: closeArea.pressed

        Canvas {
            anchors.fill: parent
            anchors.margins: 12
            onPaint: face.paintGlyph(getContext("2d"), "close", width, height, face.rgbaStr(face.cInk, 1))
            Component.onCompleted: requestPaint()
        }

        MouseArea {
            id: closeArea
            anchors.fill: parent
            onClicked: face.closeRequested()
        }
    }

    // ── Hero: current film as a poster with title and the "Xem" button ──
    Item {
        id: hero
        visible: !face.showingEpisodes && face.current !== null
        x: face.pad
        y: 140
        width: face.width - face.pad * 2
        height: 250
        readonly property string picSrc: face.current && face.current.thumb ? String(face.current.thumb) : ""

        Image {
            id: heroPic
            visible: false
            asynchronous: true
            cache: true
            source: hero.picSrc
            fillMode: Image.PreserveAspectCrop
        }

        Canvas {
            id: heroCanvas
            x: hero.width - face.posterW
            y: 0
            width: face.posterW
            height: face.posterH
            onPaint: face.paintCover(getContext("2d"), heroCanvas, heroPic, hero.picSrc, width, height, 18)
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onImageLoaded: requestPaint()
            Component.onCompleted: if (hero.picSrc !== "") loadImage(hero.picSrc)
            Connections {
                target: hero
                function onPicSrcChanged() {
                    if (hero.picSrc !== "") heroCanvas.loadImage(hero.picSrc);
                    heroCanvas.requestPaint();
                }
            }
            Connections {
                target: heroPic
                function onStatusChanged() { heroCanvas.requestPaint(); }
            }
        }

        // Status chip: result position, or the feed label when not searching
        GlassPlate {
            id: statusChip
            x: 0
            y: 0
            width: Math.min(hero.width - face.posterW - 12, chipText.implicitWidth + 20)
            height: 24
            radius: 12

            Text {
                id: chipText
                anchors.centerIn: parent
                width: parent.width - 20
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                text: face.searchQuery !== ""
                    ? "Kết quả " + (face.currentIndex + 1) + " / " + face.items.length
                    : "Phim hot"
                color: face.cInk
                font.pixelSize: 10
                font.bold: true
            }
        }

        Text {
            x: 0
            y: 36
            width: hero.width - face.posterW - 12
            height: 64
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 2
            text: face.current ? face.current.name : ""
            color: face.cInk
            font.pixelSize: 20
            font.bold: true
        }

        Text {
            x: 0
            y: 104
            width: hero.width - face.posterW - 12
            height: 40
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 2
            text: face.current ? (face.current.info || "") : ""
            color: face.cSub
            font.pixelSize: 11
        }

        Rectangle {
            id: xemBtn
            x: 0
            y: 160
            width: 112
            height: 36
            radius: 18
            color: xemArea.pressed ? face.cHover : face.cAct

            Text {
                anchors.centerIn: parent
                text: "Xem"
                color: face.cActInk
                font.pixelSize: 13
                font.bold: true
            }

            MouseArea {
                id: xemArea
                anchors.fill: parent
                onClicked: face.openEpisodes()
            }
        }

        // Caption pill across the bottom of the hero
        GlassPlate {
            id: caption
            x: 0
            y: 206
            width: hero.width
            height: 44
            radius: 22

            Text {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                text: face.current ? ((face.current.type ? face.current.type + " · " : "") + (face.current.slug || "")) : ""
                color: face.cInk
                font.pixelSize: 11
            }
        }
    }

    // ── Empty / loading states for the body ──
    Text {
        visible: !face.showingEpisodes && face.current === null
        x: face.pad
        y: 140
        width: face.width - face.pad * 2
        height: 250
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        text: face.loading
            ? (face.searchQuery !== "" ? "Đang tìm “" + face.searchQuery + "”…" : "Đang tải phim…")
            : (face.searchQuery !== "" ? "Không có kết quả cho “" + face.searchQuery + "”" : "Chưa có phim để hiển thị")
        color: face.cInk
        font.pixelSize: 13
    }

    Rectangle {
        visible: !face.showingEpisodes && face.current !== null
        x: face.pad
        y: face.height - 102
        width: face.width - face.pad * 2
        height: 1
        color: Qt.rgba(1, 1, 1, 0.30)
    }

    // ── Footer: result counter and the down arrow that moves to the next film ──
    Item {
        id: footer
        visible: !face.showingEpisodes && face.current !== null
        x: face.pad
        y: face.height - 92
        width: face.width - face.pad * 2
        height: 40

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - nextBtn.width - 12
            elide: Text.ElideRight
            text: (face.currentIndex + 1) + " / " + face.items.length
                + (face.searchQuery !== "" ? "  ·  “" + face.searchQuery + "”" : "  ·  phim hot")
            color: face.cInk
            font.pixelSize: 11
            font.bold: true
        }

        GlassPlate {
            id: nextBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            radius: 20
            pressedLook: nextArea.pressed

            Canvas {
                anchors.fill: parent
                anchors.margins: 12
                onPaint: face.paintGlyph(getContext("2d"), "down", width, height, face.rgbaStr(face.cInk, 1))
                Component.onCompleted: requestPaint()
            }

            MouseArea {
                id: nextArea
                anchors.fill: parent
                onClicked: face.nextResult()
            }
        }
    }

    Text {
        visible: !face.showingEpisodes
        x: face.pad
        y: face.height - 36
        width: face.width - face.pad * 2
        horizontalAlignment: Text.AlignHCenter
        text: "Enter để tìm · Esc để đóng"
        color: Qt.alpha(face.cSub, 0.9)
        font.pixelSize: 9
    }

    // ── Episode mode: back button, film name, and one pill per episode ──
    GlassPlate {
        id: backBtn
        visible: face.showingEpisodes
        x: face.pad
        y: 140
        width: 40
        height: 40
        radius: 20
        pressedLook: backArea.pressed

        Canvas {
            anchors.fill: parent
            anchors.margins: 12
            onPaint: face.paintGlyph(getContext("2d"), "back", width, height, face.rgbaStr(face.cInk, 1))
            Component.onCompleted: requestPaint()
        }

        MouseArea {
            id: backArea
            anchors.fill: parent
            onClicked: face.closeEpisodes()
        }
    }

    Text {
        visible: face.showingEpisodes
        x: face.pad + 52
        y: 140
        width: face.width - face.pad * 2 - 52
        height: 40
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: face.episodeFilm ? face.episodeFilm.name : ""
        color: face.cInk
        font.pixelSize: 15
        font.bold: true
    }

    ListView {
        id: episodeList
        visible: face.showingEpisodes && face.episodes.length > 0
        x: face.pad
        y: 190
        width: face.width - face.pad * 2
        height: face.height - 190 - 16
        clip: true
        spacing: 6
        boundsBehavior: Flickable.StopAtBounds
        model: face.episodes

        delegate: GlassPlate {
            id: epRow
            required property var modelData
            width: episodeList.width
            height: 40
            radius: 20
            pressedLook: epArea.pressed

            Text {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                width: epRow.width - 32
                elide: Text.ElideRight
                text: epRow.modelData.name
                color: face.cInk
                font.pixelSize: 13
                font.bold: true
            }

            MouseArea {
                id: epArea
                anchors.fill: parent
                onClicked: face.playEpisode(face.episodeFilm, epRow.modelData)
            }
        }
    }

    Text {
        visible: face.showingEpisodes && face.episodes.length === 0
        x: face.pad
        y: 190
        width: face.width - face.pad * 2
        height: 120
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        text: face.episodesLoading ? "Đang tải danh sách tập…" : "Phim này chưa có tập phát."
        color: face.cInk
        font.pixelSize: 13
    }
}
