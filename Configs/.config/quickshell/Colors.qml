import QtQuick

QtObject {
    id: colors
    property color barBg: "#0d1117"
    property color mainBg: "#0d1117"
    property color surfaceBg: "#161c24"
    property color mainFg: "#e6edf3"
    property color subFg: "#8b949e"
    property color actBg: "#7dcfff"
    property color accentSecondary: "#bb9af7"
    property color actFg: "#0d1117"
    property color hvrBg: "#212936"
    property color hvrFg: "#e6edf3"
    property color borderColor: "#2a3444"
    property color successColor: "#73daca"
    property color warnColor: "#e0af68"
    property color dangerColor: "#f7768e"
    property int cornerRadius: 18

    function applyJson(raw) {
        if (!raw) return;
        try {
            var data = JSON.parse(raw);
            if (data.barBg) barBg = data.barBg;
            if (data.mainBg) mainBg = data.mainBg;
            if (data.surfaceBg) surfaceBg = data.surfaceBg;
            if (data.mainFg) mainFg = data.mainFg;
            if (data.subFg) subFg = data.subFg;
            if (data.actBg) actBg = data.actBg;
            if (data.accentSecondary) accentSecondary = data.accentSecondary;
            if (data.actFg) actFg = data.actFg;
            if (data.hvrBg) hvrBg = data.hvrBg;
            if (data.hvrFg) hvrFg = data.hvrFg;
            if (data.borderColor) borderColor = data.borderColor;
            if (data.cornerRadius !== undefined) cornerRadius = Number(data.cornerRadius) || 18;
        } catch (e) {
            // Keep existing theme values if JSON is mid-write
        }
    }
}
