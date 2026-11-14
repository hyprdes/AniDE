// AniSub movie wallpaper widget face: glass style after the reference card.
// Idle: only the search pill floats on the wallpaper (no card background).
// Searching: a frosted glass card shows the current result as a poster hero
// with a "Xem" button (opens its episode list) and a down arrow that moves to
// the next result. Nothing here opens rofi: the parent runs rofi.movie
// feed-search / episodes / play-episode and feeds the results back in.
// The parent sets width and height (free resize) and dragTarget (the card).
// File-based component so it resolves inside Variants / PanelWindow templates.
// GPL-3.0-or-later; see CREDITS.md.
import QtQuick

Item {
    id: face

    property var themePalette: null
    property var searchItems: []
    property bool searchLoading: false
    property bool searchActive: false
    property string searchQuery: ""
    property int currentIndex: 0
    property var episodes: []
    property bool episodesLoading: false
    property var episodeFilm: null
    property bool showingEpisodes: false
    property Item dragTarget: null

    signal searchSubmitted(string query)
    signal searchCleared()
    signal episodesRequested(var film)
    signal playEpisode(var film, var ep)
    signal dragReleased()

    // Sizes follow the card; the smaller ratio keeps everything inside it
    readonly property real u: Math.max(0.6, Math.min(width / 280, height / 340))
    readonly property real pad: Math.round(12 * u)
    readonly property real pillH: Math.max(32, Math.round(40 * u))
    readonly property real pillY: pad
    readonly property real bodyY: pillY + pillH + pad
    readonly property real footH: Math.max(40, Math.round(50 * u))
    readonly property real footY: height - pad - footH
    readonly property real heroH: Math.max(60, footY - pad - bodyY)
    readonly property real cornerR: Math.round(28 * u)
    readonly property real fontSm: Math.max(8, Math.round(11 * u))
    readonly property real fontMd: Math.max(10, Math.round(14 * u))
    readonly property real fontLg: Math.max(12, Math.round(18 * u))

    readonly property color cInk: "#16203a"
    readonly property color cWhite: "#ffffff"
    readonly property color cGlassStrong: Qt.rgba(1, 1, 1, 0.55)
    readonly property color cEdge: Qt.rgba(1, 1, 1, 0.75)

    readonly property bool idle: !searchActive
    readonly property bool showingResults: searchActive && searchQuery !== ""
    readonly property var current: searchItems.length > 0
        ? searchItems[Math.min(currentIndex, searchItems.length - 1)] : null

    // Input shape for the window: the bare pill while idle, the whole card otherwise
    readonly property Item maskItem: idle ? pill : glass

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

    // Cover-fit poster, rounded corners. The Canvas loads the URL (loadImage);
    // the hidden Image item only supplies the natural size.
    function paintCover(ctx, cv, img, src, w, h, r) {
        ctx.reset();
        ctx.save();
        roundPath(ctx, 0, 0, w, h, r);
        ctx.clip();
        if (src !== "" && cv.isImageLoaded(src) && img && img.implicitWidth > 0 && img.implicitHeight > 0) {
            var sw = img.implicitWidth;
            var sh = img.implicitHeight;
            var s = Math.max(w / sw, h / sh);
            var cw = w / s;
            var ch = h / s;
            ctx.drawImage(src, (sw - cw) / 2, (sh - ch) / 2, cw, ch, 0, 0, w, h);
        } else {
            ctx.fillStyle = rgbaStr(Qt.rgba(1, 1, 1, 1), 0.18);
            ctx.fillRect(0, 0, w, h);
        }
        ctx.restore();
    }

    // Vector glyphs: search, close, back and down chevrons
    function paintGlyph(ctx, kind, w, h, color) {
        ctx.reset();
        var s = Math.min(w, h) * 0.22;
        var cx = w / 2;
        var cy = h / 2;
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

    function beginSearch() {
        showingEpisodes = false;
        searchActive = true;
        searchInput.forceActiveFocus();
    }

    function endSearch() {
        searchActive = false;
        searchQuery = "";
        searchInput.text = "";
        currentIndex = 0;
        showingEpisodes = false;
        searchCleared();
    }

    function submitSearch() {
        var q = searchInput.text.trim();
        if (q.length < 2) return;
        searchQuery = q;
        currentIndex = 0;
        showingEpisodes = false;
        searchSubmitted(q);
    }

    function nextResult() {
        if (searchItems.length > 0) currentIndex = (currentIndex + 1) % searchItems.length;
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

    // Frosted card (translucent white over the wallpaper; no blur or gradient)
    Rectangle {
        id: glass
        anchors.fill: parent
        visible: !face.idle
        radius: face.cornerR
        color: Qt.rgba(1, 1, 1, 0.34)
        border.width: 1
        border.color: face.cEdge
    }

    // ── Search pill (the only thing visible while idle) ──
    Rectangle {
        id: pill
        x: face.pad
        y: face.pillY
        width: face.idle ? face.width - face.pad * 2 : face.width - face.pad * 3 - face.pillH
        height: face.pillH
        radius: face.pillH / 2
        visible: !face.showingEpisodes
        color: face.idle ? Qt.rgba(1, 1, 1, 0.5) : face.cGlassStrong
        border.width: 1
        border.color: face.cEdge

        Canvas {
            id: searchIcon
            x: 0
            y: 0
            width: face.pillH
            height: face.pillH
            onPaint: face.paintGlyph(getContext("2d"), "search", width, height, face.cInk)
            Component.onCompleted: requestPaint()
        }

        TextInput {
            id: searchInput
            x: face.pillH
            y: 0
            width: pill.width - face.pillH - face.pad * 0.5
            height: pill.height
            verticalAlignment: TextInput.AlignVCenter
            font.pixelSize: face.fontSm + 2
            color: face.cInk
            selectByMouse: true
            clip: true
            onAccepted: face.submitSearch()
            Keys.onEscapePressed: face.endSearch()
            onActiveFocusChanged: {
                if (activeFocus) {
                    if (!face.searchActive) face.beginSearch();
                } else if (text.trim() === "" && !face.showingResults) {
                    face.searchActive = false;
                }
            }
        }

        Text {
            x: face.pillH
            width: pill.width - face.pillH
            height: pill.height
            verticalAlignment: Text.AlignVCenter
            visible: searchInput.text === ""
            text: "Tìm phim…"
            color: Qt.rgba(0.086, 0.125, 0.227, 0.5)
            font.pixelSize: face.fontSm + 2
        }

        // Left icon: drag handle for the card, and starts the search when idle
        MouseArea {
            id: handle
            x: 0
            y: 0
            width: face.pillH
            height: face.pillH
            cursorShape: Qt.OpenHandCursor
            drag.target: face.dragTarget
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 12
            drag.maximumX: face.dragTarget ? Math.max(12, face.dragTarget.parent.width - face.dragTarget.width - 12) : 12
            drag.minimumY: 52
            drag.maximumY: face.dragTarget ? Math.max(52, face.dragTarget.parent.height - face.dragTarget.height - 12) : 52
            onClicked: if (face.idle) face.beginSearch()
            onReleased: face.dragReleased()
        }
    }

    // Close (cross): leaves search and returns to idle
    Rectangle {
        id: closeBtn
        x: face.width - face.pad - face.pillH
        y: face.pillY
        width: face.pillH
        height: face.pillH
        radius: face.pillH / 2
        visible: !face.idle
        color: closeArea.pressed ? face.cGlassStrong : Qt.rgba(1, 1, 1, 0.5)
        border.width: 1
        border.color: face.cEdge

        Canvas {
            anchors.fill: parent
            onPaint: face.paintGlyph(getContext("2d"), "close", width, height, face.cInk)
            Component.onCompleted: requestPaint()
        }

        MouseArea {
            id: closeArea
            anchors.fill: parent
            onClicked: face.endSearch()
        }
    }

    // Episode mode header: back arrow and the film name replace the pill
    Rectangle {
        id: backBtn
        x: face.pad
        y: face.pillY
        width: face.pillH
        height: face.pillH
        radius: face.pillH / 2
        visible: face.showingEpisodes
        color: backArea.pressed ? face.cGlassStrong : Qt.rgba(1, 1, 1, 0.5)
        border.width: 1
        border.color: face.cEdge

        Canvas {
            anchors.fill: parent
            onPaint: face.paintGlyph(getContext("2d"), "back", width, height, face.cInk)
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
        x: face.pad * 2 + face.pillH
        y: face.pillY
        width: face.width - face.pad * 4 - face.pillH * 2
        height: face.pillH
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: face.episodeFilm ? face.episodeFilm.name : ""
        color: face.cInk
        font.pixelSize: face.fontLg
        font.bold: true
    }

    // ── Results: current film as a poster hero ──
    Item {
        id: hero
        visible: face.showingResults && !face.showingEpisodes && face.current !== null
        x: face.pad
        y: face.bodyY
        width: face.width - face.pad * 2
        height: face.heroH
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
            anchors.fill: parent
            onPaint: face.paintCover(getContext("2d"), heroCanvas, heroPic, hero.picSrc, width, height, face.cornerR * 0.75)
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

        // Glass plate over the poster carrying the title and the "Xem" button
        Rectangle {
            id: plate
            x: Math.round(8 * face.u)
            width: hero.width - Math.round(16 * face.u)
            height: Math.min(hero.height * 0.5, Math.round(86 * face.u))
            y: hero.height - height - Math.round(8 * face.u)
            radius: Math.round(16 * face.u)
            color: Qt.rgba(1, 1, 1, 0.3)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.6)

            Column {
                x: Math.round(12 * face.u)
                anchors.verticalCenter: parent.verticalCenter
                width: plate.width - xemBtn.width - Math.round(36 * face.u)
                spacing: Math.round(2 * face.u)

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: face.current ? (face.current.info || "") : ""
                    color: Qt.rgba(1, 1, 1, 0.85)
                    font.pixelSize: face.fontSm
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: face.current ? face.current.name : ""
                    color: face.cWhite
                    font.pixelSize: face.fontLg
                    font.bold: true
                }
            }

            Rectangle {
                id: xemBtn
                anchors.right: parent.right
                anchors.rightMargin: Math.round(12 * face.u)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(84 * face.u)
                height: Math.round(32 * face.u)
                radius: height / 2
                color: xemArea.pressed ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(1, 1, 1, 0.3)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.75)

                Text {
                    anchors.centerIn: parent
                    text: "Xem"
                    color: face.cWhite
                    font.pixelSize: face.fontSm + 1
                    font.bold: true
                }

                MouseArea {
                    id: xemArea
                    anchors.fill: parent
                    onClicked: face.openEpisodes()
                }
            }
        }
    }

    // Results footer: position and the down arrow that moves to the next film
    Item {
        id: footer
        visible: face.showingResults && !face.showingEpisodes && face.current !== null
        x: face.pad
        y: face.footY
        width: face.width - face.pad * 2
        height: face.footH

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - nextBtn.width - face.pad
            spacing: Math.round(2 * face.u)

            Text {
                text: "Kết quả " + (face.currentIndex + 1) + " / " + face.searchItems.length
                color: face.cInk
                font.pixelSize: face.fontSm
                font.bold: true
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: "“" + face.searchQuery + "”"
                color: Qt.rgba(0.086, 0.125, 0.227, 0.7)
                font.pixelSize: face.fontSm
            }
        }

        Rectangle {
            id: nextBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: footer.height
            height: footer.height
            radius: height / 2
            color: nextArea.pressed ? Qt.rgba(1, 1, 1, 0.7) : face.cGlassStrong
            border.width: 1
            border.color: face.cEdge

            Canvas {
                anchors.fill: parent
                onPaint: face.paintGlyph(getContext("2d"), "down", width, height, face.cInk)
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
            }

            MouseArea {
                id: nextArea
                anchors.fill: parent
                onClicked: face.nextResult()
            }
        }
    }

    // Search states without a film to show
    Text {
        visible: face.showingResults && !face.showingEpisodes && face.searchItems.length === 0
        x: face.pad
        y: face.bodyY
        width: face.width - face.pad * 2
        height: face.heroH
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        text: face.searchLoading ? "Đang tìm “" + face.searchQuery + "”…"
                                 : "Không có kết quả cho “" + face.searchQuery + "”"
        color: face.cInk
        font.pixelSize: face.fontMd
    }

    // ── Episodes of the chosen film: one row per episode; a tap plays it ──
    ListView {
        id: episodeList
        visible: face.showingEpisodes && face.episodes.length > 0
        x: face.pad
        y: face.bodyY
        width: face.width - face.pad * 2
        height: face.height - face.bodyY - face.pad
        clip: true
        spacing: Math.round(6 * face.u)
        boundsBehavior: Flickable.StopAtBounds
        model: face.episodes

        delegate: Rectangle {
            id: epRow
            required property var modelData
            width: episodeList.width
            height: Math.max(34, Math.round(42 * face.u))
            radius: height / 2
            color: epArea.pressed ? face.cGlassStrong : Qt.rgba(1, 1, 1, 0.42)
            border.width: 1
            border.color: face.cEdge

            Text {
                x: Math.round(16 * face.u)
                anchors.verticalCenter: parent.verticalCenter
                width: epRow.width - Math.round(32 * face.u)
                elide: Text.ElideRight
                text: epRow.modelData.name
                color: face.cInk
                font.pixelSize: face.fontMd
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
        y: face.bodyY
        width: face.width - face.pad * 2
        height: face.heroH
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        text: face.episodesLoading ? "Đang tải danh sách tập…" : "Phim này chưa có tập phát."
        color: face.cInk
        font.pixelSize: face.fontMd
    }
}
