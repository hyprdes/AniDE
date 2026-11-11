import QtQuick

QtObject {
    id: colors
    property color barBg: "#101419"
    property color mainBg: "#101419"
    property color surfaceBg: "#1a2028"
    property color mainFg: "#93cee9"
    property color subFg: "#7aa8c4"
    property color actBg: "#93cee9"
    property color actFg: "#101419"
    property color hvrBg: "#27323f"
    property color hvrFg: "#93cee9"
    property color borderColor: "#2c3847"
    property int cornerRadius: 16

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
            if (data.actFg) actFg = data.actFg;
            if (data.hvrBg) hvrBg = data.hvrBg;
            if (data.hvrFg) hvrFg = data.hvrFg;
            if (data.borderColor) borderColor = data.borderColor;
            if (data.cornerRadius !== undefined) cornerRadius = Number(data.cornerRadius) || 16;
        } catch (e) {
            // Keep existing theme values if JSON is mid-write
        }
    }
}
