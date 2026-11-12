import QtQuick

QtObject {
    id: colors
    // Default end-4 rounded layout + dreamy frosted cyan-on-obsidian glass palette (overridden by Wallbash theme.json)
    property color barBg: "#070a0f"          // Deep obsidian translucent bar backdrop
    property color mainBg: "#070a0f"
    property color surfaceBg: "#0d131c"      // Dark frosted glass pill base
    property color layer2Bg: "#141f2c"       // Inner circular button glass base
    property color mainFg: "#f2f7fa"         // Crisp ice-white text
    property color subFg: "#8fa6b8"          // Misty silver-blue subtext
    property color actBg: "#00d8ff"          // Electric cyan active pill
    property color glowColor: "#00e5ff"      // Primary radial mist glow inside frosted pills
    property color glowSecondary: "#7beeff"  // Secondary ice-cyan mist highlight
    property color accentSecondary: "#162b3d"// Occupied workspace capsule
    property color onSecondaryContainer: "#d7f4ff"
    property color actFg: "#041016"          // Deep contrast text on active cyan pill
    property color hvrBg: "#1b2e40"
    property color hvrFg: "#ffffff"
    property color borderColor: "#5ce1ff"    // Luminous specular glass rim
    property color errorColor: "#ff6b8b"
    property color onErrorColor: "#1f0008"
    property real barOpacity: 0.78           // Translucent bar alpha for Hyprland Kawase blur
    property real pillOpacity: 0.74          // Translucent capsule alpha for frosted mist
    property int cornerRadius: 24            // Rounded screen & pill radius (24px)
    property int groupRadius: 9999           // Full stadium/capsule rounding like end-4 & profile pill

    function applyJson(raw) {
        if (!raw) return;
        try {
            var data = JSON.parse(raw);
            if (data.barBg) barBg = data.barBg;
            if (data.mainBg) mainBg = data.mainBg;
            if (data.surfaceBg) surfaceBg = data.surfaceBg;
            if (data.layer2Bg) layer2Bg = data.layer2Bg;
            if (data.mainFg) mainFg = data.mainFg;
            if (data.subFg) subFg = data.subFg;
            if (data.actBg) actBg = data.actBg;
            if (data.glowColor) glowColor = data.glowColor;
            else if (data.actBg) glowColor = data.actBg;
            if (data.glowSecondary) glowSecondary = data.glowSecondary;
            if (data.accentSecondary) accentSecondary = data.accentSecondary;
            if (data.onSecondaryContainer) onSecondaryContainer = data.onSecondaryContainer;
            if (data.actFg) actFg = data.actFg;
            if (data.hvrBg) hvrBg = data.hvrBg;
            if (data.hvrFg) hvrFg = data.hvrFg;
            if (data.borderColor) borderColor = data.borderColor;
            if (data.barOpacity !== undefined) barOpacity = Number(data.barOpacity) || 0.78;
            if (data.pillOpacity !== undefined) pillOpacity = Number(data.pillOpacity) || 0.74;
            if (data.cornerRadius !== undefined) cornerRadius = Number(data.cornerRadius) || 24;
        } catch (e) {
            // Keep existing theme values if JSON is mid-write
        }
    }
}
