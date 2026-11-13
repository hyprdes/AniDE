import QtQuick

QtObject {
    id: colors
    // Pale-white wallpaper-synced palette (image-11.png request): soft white glass surfaces,
    // deep ink foregrounds, @lisa.p.ng orange-coral + violet accents. No multicolor gradients.
    property color barBg: "#ebeaf2"          // Pale white Hug bar frame base
    property color mainBg: "#f0eff6"         // Pale white base
    property color surfaceBg: "#f5f4fa"      // Pale white capsule / icon plate surface
    property color layer2Bg: "#e3e2ec"       // Slightly deeper pale inner layer
    property color mainFg: "#242739"         // Deep ink foreground text & glyphs
    property color subFg: "#5c6174"          // Muted ink secondary text
    property color actBg: "#ff4f18"          // Vibrant @lisa.p.ng orange-coral accent
    property color glowColor: "#ff5722"      // Warm orange-coral accent glow
    property color glowSecondary: "#6366f1"  // Violet accent glow (active pills)
    property color accentSecondary: "#d9d7e5"// Pale track / occupied surface
    property color secondaryFg: "#3c4054"    // Ink-2 text/icons
    property color actFg: "#ffffff"          // Foreground on accent (violet/orange) surfaces
    property color hvrBg: "#e4e2ee"          // Pale hover state
    property color hvrFg: "#242739"
    property color borderColor: "#c9c7d6"    // Soft ink border on pale glass
    property color errorColor: "#b3261e"
    property color errorFg: "#ffffff"
    property real barOpacity: 0.80           // Translucent pale bar opacity
    property real pillOpacity: 0.85          // Pale capsule opacity
    property int cornerRadius: 23
    property int groupRadius: 17             // Stadium BarGroup radius (height 34 / 2)
    property string wallBlurPath: ""

    function normHex(val) {
        if (!val) return "";
        var s = val.toString().trim();
        if (s === "") return "";
        return s.charAt(0) === "#" ? s : ("#" + s);
    }

    // Blend a subtle atmospheric wallpaper tint while preserving the pale-white + orange-coral palette
    function subtleTint(baseHex, tintHex, amount) {
        var b = Qt.color(baseHex);
        if (!tintHex || tintHex === "") return b;
        var t = Qt.color(normHex(tintHex));
        return Qt.tint(b, Qt.rgba(t.r, t.g, t.b, amount));
    }

    function applyJson(raw) {
        if (!raw) return;
        try {
            var data = JSON.parse(raw);
            if (data.barBg) barBg = subtleTint("#ebeaf2", data.barBg, 0.12);
            if (data.mainBg) mainBg = subtleTint("#f0eff6", data.mainBg, 0.12);
            if (data.surfaceBg) surfaceBg = subtleTint("#f5f4fa", data.surfaceBg, 0.12);
            if (data.layer2Bg) layer2Bg = subtleTint("#e3e2ec", data.layer2Bg, 0.12);
            if (data.mainFg) mainFg = subtleTint("#242739", data.mainFg, 0.10);
            if (data.subFg) subFg = subtleTint("#5c6174", data.subFg, 0.12);
            if (data.actBg) actBg = subtleTint("#ff4f18", data.actBg, 0.10);
            if (data.glowColor) glowColor = subtleTint("#ff5722", data.glowColor, 0.10);
            if (data.glowSecondary) glowSecondary = subtleTint("#6366f1", data.glowSecondary, 0.12);
            if (data.accentSecondary) accentSecondary = subtleTint("#d9d7e5", data.accentSecondary, 0.12);
            if (data.onSecondaryContainer) secondaryFg = subtleTint("#3c4054", data.onSecondaryContainer, 0.10);
            if (data.secondaryFg) secondaryFg = subtleTint("#3c4054", data.secondaryFg, 0.10);
            if (data.borderColor) borderColor = subtleTint("#c9c7d6", data.borderColor, 0.12);
            if (data.barOpacity !== undefined) barOpacity = Number(data.barOpacity);
            if (data.pillOpacity !== undefined) pillOpacity = Number(data.pillOpacity);
            if (data.cornerRadius !== undefined) cornerRadius = Number(data.cornerRadius) || 23;
            if (data.wallBlurPath !== undefined) wallBlurPath = data.wallBlurPath;
        } catch (e) {
            // Keep existing palette if JSON is mid-write
        }
    }
}
