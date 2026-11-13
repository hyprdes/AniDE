import QtQuick

QtObject {
    id: colors
    // @bee_ui.ux Sculpted Dark Smoky Matte-Glass + Frosted Silver-White palette (image-7.png)
    property color barBg: "#0c0f13"          // Deep carbon-obsidian outer frame
    property color mainBg: "#11151a"         // Dark smoky glass base
    property color surfaceBg: "#1d2229"      // Sculpted island capsule dark matte base
    property color layer2Bg: "#2c333d"       // Soft matte oblong inner pill & orb surface
    property color mainFg: "#e8edf3"         // Crisp frosted white text/icons
    property color subFg: "#8c96a4"          // Soft cool slate muted text
    property color actBg: "#e4e9f0"          // Frosted silver-white active pill/orb (matches image-7.png)
    property color glowColor: "#93c5fd"      // Subtle cool atmospheric rim glow
    property color glowSecondary: "#cbd5e1"
    property color accentSecondary: "#323944"// Matte charcoal occupied pill/orb surface
    property color secondaryFg: "#dde4ed"    // Crisp light foreground on matte pills
    property color actFg: "#0e1217"          // Deep dark icon/text on frosted white active pill
    property color hvrBg: "#3b4350"          // Soft hover state for matte pills & orbs
    property color hvrFg: "#f8fafc"
    property color borderColor: "#434c59"    // Crisp 1px specular glass rim highlight
    property color errorColor: "#ffb4ab"
    property color errorFg: "#690005"
    property real barOpacity: 0.78           // Soft smoky glass bar translucency
    property real pillOpacity: 0.52          // Soft matte oblong pill translucency
    property int cornerRadius: 23            // Concave screen corner radius
    property int groupRadius: 16
    property string wallBlurPath: ""

    function normHex(val) {
        if (!val) return "";
        var s = val.toString().trim();
        if (s === "") return "";
        return s.charAt(0) === "#" ? s : ("#" + s);
    }

    // Blend a small atmospheric hint (12-15%) of wallpaper color into the @bee_ui.ux dark matte-glass base
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
            if (data.barBg) barBg = subtleTint("#0c0f13", data.barBg, 0.14);
            if (data.mainBg) mainBg = subtleTint("#11151a", data.mainBg, 0.14);
            if (data.surfaceBg) surfaceBg = subtleTint("#1d2229", data.surfaceBg, 0.14);
            if (data.layer2Bg) layer2Bg = subtleTint("#2c333d", data.layer2Bg, 0.14);
            if (data.mainFg) mainFg = subtleTint("#e8edf3", data.mainFg, 0.10);
            if (data.subFg) subFg = subtleTint("#8c96a4", data.subFg, 0.12);
            if (data.actBg) actBg = subtleTint("#e4e9f0", data.actBg, 0.12);
            if (data.glowColor) glowColor = subtleTint("#93c5fd", data.glowColor, 0.20);
            if (data.glowSecondary) glowSecondary = subtleTint("#cbd5e1", data.glowSecondary, 0.15);
            if (data.accentSecondary) accentSecondary = subtleTint("#323944", data.accentSecondary, 0.14);
            if (data.onSecondaryContainer) secondaryFg = subtleTint("#dde4ed", data.onSecondaryContainer, 0.12);
            if (data.secondaryFg) secondaryFg = subtleTint("#dde4ed", data.secondaryFg, 0.12);
            if (data.borderColor) borderColor = subtleTint("#434c59", data.borderColor, 0.15);
            if (data.barOpacity !== undefined) barOpacity = Number(data.barOpacity);
            if (data.pillOpacity !== undefined) pillOpacity = Number(data.pillOpacity);
            if (data.cornerRadius !== undefined) cornerRadius = Number(data.cornerRadius) || 23;
            if (data.wallBlurPath !== undefined) wallBlurPath = data.wallBlurPath;
        } catch (e) {
            // Keep existing palette if JSON is mid-write
        }
    }
}
