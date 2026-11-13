import QtQuick

QtObject {
    id: colors
    // end-4 Illogical Impulse (ii) + Liquid Glass + @lisa.p.ng (image-10.png) Orange-Coral & Frosted Indigo-Violet Palette
    property color barBg: "#0e1017"          // Deep obsidian-indigo Hug bar frame
    property color mainBg: "#12141f"         // Dark indigo-obsidian base
    property color surfaceBg: "#1e2238"      // Liquid glass capsule deep indigo surface
    property color layer2Bg: "#313866"       // Frosted indigo-violet inner glass layer
    property color mainFg: "#ffffff"         // Pure snow-white foreground text & icons
    property color subFg: "#9ca3c9"          // Soft lavender-slate muted text
    property color actBg: "#ff4f18"          // Vibrant @lisa.p.ng orange-coral accent (image-10.png)
    property color glowColor: "#ff5722"      // Warm orange-coral subsurface glow
    property color glowSecondary: "#6366f1"  // Frosted indigo-violet glass refraction glow
    property color accentSecondary: "#3d4582"// Translucent indigo-violet occupied pill/track surface
    property color secondaryFg: "#e2e6ff"    // Crisp ice-lavender text/icons
    property color actFg: "#ffffff"          // Pure snow-white active icon/text
    property color hvrBg: "#464f96"          // Frosted indigo hover state
    property color hvrFg: "#ffffff"
    property color borderColor: "#8b93e8"    // Liquid glass specular border highlight
    property color errorColor: "#ffb4ab"
    property color errorFg: "#690005"
    property real barOpacity: 0.80           // Translucent Liquid Glass bar opacity
    property real pillOpacity: 0.58          // Liquid Glass BarGroup capsule opacity
    property int cornerRadius: 23
    property int groupRadius: 17             // Stadium BarGroup radius (height 34 / 2)
    property string wallBlurPath: ""

    function normHex(val) {
        if (!val) return "";
        var s = val.toString().trim();
        if (s === "") return "";
        return s.charAt(0) === "#" ? s : ("#" + s);
    }

    // Blend a subtle 14% atmospheric wallpaper tint while preserving the @lisa.p.ng indigo-glass + orange-coral palette
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
            if (data.barBg) barBg = subtleTint("#0e1017", data.barBg, 0.14);
            if (data.mainBg) mainBg = subtleTint("#12141f", data.mainBg, 0.14);
            if (data.surfaceBg) surfaceBg = subtleTint("#1e2238", data.surfaceBg, 0.14);
            if (data.layer2Bg) layer2Bg = subtleTint("#313866", data.layer2Bg, 0.14);
            if (data.mainFg) mainFg = subtleTint("#ffffff", data.mainFg, 0.06);
            if (data.subFg) subFg = subtleTint("#9ca3c9", data.subFg, 0.12);
            if (data.actBg) actBg = subtleTint("#ff4f18", data.actBg, 0.10);
            if (data.glowColor) glowColor = subtleTint("#ff5722", data.glowColor, 0.10);
            if (data.glowSecondary) glowSecondary = subtleTint("#6366f1", data.glowSecondary, 0.16);
            if (data.accentSecondary) accentSecondary = subtleTint("#3d4582", data.accentSecondary, 0.14);
            if (data.onSecondaryContainer) secondaryFg = subtleTint("#e2e6ff", data.onSecondaryContainer, 0.10);
            if (data.secondaryFg) secondaryFg = subtleTint("#e2e6ff", data.secondaryFg, 0.10);
            if (data.borderColor) borderColor = subtleTint("#8b93e8", data.borderColor, 0.14);
            if (data.barOpacity !== undefined) barOpacity = Number(data.barOpacity);
            if (data.pillOpacity !== undefined) pillOpacity = Number(data.pillOpacity);
            if (data.cornerRadius !== undefined) cornerRadius = Number(data.cornerRadius) || 23;
            if (data.wallBlurPath !== undefined) wallBlurPath = data.wallBlurPath;
        } catch (e) {
            // Keep existing palette if JSON is mid-write
        }
    }
}
