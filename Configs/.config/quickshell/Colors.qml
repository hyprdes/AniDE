import QtQuick

QtObject {
    id: colors
    // Wallpaper green palette (image-18.png request): the bar is a translucent
    // sage-green glass with cream ink, deep-green capsule plates and a lime
    // accent. The values are sampled from image-18 (mean tone #6F8F55, card
    // green #5D8839, deep ink #3A5C37, pale pill #C5D1AD, lime #ADBC66).
    property color barBg: "#6f8f55"          // Wallpaper mean tone (bar glass)
    property color mainBg: "#5d8839"         // Card green
    property color surfaceBg: "#3a5c37"      // Deep-green capsule / icon plate
    property color layer2Bg: "#4d6d39"       // Inner layer
    property color mainFg: "#fdfff7"         // Cream ink: text & glyphs
    property color subFg: "#c5d1ad"          // Pale sage secondary text
    property color actBg: "#adbc66"          // Lime active fill
    property color glowColor: "#adbc66"      // Lime accent
    property color glowSecondary: "#8da968"  // Soft green glow (active pills)
    property color accentSecondary: "#86a06a"// Occupied surface track
    property color secondaryFg: "#c5d1ad"    // Pale sage ink-2 text/icons
    property color actFg: "#1e2e1a"          // Dark green ink on lime
    property color hvrBg: "#4d6d39"          // Hover state
    property color hvrFg: "#fdfff7"
    property color borderColor: "#2e4a2b"    // Deep green outline
    property color errorColor: "#b3261e"
    property color errorFg: "#ffffff"
    property real barOpacity: 0.9            // Glass: the wallpaper shows through
    property real pillOpacity: 1.0
    property int cornerRadius: 23
    property int groupRadius: 17             // Stadium BarGroup radius (height 34 / 2)
    property string wallBlurPath: ""

    // Palette source arbitration: "dcol" when wallbash colors drove the last
    // update, "image" when the QML wallpaper sampler did (works without wallbash).
    property string wallSyncSource: "none"

    function rgbHex(r, g, b) {
        function h(v) {
            var s = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16);
            return s.length < 2 ? "0" + s : s;
        }
        return "#" + h(r) + h(g) + h(b);
    }

    function normHex(val) {
        if (!val) return "";
        var s = val.toString().trim();
        if (s === "") return "";
        return s.charAt(0) === "#" ? s : ("#" + s);
    }

    // Derive the whole bar palette from one wallpaper tone (r, g, b in 0..1).
    // The bar takes the wallpaper color itself, so the sync is clearly visible;
    // ink flips to cream on dark tones and to deep green on light tones.
    function syncWallTone(r, g, b) {
        var t = Qt.rgba(Math.max(0, Math.min(1, r)), Math.max(0, Math.min(1, g)), Math.max(0, Math.min(1, b)), 1);
        var lum = 0.2126 * t.r + 0.7152 * t.g + 0.0722 * t.b;
        var light = lum >= 0.6;
        barBg = t;
        mainBg = Qt.darker(t, 1.12);
        surfaceBg = Qt.darker(t, 1.6);
        layer2Bg = Qt.darker(t, 1.3);
        mainFg = light ? "#1e2e1a" : "#fdfff7";
        subFg = light ? "#3a5c37" : "#c5d1ad";
        secondaryFg = subFg;
        actBg = Qt.lighter(t, 1.3);
        actFg = light ? "#fdfff7" : "#1e2e1a";
        glowColor = Qt.lighter(t, 1.35);
        glowSecondary = Qt.lighter(t, 1.15);
        accentSecondary = Qt.lighter(t, 1.2);
        hvrBg = Qt.darker(t, 1.3);
        hvrFg = mainFg;
        borderColor = Qt.darker(t, 1.9);
    }

    // theme.json carries the exact palette (wallbash or the sampler wrote it);
    // its values are used as they are, without any tint.
    function applyJson(raw) {
        if (!raw) return;
        try {
            var data = JSON.parse(raw);
            if (data.barBg) barBg = Qt.color(normHex(data.barBg));
            if (data.mainBg) mainBg = Qt.color(normHex(data.mainBg));
            if (data.surfaceBg) surfaceBg = Qt.color(normHex(data.surfaceBg));
            if (data.layer2Bg) layer2Bg = Qt.color(normHex(data.layer2Bg));
            if (data.mainFg) mainFg = Qt.color(normHex(data.mainFg));
            if (data.subFg) subFg = Qt.color(normHex(data.subFg));
            if (data.actBg) actBg = Qt.color(normHex(data.actBg));
            if (data.actFg) actFg = Qt.color(normHex(data.actFg));
            if (data.glowColor) glowColor = Qt.color(normHex(data.glowColor));
            if (data.glowSecondary) glowSecondary = Qt.color(normHex(data.glowSecondary));
            if (data.accentSecondary) accentSecondary = Qt.color(normHex(data.accentSecondary));
            if (data.onSecondaryContainer) secondaryFg = Qt.color(normHex(data.onSecondaryContainer));
            if (data.secondaryFg) secondaryFg = Qt.color(normHex(data.secondaryFg));
            if (data.hvrBg) hvrBg = Qt.color(normHex(data.hvrBg));
            if (data.hvrFg) hvrFg = Qt.color(normHex(data.hvrFg));
            if (data.borderColor) borderColor = Qt.color(normHex(data.borderColor));
            if (data.errorColor) errorColor = Qt.color(normHex(data.errorColor));
            if (data.barOpacity !== undefined) barOpacity = Number(data.barOpacity);
            if (data.pillOpacity !== undefined) pillOpacity = Number(data.pillOpacity);
            if (data.cornerRadius !== undefined) cornerRadius = Number(data.cornerRadius) || 23;
            if (data.wallBlurPath !== undefined) wallBlurPath = data.wallBlurPath;
        } catch (e) {
            // Keep existing palette if JSON is mid-write
        }
    }
}
