import QtQuick

QtObject {
    id: colors
    // Frosted Sea-Glass / Translucent Deep Slate-Teal Pill Palette (matching image-8.png)
    property color barBg: "#0f1c22"          // Deep abyssal sea-glass left gradient stop
    property color mainBg: "#14252d"         // Translucent deep slate-teal glass base
    property color surfaceBg: "#1c343f"      // Mid-capsule frosted sea-glass slate
    property color layer2Bg: "#274755"       // Right-side luminous frosted teal-cyan glass
    property color mainFg: "#f4f9fc"         // Pure crisp snow-white for active icon/text
    property color subFg: "#7e9aa6"          // Soft muted sea-glass slate
    property color actBg: "#374c56"          // Soft frosted inner pill surface (matching left Home pill in image-8.png)
    property color glowColor: "#cbeaf5"      // Icy sea-glass specular rim highlight
    property color glowSecondary: "#94c5d6"  // Secondary soft cyan-ice rim reflection
    property color accentSecondary: "#2c434d"// Subtle frosted ring/track background
    property color secondaryFg: "#a9c1ca"    // Clean frosted ice-silver for inactive icons/text (matching right 3 icons in image-8.png)
    property color actFg: "#f5f9fc"          // Pure snow-white icon/text inside active inner pill
    property color hvrBg: "#415a66"          // Soft frosted inner pill hover state
    property color hvrFg: "#ffffff"
    property color borderColor: "#b8dce8"    // Crisp 1px icy specular glass border
    property color errorColor: "#ffb4ab"
    property color errorFg: "#690005"
    property real barOpacity: 0.72           // Translucent frosted glass capsule opacity
    property real pillOpacity: 0.22          // Soft frosted inner pill translucency
    property int cornerRadius: 23
    property int groupRadius: 20             // Full stadium pill radius (height 40 / 2)
    property string wallBlurPath: ""

    function normHex(val) {
        if (!val) return "";
        var s = val.toString().trim();
        if (s === "") return "";
        return s.charAt(0) === "#" ? s : ("#" + s);
    }

    // Blend a subtle 14% atmospheric wallpaper tint into the image-8.png frosted sea-glass palette
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
            if (data.barBg) barBg = subtleTint("#0f1c22", data.barBg, 0.14);
            if (data.mainBg) mainBg = subtleTint("#14252d", data.mainBg, 0.14);
            if (data.surfaceBg) surfaceBg = subtleTint("#1c343f", data.surfaceBg, 0.14);
            if (data.layer2Bg) layer2Bg = subtleTint("#274755", data.layer2Bg, 0.14);
            if (data.mainFg) mainFg = subtleTint("#f4f9fc", data.mainFg, 0.08);
            if (data.subFg) subFg = subtleTint("#7e9aa6", data.subFg, 0.12);
            if (data.actBg) actBg = subtleTint("#374c56", data.actBg, 0.14);
            if (data.glowColor) glowColor = subtleTint("#cbeaf5", data.glowColor, 0.16);
            if (data.glowSecondary) glowSecondary = subtleTint("#94c5d6", data.glowSecondary, 0.16);
            if (data.accentSecondary) accentSecondary = subtleTint("#2c434d", data.accentSecondary, 0.14);
            if (data.onSecondaryContainer) secondaryFg = subtleTint("#a9c1ca", data.onSecondaryContainer, 0.10);
            if (data.secondaryFg) secondaryFg = subtleTint("#a9c1ca", data.secondaryFg, 0.10);
            if (data.borderColor) borderColor = subtleTint("#b8dce8", data.borderColor, 0.14);
            if (data.barOpacity !== undefined) barOpacity = Number(data.barOpacity);
            if (data.pillOpacity !== undefined) pillOpacity = Number(data.pillOpacity);
            if (data.cornerRadius !== undefined) cornerRadius = Number(data.cornerRadius) || 23;
            if (data.wallBlurPath !== undefined) wallBlurPath = data.wallBlurPath;
        } catch (e) {
            // Keep existing palette if JSON is mid-write
        }
    }
}
