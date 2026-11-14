import QtQuick

QtObject {
    id: colors
    // LOOSE print-poster palette (image-13.png request): warm paper base, bold
    // cobalt-blue inks, white capsule plates, magenta-pink pop accents, flat
    // halftone texture. Fixed brand colors with only a whisper of wallpaper tint.
    property color barBg: "#f2f1e8"          // Warm paper base (linen white)
    property color mainBg: "#f0efe6"         // Paper base
    property color surfaceBg: "#ffffff"      // White capsule / icon plate surface
    property color layer2Bg: "#e9e7da"       // Paper shade inner layer
    property color mainFg: "#2434e0"         // Cobalt ink: text & glyphs
    property color subFg: "#5b62c4"          // Muted cobalt secondary text
    property color actBg: "#2434e0"          // Cobalt blocks (active fills)
    property color glowColor: "#e8449b"      // Magenta-pink pop accent
    property color glowSecondary: "#1b26c8"  // Deep cobalt glow (active pills)
    property color accentSecondary: "#c9d2f7"// Pale cobalt track / occupied surface
    property color secondaryFg: "#2c36b8"    // Deep cobalt ink-2 text/icons
    property color actFg: "#ffffff"          // Foreground on cobalt surfaces
    property color hvrBg: "#e4e8fb"          // Pale cobalt hover state
    property color hvrFg: "#2434e0"
    property color borderColor: "#2233dd"    // Bold cobalt outline (DESIGN-pill style)
    property color errorColor: "#b3261e"
    property color errorFg: "#ffffff"
    property real barOpacity: 1.0            // Opaque paper print
    property real pillOpacity: 1.0           // Flat ink capsules
    property int cornerRadius: 23
    property int groupRadius: 17             // Stadium BarGroup radius (height 34 / 2)
    property string wallBlurPath: ""

    // Palette source arbitration: "dcol" when wallbash colors drove the last
    // update (richer semantic palette), "image" when the QML wallpaper sampler
    // did (works without wallbash). The sampler defers to wallbash.
    property string wallSyncSource: "none"

    function rgbHex(r, g, b) {
        function h(v) {
            var s = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16);
            return s.length < 2 ? "0" + s : s;
        }
        return "#" + h(r) + h(g) + h(b);
    }

    // Derive the whole pale palette from the wallpaper's dominant tone
    // (end-4 ii style: bar colors come straight from the wallpaper image).
    function syncWallTone(r, g, b) {
        var tone = rgbHex(r, g, b);
        barBg = subtleTint("#f2f1e8", tone, 0.12);
        mainBg = subtleTint("#f0efe6", tone, 0.10);
        surfaceBg = subtleTint("#ffffff", tone, 0.10);
        layer2Bg = subtleTint("#e9e7da", tone, 0.14);
        mainFg = subtleTint("#2434e0", tone, 0.08);
        subFg = subtleTint("#5b62c4", tone, 0.10);
        secondaryFg = subtleTint("#2c36b8", tone, 0.08);
        accentSecondary = subtleTint("#c9d2f7", tone, 0.14);
        borderColor = subtleTint("#2233dd", tone, 0.10);
    }

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
            if (data.barBg) barBg = subtleTint("#f2f1e8", data.barBg, 0.12);
            if (data.mainBg) mainBg = subtleTint("#f0efe6", data.mainBg, 0.12);
            if (data.surfaceBg) surfaceBg = subtleTint("#ffffff", data.surfaceBg, 0.12);
            if (data.layer2Bg) layer2Bg = subtleTint("#e9e7da", data.layer2Bg, 0.14);
            if (data.mainFg) mainFg = subtleTint("#2434e0", data.mainFg, 0.08);
            if (data.subFg) subFg = subtleTint("#5b62c4", data.subFg, 0.08);
            if (data.actBg) actBg = subtleTint("#2434e0", data.actBg, 0.08);
            if (data.glowColor) glowColor = subtleTint("#e8449b", data.glowColor, 0.08);
            if (data.glowSecondary) glowSecondary = subtleTint("#1b26c8", data.glowSecondary, 0.08);
            if (data.accentSecondary) accentSecondary = subtleTint("#c9d2f7", data.accentSecondary, 0.14);
            if (data.onSecondaryContainer) secondaryFg = subtleTint("#2c36b8", data.onSecondaryContainer, 0.10);
            if (data.secondaryFg) secondaryFg = subtleTint("#2c36b8", data.secondaryFg, 0.10);
            if (data.borderColor) borderColor = subtleTint("#2233dd", data.borderColor, 0.10);
            if (data.barOpacity !== undefined) barOpacity = Number(data.barOpacity);
            if (data.pillOpacity !== undefined) pillOpacity = Number(data.pillOpacity);
            if (data.cornerRadius !== undefined) cornerRadius = Number(data.cornerRadius) || 23;
            if (data.wallBlurPath !== undefined) wallBlurPath = data.wallBlurPath;
        } catch (e) {
            // Keep existing palette if JSON is mid-write
        }
    }
}
