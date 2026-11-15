// FrameLauncher: the app launcher of the frame layout (Win+A). The middle of
// the bottom frame edge swells up into a drawer: a list of applications on a
// FrameBump in the frame color, with a live search field sitting in the edge
// itself, where the bar shows its input pill. Fills the window that hosts it;
// a click anywhere outside the drawer closes it.
// Pure QtQuick: the host passes in the desktop entries and resolves icons, so
// this file needs no Quickshell import.
// File-based component (not inline): immune to QML inline-component ordering quirks ("X is not a type").
import QtQuick

Item {
    id: root

    // Shell theme (Colors.qml). Left null, the stand-alone light defaults apply.
    property var themePalette: null
    // true: the drawer rises and takes typing; false: it sinks back into the edge
    property bool open: false
    // DesktopEntry-like objects: name, genericName, comment, keywords, id
    property var entries: []
    // function (entry) returning an icon URL, or "" when the theme has none
    property var iconSource: null
    // One pixel of a 1080px-high screen. Deliberately not the frame scale: a
    // thin frame still gets a launcher that can be read.
    property real unit: 1.0
    // Thickness of the bottom frame edge the drawer stands on
    property int edgeHeight: 57
    // Width of the side frame edges; the drawer keeps clear of them
    property int sideInset: 0
    property int maxRows: 6
    property string placeholder: "Tìm ứng dụng…"
    property string actionText: "Mở"
    property string emptyText: "Không tìm thấy ứng dụng"

    signal launchRequested(var entry)
    signal closeRequested()

    readonly property color cBg: themePalette ? themePalette.frameBg : "#f2f2f2"
    readonly property color cPill: themePalette ? themePalette.framePill : "#ffffff"
    readonly property color cInk: themePalette ? themePalette.frameInk : "#1f1f1f"
    readonly property color cSoft: themePalette ? themePalette.frameInkSoft : "#9a9a9a"
    readonly property color cAccentA: themePalette ? themePalette.frameAccentA : "#9acee3"
    readonly property color cAccentB: themePalette ? themePalette.frameAccentB : "#b3d9d6"
    readonly property color cAccentInk: themePalette ? themePalette.frameAccentInk : "#ffffff"
    readonly property string cFont: themePalette ? themePalette.frameFont : "Cantarell"
    readonly property string cGlyphFont: themePalette ? themePalette.frameGlyphFont : "JetBrainsMono Nerd Font"

    // ── Geometry ──
    function px(n) {
        return Math.round(n * root.unit);
    }

    readonly property int cardW: Math.max(px(240), Math.min(px(520), width - 2 * sideInset - px(96)))
    readonly property int rowH: px(52)
    readonly property int iconS: px(32)
    readonly property int fieldH: px(44)
    readonly property int pad: px(12)
    readonly property int gap: px(8)
    readonly property int shoulder: px(16)
    readonly property int fontPx: Math.max(11, px(15))
    readonly property int subFontPx: Math.max(10, px(12))
    // The field sits in the middle of the edge when the edge is thick enough
    // to hold it, and stands on the screen bottom with a small margin otherwise.
    readonly property int fieldBottom: Math.max(px(8), Math.round((edgeHeight - fieldH) / 2))
    readonly property int visibleRows: Math.max(1, Math.min(maxRows, results.length))
    property real listH: visibleRows * rowH
    readonly property real fullH: pad + listH + gap + fieldH + fieldBottom
    // 0: flush with the edge, 1: fully risen
    property real openness: open ? 1.0 : 0.0
    readonly property real cardH: edgeHeight + Math.max(0, fullH - edgeHeight) * openness
    readonly property real cardX: Math.round((width - cardW) / 2)
    readonly property real cardTop: height - cardH
    readonly property real fieldTop: height - fieldBottom - fieldH

    Behavior on openness {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    Behavior on listH {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }

    // ── Search ──
    property string query: ""
    property var searchIndex: []
    property var results: []

    // Lower-case, without diacritics: "tim" finds "Tìm", "dien" finds "Điện"
    function fold(s) {
        var t = String(s === undefined || s === null ? "" : s).toLowerCase();
        try {
            t = t.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
        } catch (e) {
            // No Unicode normalization in this engine: match accents literally
        }
        return t.replace(/đ/g, "d");
    }

    function joinList(list) {
        var out = [];
        var n = (list && list.length) ? list.length : 0;
        for (var i = 0; i < n; i++) out.push(String(list[i]));
        return out.join(" ");
    }

    function rebuildIndex() {
        var out = [];
        var n = (entries && entries.length) ? entries.length : 0;
        for (var i = 0; i < n; i++) {
            var e = entries[i];
            if (!e || !e.name) continue;
            out.push({
                entry: e,
                name: fold(e.name),
                generic: fold(e.genericName),
                comment: fold(e.comment),
                keywords: fold(joinList(e.keywords)),
                id: fold(e.id)
            });
        }
        out.sort(function (a, b) {
            return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0);
        });
        searchIndex = out;
        refresh();
    }

    // Higher is better, 0 is no match. A hit at the start of the name wins,
    // then one at the start of a later word, then initials ("vsc" for Visual
    // Studio Code), then anywhere in the name, then the other fields, and
    // last the letters in order with gaps.
    function score(item, q) {
        var name = item.name;
        var at = name.indexOf(q);
        if (at === 0) return 100 - Math.min(20, name.length - q.length) * 0.5;
        if (at > 0 && " -_./(".indexOf(name.charAt(at - 1)) >= 0) return 80 - Math.min(20, at) * 0.5;
        var initials = "";
        var words = name.split(/[\s\-_.\/]+/);
        for (var w = 0; w < words.length; w++) initials += words[w].charAt(0);
        if (q.length > 1 && initials.indexOf(q) === 0) return 70;
        if (at > 0) return 60 - Math.min(20, at) * 0.5;
        if (item.generic.indexOf(q) >= 0) return 45;
        if (item.keywords.indexOf(q) >= 0) return 40;
        if (item.id.indexOf(q) >= 0) return 35;
        if (item.comment.indexOf(q) >= 0) return 25;
        if (q.length < 2) return 0;
        var pos = -1;
        var spread = 0;
        for (var i = 0; i < q.length; i++) {
            var next = name.indexOf(q.charAt(i), pos + 1);
            if (next < 0) return 0;
            if (pos >= 0) spread += next - pos - 1;
            pos = next;
        }
        // Letters scattered across a long name are noise, not a match
        if (spread > q.length) return 0;
        return 20 - spread;
    }

    function refresh() {
        var q = fold(query).trim();
        var out = [];
        var i;
        if (q === "") {
            for (i = 0; i < searchIndex.length; i++) out.push(searchIndex[i].entry);
        } else {
            var hits = [];
            for (i = 0; i < searchIndex.length; i++) {
                var s = score(searchIndex[i], q);
                if (s > 0) hits.push({ s: s, n: searchIndex[i].name, e: searchIndex[i].entry });
            }
            hits.sort(function (a, b) {
                return b.s !== a.s ? b.s - a.s : (a.n < b.n ? -1 : (a.n > b.n ? 1 : 0));
            });
            for (i = 0; i < hits.length; i++) out.push(hits[i].e);
        }
        results = out;
        list.currentIndex = out.length > 0 ? 0 : -1;
        list.positionViewAtBeginning();
    }

    function move(delta) {
        if (results.length === 0) return;
        var i = Math.max(0, Math.min(results.length - 1, list.currentIndex + delta));
        list.currentIndex = i;
        list.positionViewAtIndex(i, ListView.Contain);
    }

    function launchCurrent() {
        if (list.currentIndex < 0 || list.currentIndex >= results.length) return;
        launchRequested(results[list.currentIndex]);
    }

    function focusInput() {
        input.forceActiveFocus();
    }

    onEntriesChanged: rebuildIndex()
    onQueryChanged: refresh()
    Component.onCompleted: rebuildIndex()

    // Every opening starts from an empty field with the first app selected
    onOpenChanged: {
        if (open) {
            input.text = "";
            refresh();
            focusInput();
        }
    }

    // ── Outside the drawer: one click closes ──
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: root.closeRequested()
    }

    // ── Drawer body: a bump above the edge line, a plain strip inside the edge ──
    FrameBump {
        id: bump
        pointsDown: false
        x: root.cardX - root.shoulder
        y: Math.round(root.cardTop)
        width: root.cardW + 2 * root.shoulder
        height: Math.max(0, root.height - root.edgeHeight - y)
        shoulder: root.shoulder
        bodyRadius: root.px(24)
        // Opaque even when the frame is translucent: the drawer lies over the
        // bar's title tab and input pill, and they must not show through
        fillColor: root.cBg
        fillAlpha: 1.0
    }

    Rectangle {
        id: edgeStrip
        x: root.cardX
        y: root.height - root.edgeHeight
        width: root.cardW
        height: root.edgeHeight
        color: root.cBg
        // Covers the bar's own input pill, so it fades in rather than blinking
        opacity: Math.min(1, root.openness * 4)
    }

    // Swallows clicks on the drawer so they do not count as "outside"
    MouseArea {
        x: root.cardX
        y: root.cardTop
        width: root.cardW
        height: root.cardH
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: input.forceActiveFocus()
    }

    // ── Results: ride up with the top of the drawer, cut off above the field ──
    Item {
        id: listClip
        x: root.cardX + root.pad
        y: root.cardTop + root.pad
        width: root.cardW - 2 * root.pad
        height: Math.max(0, Math.min(root.listH, root.fieldTop - root.gap - y))
        clip: true
        opacity: Math.min(1, root.openness * 2)

        ListView {
            id: list
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: root.listH
            model: root.results
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            highlightFollowsCurrentItem: false
            cacheBuffer: root.rowH * 4

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool current: ListView.isCurrentItem
                readonly property string sub: {
                    var c = modelData ? String(modelData.comment || "") : "";
                    return c !== "" ? c : (modelData ? String(modelData.genericName || "") : "");
                }
                width: ListView.view ? ListView.view.width : 0
                height: root.rowH

                Rectangle {
                    anchors {
                        fill: parent
                        topMargin: root.px(2)
                        bottomMargin: root.px(2)
                    }
                    radius: root.px(14)
                    color: root.cPill
                    opacity: row.current ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation { duration: 90 }
                    }
                }

                Image {
                    id: rowIcon
                    anchors {
                        left: parent.left
                        leftMargin: root.px(10)
                        verticalCenter: parent.verticalCenter
                    }
                    width: root.iconS
                    height: root.iconS
                    sourceSize.width: root.iconS
                    sourceSize.height: root.iconS
                    asynchronous: true
                    smooth: true
                    source: (root.iconSource && row.modelData) ? root.iconSource(row.modelData) : ""
                }

                // No themed icon: a neutral app glyph keeps the column aligned
                Text {
                    anchors.centerIn: rowIcon
                    visible: rowIcon.status !== Image.Ready
                    text: "󰣆"
                    color: root.cSoft
                    font.family: root.cGlyphFont
                    font.pixelSize: Math.round(root.iconS * 0.8)
                }

                Column {
                    anchors {
                        left: rowIcon.right
                        leftMargin: root.px(12)
                        right: parent.right
                        rightMargin: root.px(12)
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: root.px(1)

                    Text {
                        width: parent.width
                        text: row.modelData ? String(row.modelData.name || "") : ""
                        color: root.cInk
                        font.family: root.cFont
                        font.pixelSize: root.fontPx
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: row.sub !== ""
                        text: row.sub
                        color: root.cSoft
                        font.family: root.cFont
                        font.pixelSize: root.subFontPx
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Only a moving pointer selects, so a row scrolling under a
                    // resting pointer does not steal the keyboard selection
                    onPositionChanged: list.currentIndex = row.index
                    onClicked: {
                        list.currentIndex = row.index;
                        root.launchCurrent();
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.results.length === 0
            text: root.emptyText
            color: root.cSoft
            font.family: root.cFont
            font.pixelSize: root.fontPx
        }
    }

    // ── Search field: white pill, glyph, live text, teal action pill ──
    Rectangle {
        id: field
        x: root.cardX + root.pad
        y: root.fieldTop
        width: root.cardW - 2 * root.pad
        height: root.fieldH
        radius: height / 2
        color: root.cPill
        opacity: Math.min(1, root.openness * 4)

        Text {
            id: fieldGlyph
            anchors {
                left: parent.left
                leftMargin: root.px(15)
                verticalCenter: parent.verticalCenter
            }
            text: "󰍉"
            color: root.cSoft
            font.family: root.cGlyphFont
            font.pixelSize: root.fontPx + root.px(3)
        }

        TextInput {
            id: input
            anchors {
                left: fieldGlyph.right
                leftMargin: root.px(9)
                right: fieldAction.left
                rightMargin: root.px(8)
                top: parent.top
                bottom: parent.bottom
            }
            verticalAlignment: TextInput.AlignVCenter
            color: root.cInk
            selectionColor: root.cAccentA
            selectedTextColor: root.cInk
            font.family: root.cFont
            font.pixelSize: root.fontPx
            selectByMouse: true
            clip: true
            onTextChanged: root.query = text
            onAccepted: root.launchCurrent()

            Keys.onPressed: event => {
                var ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                if (event.key === Qt.Key_Escape) {
                    root.closeRequested();
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab
                        || (ctrl && (event.key === Qt.Key_N || event.key === Qt.Key_J))) {
                    root.move(1);
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab
                        || (ctrl && (event.key === Qt.Key_P || event.key === Qt.Key_K))) {
                    root.move(-1);
                } else if (event.key === Qt.Key_PageDown) {
                    root.move(root.maxRows);
                } else if (event.key === Qt.Key_PageUp) {
                    root.move(-root.maxRows);
                } else {
                    return;
                }
                event.accepted = true;
            }
        }

        Text {
            anchors {
                left: input.left
                right: input.right
                verticalCenter: parent.verticalCenter
            }
            visible: input.text === ""
            text: root.placeholder
            color: root.cSoft
            font.family: root.cFont
            font.pixelSize: root.fontPx
            elide: Text.ElideRight
        }

        Rectangle {
            id: fieldAction
            anchors {
                right: parent.right
                rightMargin: root.px(5)
                verticalCenter: parent.verticalCenter
            }
            width: fieldActionRow.width + 2 * root.px(13)
            height: parent.height - 2 * root.px(5)
            radius: height / 2
            opacity: fieldActionMouse.containsMouse ? 0.86 : 1.0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.cAccentA }
                GradientStop { position: 1.0; color: root.cAccentB }
            }

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }

            Row {
                id: fieldActionRow
                anchors.centerIn: parent
                spacing: root.px(5)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰌑"
                    color: root.cAccentInk
                    font.family: root.cGlyphFont
                    font.pixelSize: root.fontPx
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.actionText
                    color: root.cAccentInk
                    font.family: root.cFont
                    font.pixelSize: root.subFontPx + 1
                    font.weight: Font.DemiBold
                }
            }

            MouseArea {
                id: fieldActionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.launchCurrent()
            }
        }
    }
}
