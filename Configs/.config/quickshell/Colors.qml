import QtQuick

QtObject {
    id: colors
    // Sculpted Dark Matte-Glass UI palette (modeled on @bee_ui.ux image-7.png + dynamic Wallbash tinting)
    property color barBg: "#0e1115"          // Deep obsidian outer frame & notch base
    property color mainBg: "#12161b"         // Dark glass base
    property color surfaceBg: "#262c34"      // Matte charcoal-slate capsule surface
    property color layer2Bg: "#323943"       // Oblong inner pill & inactive orb surface
    property color mainFg: "#e6ebf0"         // Crisp frosted white text/icons
    property color subFg: "#8b95a1"          // Muted cool slate subtext
    property color actBg: "#e2e8f0"          // Frosted silver-white active pill/orb highlight
    property color glowColor: "#7dd3fc"      // Subtle ice-cyan ambient highlight
    property color glowSecondary: "#cbd5e1"
    property color accentSecondary: "#333b45"// Matte slate secondary pill fill
    property color secondaryFg: "#dde4ed"    // Crisp foreground on secondary pills
    property color actFg: "#0f1318"          // Dark foreground on frosted white active pill
    property color hvrBg: "#3d4652"          // Hover state for pills & orbs
    property color hvrFg: "#f8fafc"
    property color borderColor: "#38414d"    // Crisp 1px specular rim border
    property color errorColor: "#ffb4ab"
    property color errorFg: "#690005"
    property real barOpacity: 0.86           // Sculpted dark glass frame opacity
    property real pillOpacity: 0.56          // Soft matte-glass oblong pill translucency
    property int cornerRadius: 23            // Concave screen & notch corner radius
    property int groupRadius: 16
    property string wallBlurPath: ""

    function normHex(val) {
        if (!val) return "";
        var s = val.toString().trim();
        if (s === "") return "";
        return s.charAt(0) === "#" ? s : ("#" + s);
    }

    function applyJson(raw) {
        if (!raw) return;
        try {
            var data = JSON.parse(raw);
            if (data.barBg) barBg = normHex(data.barBg);
            if (data.mainBg) mainBg = normHex(data.mainBg);
            if (data.surfaceBg) surfaceBg = normHex(data.surfaceBg);
            if (data.layer2Bg) layer2Bg = normHex(data.layer2Bg);
            if (data.mainFg) mainFg = normHex(data.mainFg);
            if (data.subFg) subFg = normHex(data.subFg);
            if (data.actBg) actBg = normHex(data.actBg);
            if (data.glowColor) glowColor = normHex(data.glowColor);
            if (data.glowSecondary) glowSecondary = normHex(data.glowSecondary);
            if (data.accentSecondary) accentSecondary = normHex(data.accentSecondary);
            if (data.onSecondaryContainer) secondaryFg = normHex(data.onSecondaryContainer);
            if (data.secondaryFg) secondaryFg = normHex(data.secondaryFg);
            if (data.actFg) actFg = normHex(data.actFg);
            if (data.hvrBg) hvrBg = normHex(data.hvrBg);
            if (data.hvrFg) hvrFg = normHex(data.hvrFg);
            if (data.borderColor) borderColor = normHex(data.borderColor);
            if (data.barOpacity !== undefined) barOpacity = Number(data.barOpacity);
            if (data.pillOpacity !== undefined) pillOpacity = Number(data.pillOpacity);
            if (data.cornerRadius !== undefined) cornerRadius = Number(data.cornerRadius) || 23;
            if (data.wallBlurPath !== undefined) wallBlurPath = data.wallBlurPath;
        } catch (e) {
            // Keep existing palette if JSON is mid-write
        }
    }
}
