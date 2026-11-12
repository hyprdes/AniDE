import QtQuick

QtObject {
    id: colors
    // end-4 Illogical Impulse (ii) Material 3 Dark "Tonal Spot" palette (matches image-5.png)
    property color barBg: "#151217"          // colLayer0
    property color mainBg: "#151217"         // m3background
    property color surfaceBg: "#211c24"      // colLayer1 (BarGroup capsule background)
    property color layer2Bg: "#2e2732"       // colLayer2 (CircleUtilButton background)
    property color mainFg: "#e9e0eb"         // colOnLayer0 / colOnLayer1
    property color subFg: "#988d9e"          // colSubtext / colOnLayer1Inactive
    property color actBg: "#dcbff2"          // colPrimary (active workspace indicator)
    property color glowColor: "#dcbff2"
    property color glowSecondary: "#e8def8"
    property color accentSecondary: "#3b3242"// colSecondaryContainer (connected occupied workspaces & ring track)
    property color onSecondaryContainer: "#e8def8" // colOnSecondaryContainer (ring fill & battery fill)
    property color actFg: "#24172e"          // colOnPrimary
    property color hvrBg: "#38303d"          // colLayer1Hover
    property color hvrFg: "#f5eff7"
    property color borderColor: "#49414e"
    property color errorColor: "#ffb4ab"
    property color onErrorColor: "#690005"
    property real barOpacity: 0.85           // Material 3 Tonal Spot transparency
    property real pillOpacity: 0.90
    property int cornerRadius: 23            // Appearance.rounding.screenRounding (23px Hug corners)
    property int groupRadius: 16             // Smooth capsule rounding inside 40px bar
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
            if (data.onSecondaryContainer) onSecondaryContainer = normHex(data.onSecondaryContainer);
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
