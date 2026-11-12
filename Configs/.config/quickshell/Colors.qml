import QtQuick

QtObject {
    id: colors
    // Wallpaper-adaptive Frosted Glass palette (seeded with Soul's Market cyan-mist, updated dynamically from wall.dcol / Wallbash)
    property color barBg: "#05070b"
    property color mainBg: "#05070b"
    property color surfaceBg: "#070b10"
    property color layer2Bg: "#0c141d"
    property color mainFg: "#f5fbff"
    property color subFg: "#9ab4c7"
    property color actBg: "#00e5ff"
    property color glowColor: "#00e5ff"
    property color glowSecondary: "#9ef8ff"
    property color accentSecondary: "#0f2533"
    property color onSecondaryContainer: "#e3faff"
    property color actFg: "#030b10"
    property color hvrBg: "#122838"
    property color hvrFg: "#ffffff"
    property color borderColor: "#b8f2ff"
    property color errorColor: "#ff6b8b"
    property color onErrorColor: "#1f0008"
    property real barOpacity: 0.28
    property real pillOpacity: 0.48
    property int cornerRadius: 24
    property int groupRadius: 9999
    property string wallBlurPath: ""

    Behavior on barBg { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on mainBg { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on surfaceBg { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on layer2Bg { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on mainFg { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on subFg { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on actBg { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on glowColor { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on glowSecondary { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on accentSecondary { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on onSecondaryContainer { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on actFg { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on borderColor { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }

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
            else if (data.actBg) glowColor = normHex(data.actBg);
            if (data.glowSecondary) glowSecondary = normHex(data.glowSecondary);
            if (data.accentSecondary) accentSecondary = normHex(data.accentSecondary);
            if (data.onSecondaryContainer) onSecondaryContainer = normHex(data.onSecondaryContainer);
            if (data.actFg) actFg = normHex(data.actFg);
            if (data.hvrBg) hvrBg = normHex(data.hvrBg);
            if (data.hvrFg) hvrFg = normHex(data.hvrFg);
            if (data.borderColor) borderColor = normHex(data.borderColor);
            if (data.barOpacity !== undefined) barOpacity = Number(data.barOpacity);
            if (data.pillOpacity !== undefined) pillOpacity = Number(data.pillOpacity);
            if (data.cornerRadius !== undefined) cornerRadius = Number(data.cornerRadius) || 24;
            if (data.wallBlurPath !== undefined) wallBlurPath = data.wallBlurPath;
        } catch (e) {
            // Keep existing palette if JSON is mid-write
        }
    }
}
