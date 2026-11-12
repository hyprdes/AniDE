import QtQuick

QtObject {
    id: colors
    // Soul's Market / image-4 Dreamy Frosted Obsidian & Electric Cyan Mist palette
    property color barBg: "#05070b"          // Ultra-translucent smoky obsidian bar backdrop
    property color mainBg: "#05070b"
    property color surfaceBg: "#070b10"      // Smoky black-glass capsule base
    property color layer2Bg: "#0c141d"       // Inner circular button glass base
    property color mainFg: "#f5fbff"         // Crisp pure ice-white typography (like "profile" & "2025")
    property color subFg: "#9ab4c7"          // Misty silver-cyan secondary text
    property color actBg: "#00e5ff"          // Vivid electric cyan glow (from "#Soul's", "profile", "2025")
    property color glowColor: "#00e5ff"      // Primary diagonal cyan airbrush mist bloom
    property color glowSecondary: "#9ef8ff"  // Bright ice-cyan inner mist core
    property color accentSecondary: "#0f2533"// Frosted deep-cyan occupied workspace capsule
    property color onSecondaryContainer: "#e3faff"
    property color actFg: "#030b10"          // High-contrast obsidian text on glowing cyan pill
    property color hvrBg: "#122838"
    property color hvrFg: "#ffffff"
    property color borderColor: "#b8f2ff"    // Luminous frosted white-cyan glass rim
    property color errorColor: "#ff6b8b"
    property color onErrorColor: "#1f0008"
    property real barOpacity: 0.28           // Low bar alpha so Hyprland 4-pass Kawase blur shines through
    property real pillOpacity: 0.50          // Translucent smoky pill alpha so cyan mist & blur blend dreamingly
    property int cornerRadius: 24            // 24px rounded screen corners & capsule geometry
    property int groupRadius: 9999           // Full stadium/capsule rounding

    function applyJson(raw) {
        if (!raw) return;
        try {
            var data = JSON.parse(raw);
            // Only apply if it's the soul-cyan-mist preset or explicit custom config with glowColor
            if (data.barBg) barBg = data.barBg;
            if (data.mainBg) mainBg = data.mainBg;
            if (data.surfaceBg) surfaceBg = data.surfaceBg;
            if (data.layer2Bg) layer2Bg = data.layer2Bg;
            if (data.mainFg) mainFg = data.mainFg;
            if (data.subFg) subFg = data.subFg;
            if (data.actBg) actBg = data.actBg;
            if (data.glowColor) glowColor = data.glowColor;
            if (data.glowSecondary) glowSecondary = data.glowSecondary;
            if (data.accentSecondary) accentSecondary = data.accentSecondary;
            if (data.onSecondaryContainer) onSecondaryContainer = data.onSecondaryContainer;
            if (data.actFg) actFg = data.actFg;
            if (data.hvrBg) hvrBg = data.hvrBg;
            if (data.hvrFg) hvrFg = data.hvrFg;
            if (data.borderColor) borderColor = data.borderColor;
            if (data.barOpacity !== undefined) barOpacity = Number(data.barOpacity);
            if (data.pillOpacity !== undefined) pillOpacity = Number(data.pillOpacity);
            if (data.cornerRadius !== undefined) cornerRadius = Number(data.cornerRadius) || 24;
        } catch (e) {
            // Keep default dreamy cyan-mist palette if JSON is mid-write
        }
    }
}
