// AniSub wallpaper widget face (Movie + Comic). Poster-first card.
// The parent sets width and height independently (free resize). Layout:
//   top bar    : header text, or the search box while searching; magnifier / cross button
//   feed       : poster hero, title, info line; footer = previous / open / next
//   search     : every result as a scrollable row (poster, name, info); footer = result count
// Search runs on the widget itself: the magnifier opens the box, Enter emits
// searchSubmitted(query) and the parent feeds results back through searchItems and
// searchLoading. Escape or the cross emits searchCleared() and returns to the feed.
// File-based component so it resolves inside Variants / PanelWindow templates.
// Colors come in as themePalette (theme.xxx). GPL-3.0-or-later; see CREDITS.md.
import QtQuick

Item {
    id: face

    property var themePalette: null
    property string headerText: ""
    property string placeholderText: "Đang tải…"
    property string searchHint: "Tìm…"
    property var items: []
    property var searchItems: []
    property bool searchLoading: false
    property bool searchActive: false
    property string searchQuery: ""
    property int currentIndex: 0
    property var chapters: []
    property bool chaptersLoading: false
    property var chapterStory: null
    property bool showingChapters: false

    signal storyPicked(var story)
    signal chapterPicked(var chapter)
    signal searchSubmitted(string query)
    signal searchCleared()

    // Sizes scale with the card; the smaller ratio keeps text and buttons inside the card
    readonly property real u: Math.max(0.6, Math.min(width / 280, height / 340))
    readonly property real pad: Math.round(10 * u)
    readonly property real topH: Math.max(26, Math.round(34 * u))
    readonly property real footH: Math.max(32, Math.round(42 * u))
    readonly property real topY: pad
    readonly property real footY: height - pad - footH
    readonly property real cY: topY + topH + pad
    readonly property real cH: Math.max(40, footY - pad - cY)
    readonly property real cornerR: Math.round(24 * u)
    readonly property real fontSm: Math.max(8, Math.round(11 * u))
    readonly property real fontMd: Math.max(10, Math.round(14 * u))
    readonly property real fontLg: Math.max(11, Math.round(18 * u))
    readonly property real titleH: Math.round(fontLg * 1.35)
    readonly property real infoH: Math.round(fontSm * 1.6)
    readonly property real heroH: Math.max(30, cH - titleH - infoH - pad * 0.5)

    readonly property color cBlue: themePalette ? themePalette.mainFg : "#2434e0"
    readonly property color cWhite: themePalette ? themePalette.surfaceBg : "#ffffff"
    readonly property color cPale: themePalette ? themePalette.accentSecondary : "#c9d2f7"
    readonly property color cBorder: themePalette ? themePalette.borderColor : "#2233dd"
    readonly property color cButton: Qt.lighter(cBlue, 1.25)
    readonly property color cPress: Qt.lighter(cBlue, 1.5)

    readonly property bool showingResults: searchActive && searchQuery !== ""
    // The feed (hero + transport) shows only when neither results nor chapters are on screen
    readonly property bool showingFeed: !showingResults && !showingChapters
    readonly property var shownItems: showingResults ? searchItems : items
    readonly property var current: shownItems.length > 0
        ? shownItems[Math.min(currentIndex, shownItems.length - 1)] : null

    onShownItemsChanged: currentIndex = Math.max(0, Math.min(currentIndex, shownItems.length - 1))

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

    // Cover-fit poster, rounded corners. Falls back to a flat tint until the image is ready.
    // The Canvas loads the URL itself (loadImage); the hidden Image item only supplies the natural size.
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
            ctx.fillStyle = rgbaStr(face.cPale, 0.35);
            ctx.fillRect(0, 0, w, h);
        }
        ctx.restore();
    }

    // Simple vector glyphs so the card needs no icon files
    function paintGlyph(ctx, kind, w, h, color) {
        ctx.reset();
        var s = Math.min(w, h) * 0.22;
        var cx = w / 2;
        var cy = h / 2;
        ctx.fillStyle = color;
        ctx.strokeStyle = color;
        ctx.lineCap = "round";
        ctx.lineWidth = Math.max(1.5, s * 0.45);
        ctx.beginPath();
        if (kind === "search") {
            ctx.arc(cx - 0.3 * s, cy - 0.3 * s, 1.2 * s, 0, 2 * Math.PI);
            ctx.moveTo(cx + 0.7 * s, cy + 0.7 * s);
            ctx.lineTo(cx + 1.6 * s, cy + 1.6 * s);
            ctx.stroke();
        } else if (kind === "close") {
            ctx.moveTo(cx - s, cy - s);
            ctx.lineTo(cx + s, cy + s);
            ctx.moveTo(cx + s, cy - s);
            ctx.lineTo(cx - s, cy + s);
            ctx.stroke();
        } else if (kind === "play") {
            ctx.moveTo(cx - 0.7 * s, cy - 1.1 * s);
            ctx.lineTo(cx + 1.0 * s, cy);
            ctx.lineTo(cx - 0.7 * s, cy + 1.1 * s);
            ctx.closePath();
            ctx.fill();
        } else if (kind === "prev") {
            ctx.moveTo(cx - 0.8 * s, cy);
            ctx.lineTo(cx + 0.9 * s, cy - s);
            ctx.lineTo(cx + 0.9 * s, cy + s);
            ctx.closePath();
            ctx.fill();
            ctx.fillRect(cx - 1.25 * s, cy - s, 0.3 * s, 2 * s);
        } else if (kind === "next") {
            ctx.moveTo(cx + 0.8 * s, cy);
            ctx.lineTo(cx - 0.9 * s, cy - s);
            ctx.lineTo(cx - 0.9 * s, cy + s);
            ctx.closePath();
            ctx.fill();
            ctx.fillRect(cx + 0.95 * s, cy - s, 0.3 * s, 2 * s);
        }
    }

    // A story was picked: its chapter list replaces the feed and search
    function openStory(story) {
        if (!story) return;
        searchActive = false;
        chapterStory = story;
        showingChapters = true;
        storyPicked(story);
    }

    function closeChapters() {
        showingChapters = false;
        chapterStory = null;
    }

    function beginSearch() {
        showingChapters = false;
        searchActive = true;
        searchInput.forceActiveFocus();
    }

    function endSearch() {
        searchActive = false;
        searchQuery = "";
        searchInput.text = "";
        currentIndex = 0;
        searchCleared();
    }

    function submitSearch() {
        var q = searchInput.text.trim();
        if (q.length < 2) return;
        searchQuery = q;
        currentIndex = 0;
        searchSubmitted(q);
    }

    // Card body
    Rectangle {
        id: body
        anchors.fill: parent
        radius: face.cornerR
        color: face.cBlue
    }

    // ── Top bar ──
    Text {
        id: header
        x: face.pad * 1.5
        y: face.topY
        width: face.width - face.pad * 3 - face.topH
        height: face.topH
        visible: !face.searchActive && !face.showingChapters
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: face.headerText
        color: face.cPale
        font.pixelSize: face.fontSm
    }

    // Chapter mode header: back arrow and the story name
    Rectangle {
        id: chapterBack
        x: face.pad
        y: face.topY
        width: face.topH
        height: face.topH
        radius: face.topH / 2
        visible: face.showingChapters
        color: chapterBackArea.pressed ? face.cPress : face.cButton

        Canvas {
            anchors.fill: parent
            onPaint: face.paintGlyph(getContext("2d"), "prev", width, height, face.rgbaStr(face.cWhite, 1))
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
        }

        MouseArea {
            id: chapterBackArea
            anchors.fill: parent
            onClicked: face.closeChapters()
        }
    }

    Text {
        x: face.pad * 2 + face.topH
        y: face.topY
        width: face.width - face.pad * 4 - face.topH * 2
        height: face.topH
        visible: face.showingChapters
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: face.chapterStory ? face.chapterStory.name : ""
        color: face.cWhite
        font.pixelSize: face.fontSm + 1
        font.bold: true
    }

    Rectangle {
        id: searchField
        x: face.pad
        y: face.topY
        width: face.width - face.pad * 2 - face.topH - face.pad * 0.5
        height: face.topH
        radius: face.topH / 2
        visible: face.searchActive
        color: face.cWhite
        border.width: 1
        border.color: face.cBorder

        TextInput {
            id: searchInput
            anchors.fill: parent
            anchors.leftMargin: face.pad
            anchors.rightMargin: face.pad
            verticalAlignment: TextInput.AlignVCenter
            font.pixelSize: face.fontSm + 1
            color: face.cBlue
            selectByMouse: true
            clip: true
            onAccepted: face.submitSearch()
            Keys.onEscapePressed: face.endSearch()
        }

        Text {
            anchors.fill: parent
            anchors.leftMargin: face.pad
            verticalAlignment: Text.AlignVCenter
            visible: searchInput.text === ""
            text: face.searchHint
            color: Qt.rgba(face.cBlue.r, face.cBlue.g, face.cBlue.b, 0.5)
            font.pixelSize: face.fontSm + 1
        }
    }

    Rectangle {
        id: searchButton
        visible: !face.showingChapters
        x: face.width - face.pad - face.topH
        y: face.topY
        width: face.topH
        height: face.topH
        radius: face.topH / 2
        color: searchArea.pressed ? face.cPress : face.cButton

        Canvas {
            id: searchIcon
            anchors.fill: parent
            onPaint: face.paintGlyph(getContext("2d"), face.searchActive ? "close" : "search",
                                     width, height, face.rgbaStr(face.cWhite, 1))
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
            Connections {
                target: face
                function onSearchActiveChanged() { searchIcon.requestPaint(); }
            }
        }

        MouseArea {
            id: searchArea
            anchors.fill: parent
            onClicked: face.searchActive ? face.endSearch() : face.beginSearch()
        }
    }

    // ── Feed: poster hero, title, info ──
    Rectangle {
        id: hero
        visible: face.showingFeed
        x: face.pad
        y: face.cY
        width: face.width - face.pad * 2
        height: face.heroH
        radius: face.cornerR * 0.7
        color: Qt.rgba(1, 1, 1, 0.12)

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
            onPaint: face.paintCover(getContext("2d"), heroCanvas, heroPic, hero.picSrc, width, height, hero.radius)
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

        MouseArea {
            anchors.fill: parent
            enabled: face.current !== null
            cursorShape: Qt.PointingHandCursor
            onClicked: face.openStory(face.current)
        }
    }

    Text {
        id: title
        visible: face.showingFeed
        x: face.pad
        y: face.cY + face.heroH + face.pad * 0.5
        width: face.width - face.pad * 2
        height: face.titleH
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: face.current ? face.current.name : face.placeholderText
        color: face.cWhite
        font.pixelSize: face.fontLg
        font.bold: true
    }

    Text {
        id: info
        visible: face.showingFeed
        x: face.pad
        y: title.y + title.height
        width: face.width - face.pad * 2
        height: face.infoH
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: face.current ? (face.current.info || "") : ""
        color: face.cPale
        font.pixelSize: face.fontSm
    }

    // ── Search: every result, scrollable ──
    ListView {
        id: results
        visible: face.showingResults && face.searchItems.length > 0
        x: face.pad
        y: face.cY
        width: face.width - face.pad * 2
        height: face.cH
        clip: true
        spacing: Math.round(4 * face.u)
        boundsBehavior: Flickable.StopAtBounds
        model: face.searchItems

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            width: results.width
            height: Math.max(36, Math.round(44 * face.u))
            radius: Math.round(12 * face.u)
            color: rowArea.pressed ? face.cPress : face.cButton

            readonly property real side: height - Math.round(8 * face.u)
            readonly property string picSrc: row.modelData.thumb ? String(row.modelData.thumb) : ""

            Image {
                id: rowPic
                visible: false
                asynchronous: true
                cache: true
                source: row.picSrc
                fillMode: Image.PreserveAspectCrop
            }

            Canvas {
                id: rowCanvas
                x: Math.round(4 * face.u)
                y: Math.round(4 * face.u)
                width: row.side
                height: row.side
                onPaint: face.paintCover(getContext("2d"), rowCanvas, rowPic, row.picSrc, width, height, Math.round(9 * face.u))
                onImageLoaded: requestPaint()
                Component.onCompleted: if (row.picSrc !== "") loadImage(row.picSrc)
                Connections {
                    target: row
                    function onPicSrcChanged() {
                        if (row.picSrc !== "") rowCanvas.loadImage(row.picSrc);
                        rowCanvas.requestPaint();
                    }
                }
                Connections {
                    target: rowPic
                    function onStatusChanged() { rowCanvas.requestPaint(); }
                }
            }

            Column {
                x: row.side + Math.round(12 * face.u)
                anchors.verticalCenter: parent.verticalCenter
                width: row.width - x - Math.round(8 * face.u)
                spacing: Math.round(2 * face.u)

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.modelData.name
                    color: face.cWhite
                    font.pixelSize: face.fontMd
                    font.bold: true
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.modelData.info || ""
                    color: face.cPale
                    font.pixelSize: face.fontSm
                }
            }

            MouseArea {
                id: rowArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: face.openStory(row.modelData)
            }
        }
    }

    // Empty / loading message in search mode
    Text {
        visible: face.showingResults && face.searchItems.length === 0
        x: face.pad
        y: face.cY
        width: face.width - face.pad * 2
        height: face.cH
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        text: face.searchLoading ? "Đang tìm “" + face.searchQuery + "”…"
                                 : "Không có kết quả cho “" + face.searchQuery + "”"
        color: face.cPale
        font.pixelSize: face.fontMd
    }

    // ── Footer ──
    Rectangle {
        id: prevBtn
        visible: face.showingFeed
        x: face.pad
        y: face.footY
        width: Math.round((face.width - face.pad * 2 - Math.round(12 * face.u)) * 0.3)
        height: face.footH
        radius: face.footH / 2.5
        color: prevArea.pressed ? face.cPress : face.cButton
        opacity: face.currentIndex > 0 ? 1 : 0.5

        Canvas {
            anchors.fill: parent
            onPaint: face.paintGlyph(getContext("2d"), "prev", width, height, face.rgbaStr(face.cWhite, 1))
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
        visible: face.showingFeed
        x: prevBtn.x + prevBtn.width + Math.round(6 * face.u)
        y: face.footY
        width: face.width - face.pad * 2 - prevBtn.width * 2 - Math.round(12 * face.u)
        height: face.footH
        radius: face.footH / 2.5
        color: playArea.pressed ? face.cPress : face.cButton
        opacity: face.current ? 1 : 0.5

        Row {
            anchors.centerIn: parent
            spacing: Math.round(8 * face.u)

            Canvas {
                width: face.footH * 0.6
                height: face.footH * 0.6
                onPaint: face.paintGlyph(getContext("2d"), "play", width, height, face.rgbaStr(face.cWhite, 1))
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: face.shownItems.length > 0 ? (face.currentIndex + 1) + " / " + face.shownItems.length : ""
                color: face.cWhite
                font.pixelSize: face.fontSm
            }
        }

        MouseArea {
            id: playArea
            anchors.fill: parent
            enabled: face.current !== null
            onClicked: face.openStory(face.current)
        }
    }

    Rectangle {
        id: nextBtn
        visible: face.showingFeed
        x: playBtn.x + playBtn.width + Math.round(6 * face.u)
        y: face.footY
        width: prevBtn.width
        height: face.footH
        radius: face.footH / 2.5
        color: nextArea.pressed ? face.cPress : face.cButton
        opacity: face.currentIndex < face.shownItems.length - 1 ? 1 : 0.5

        Canvas {
            anchors.fill: parent
            onPaint: face.paintGlyph(getContext("2d"), "next", width, height, face.rgbaStr(face.cWhite, 1))
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
        }

        MouseArea {
            id: nextArea
            anchors.fill: parent
            onClicked: face.currentIndex = Math.min(face.shownItems.length - 1, face.currentIndex + 1)
        }
    }

    // ── Chapters of the picked story: a tap opens that chapter in the reader ──
    ListView {
        id: chapterList
        visible: face.showingChapters && face.chapters.length > 0
        x: face.pad
        y: face.cY
        width: face.width - face.pad * 2
        height: face.cH
        clip: true
        spacing: Math.round(4 * face.u)
        boundsBehavior: Flickable.StopAtBounds
        model: face.chapters

        delegate: Rectangle {
            id: chRow
            required property var modelData
            width: chapterList.width
            height: Math.max(36, Math.round(40 * face.u))
            radius: Math.round(12 * face.u)
            color: chArea.pressed ? face.cPress : face.cButton

            Text {
                x: Math.round(14 * face.u)
                anchors.verticalCenter: parent.verticalCenter
                width: chRow.width - Math.round(28 * face.u)
                elide: Text.ElideRight
                text: chRow.modelData.name
                color: face.cWhite
                font.pixelSize: face.fontMd
                font.bold: true
            }

            MouseArea {
                id: chArea
                anchors.fill: parent
                onClicked: face.chapterPicked(chRow.modelData)
            }
        }
    }

    Text {
        visible: face.showingChapters && face.chapters.length === 0
        x: face.pad
        y: face.cY
        width: face.width - face.pad * 2
        height: face.cH
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        text: face.chaptersLoading ? "Đang tải danh sách chương…" : "Truyện này chưa có chương."
        color: face.cPale
        font.pixelSize: face.fontMd
    }

    Text {
        visible: face.showingChapters && face.chapters.length > 0
        x: face.pad
        y: face.footY
        width: face.width - face.pad * 2
        height: face.footH
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: face.chapters.length + " chương · chọn để đọc"
        color: face.cPale
        font.pixelSize: face.fontSm
    }

    // Search footer: count of results instead of the transport
    Text {
        visible: face.showingResults && face.searchItems.length > 0
        x: face.pad
        y: face.footY
        width: face.width - face.pad * 2
        height: face.footH
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: face.searchItems.length + " kết quả cho “" + face.searchQuery + "”"
        color: face.cPale
        font.pixelSize: face.fontSm
    }
}
