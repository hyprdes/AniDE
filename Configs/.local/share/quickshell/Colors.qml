import QtQuick

QtObject {
    id: colors
    // Wallpaper green palette (image-18.png request): the bar is a translucent
    // sage-green glass with cream ink, deep-green capsule plates and a lime
    // accent. The values are sampled from image-18 (mean tone #6F8F55, card
    // green #5D8839, deep ink #3A5C37, pale pill #C5D1AD, lime #ADBC66).
    property color barBg: "#6f8f55"          // Wallpaper mean tone (bar glass)
    property color mainBg: "#5d8839"         // Card green
    property color surfaceBg: "#3a5c37"      // Deep-green capsule / icon plate
    property color layer2Bg: "#4d6d39"       // Inner layer
    property color mainFg: "#fdfff7"         // Cream ink: text & glyphs
    property color subFg: "#c5d1ad"          // Pale sage secondary text
    property color actBg: "#adbc66"          // Lime active fill
    property color glowColor: "#adbc66"      // Lime accent
    property color glowSecondary: "#8da968"  // Soft green glow (active pills)
    property color accentSecondary: "#86a06a"// Occupied surface track
    property color secondaryFg: "#c5d1ad"    // Pale sage ink-2 text/icons
    property color actFg: "#1e2e1a"          // Dark green ink on lime
    property color hvrBg: "#4d6d39"          // Hover state
    property color hvrFg: "#fdfff7"
    property color borderColor: "#2e4a2b"    // Deep green outline
    property color errorColor: "#b3261e"
    property color errorFg: "#ffffff"
    property real barOpacity: 0.9            // Glass: the wallpaper shows through
    property real pillOpacity: 1.0
    property int cornerRadius: 23
    property int groupRadius: 17             // Stadium BarGroup radius (height 34 / 2)
    property string wallBlurPath: ""

    // ── Frame layout (image-1 request): flat light frame on all four screen
    // edges, a notch on top, a tab and white pills at the bottom ──
    // followWallpaper = false (default): fixed light colors, the frame ignores
    // the wallpaper palette above. true: the frame takes that palette and the
    // glass icon / print texture skin again. Set it in frame.json (theme.json
    // is rewritten on every wallpaper change, so the switch cannot live there).
    property bool followWallpaper: false
    property color frameBgLight: "#f2f2f2"        // Frame (sampled from image-1)
    property color framePillLight: "#ffffff"      // Pills, circles, title tab
    property color frameInkLight: "#1f1f1f"       // Near-black text & glyphs
    property color frameInkSoftLight: "#9a9a9a"   // Placeholder / secondary text
    property color frameIndicatorLight: "#a8a8a8" // Running dash, idle dots
    property color frameHoverLight: "#e8e8e8"     // Hover fill
    property color frameAccentALight: "#9acee3"   // Action button, left stop
    property color frameAccentBLight: "#b3d9d6"   // Action button, right stop
    property color frameAccentInkLight: "#ffffff" // Ink on the action button

    readonly property color frameBg: followWallpaper ? barBg : frameBgLight
    readonly property color framePill: followWallpaper ? surfaceBg : framePillLight
    readonly property color frameInk: followWallpaper ? mainFg : frameInkLight
    readonly property color frameInkSoft: followWallpaper ? subFg : frameInkSoftLight
    readonly property color frameIndicator: followWallpaper ? secondaryFg : frameIndicatorLight
    readonly property color frameHover: followWallpaper ? hvrBg : frameHoverLight
    readonly property color frameAccentA: followWallpaper ? actBg : frameAccentALight
    readonly property color frameAccentB: followWallpaper ? glowSecondary : frameAccentBLight
    readonly property color frameAccentInk: followWallpaper ? actFg : frameAccentInkLight
    readonly property real frameOpacity: followWallpaper ? barOpacity : 1.0

    // Frame geometry. Thickness is a share of the screen, so the proportions
    // of the reference hold on any resolution (image-1 is a 918x515 screen plus
    // 7px of drop shadow below it: top 23, sides 28, bottom 54). frameScale
    // shrinks or grows the whole frame (0.6 gives a compact one).
    property real frameScale: 1.0
    property real frameTopRatio: 0.045      // top edge / screen height
    property real frameSideRatio: 0.030     // side edges / screen width
    property real frameBottomRatio: 0.105   // bottom edge / screen height
    property int framePad: 8                // gap kept between side edges and windows
    property bool frameReserveNotch: true   // windows never go under the notch
    property bool frameReserveTab: true     // windows never go under the title tab
    property string frameFont: "Cantarell"  // text; Qt falls back to the system sans
    property string frameGlyphFont: "JetBrainsMono Nerd Font"
    property var pinnedApps: []             // desktop ids always shown in the notch
    property string inputPlaceholder: "Tìm ứng dụng…"
    property string inputButtonText: "Tìm"

    // Palette source arbitration: "dcol" when wallbash colors drove the last
    // update, "image" when the QML wallpaper sampler did (works without wallbash).
    property string wallSyncSource: "none"

    function rgbHex(r, g, b) {
        function h(v) {
            var s = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16);
            return s.length < 2 ? "0" + s : s;
        }
        return "#" + h(r) + h(g) + h(b);
    }

    function normHex(val) {
        if (!val) return "";
        var s = val.toString().trim();
        if (s === "") return "";
        return s.charAt(0) === "#" ? s : ("#" + s);
    }

    // Derive the whole bar palette from one wallpaper tone (r, g, b in 0..1).
    // The bar takes the wallpaper color itself, so the sync is clearly visible;
    // ink flips to cream on dark tones and to deep green on light tones.
    function syncWallTone(r, g, b) {
        var t = Qt.rgba(Math.max(0, Math.min(1, r)), Math.max(0, Math.min(1, g)), Math.max(0, Math.min(1, b)), 1);
        var lum = 0.2126 * t.r + 0.7152 * t.g + 0.0722 * t.b;
        var light = lum >= 0.6;
        barBg = t;
        mainBg = Qt.darker(t, 1.12);
        surfaceBg = Qt.darker(t, 1.6);
        layer2Bg = Qt.darker(t, 1.3);
        mainFg = light ? "#1e2e1a" : "#fdfff7";
        subFg = light ? "#3a5c37" : "#c5d1ad";
        secondaryFg = subFg;
        actBg = Qt.lighter(t, 1.3);
        actFg = light ? "#fdfff7" : "#1e2e1a";
        glowColor = Qt.lighter(t, 1.35);
        glowSecondary = Qt.lighter(t, 1.15);
        accentSecondary = Qt.lighter(t, 1.2);
        hvrBg = Qt.darker(t, 1.3);
        hvrFg = mainFg;
        borderColor = Qt.darker(t, 1.9);
    }

    // theme.json carries the exact palette (wallbash or the sampler wrote it);
    // its values are used as they are, without any tint.
    function applyJson(raw) {
        if (!raw) return;
        try {
            var data = JSON.parse(raw);
            if (data.barBg) barBg = Qt.color(normHex(data.barBg));
            if (data.mainBg) mainBg = Qt.color(normHex(data.mainBg));
            if (data.surfaceBg) surfaceBg = Qt.color(normHex(data.surfaceBg));
            if (data.layer2Bg) layer2Bg = Qt.color(normHex(data.layer2Bg));
            if (data.mainFg) mainFg = Qt.color(normHex(data.mainFg));
            if (data.subFg) subFg = Qt.color(normHex(data.subFg));
            if (data.actBg) actBg = Qt.color(normHex(data.actBg));
            if (data.actFg) actFg = Qt.color(normHex(data.actFg));
            if (data.glowColor) glowColor = Qt.color(normHex(data.glowColor));
            if (data.glowSecondary) glowSecondary = Qt.color(normHex(data.glowSecondary));
            if (data.accentSecondary) accentSecondary = Qt.color(normHex(data.accentSecondary));
            if (data.onSecondaryContainer) secondaryFg = Qt.color(normHex(data.onSecondaryContainer));
            if (data.secondaryFg) secondaryFg = Qt.color(normHex(data.secondaryFg));
            if (data.hvrBg) hvrBg = Qt.color(normHex(data.hvrBg));
            if (data.hvrFg) hvrFg = Qt.color(normHex(data.hvrFg));
            if (data.borderColor) borderColor = Qt.color(normHex(data.borderColor));
            if (data.errorColor) errorColor = Qt.color(normHex(data.errorColor));
            if (data.barOpacity !== undefined) barOpacity = Number(data.barOpacity);
            if (data.pillOpacity !== undefined) pillOpacity = Number(data.pillOpacity);
            if (data.cornerRadius !== undefined) cornerRadius = Number(data.cornerRadius) || 23;
            if (data.wallBlurPath !== undefined) wallBlurPath = data.wallBlurPath;
        } catch (e) {
            // Keep existing palette if JSON is mid-write
        }
    }

    // frame.json: user-owned switches for the frame layout; every key is
    // optional and a missing or malformed file keeps the defaults above.
    function applyFrameJson(raw) {
        if (!raw) return;
        try {
            var d = JSON.parse(raw);
            if (d.followWallpaper !== undefined) followWallpaper = Boolean(d.followWallpaper);
            if (d.scale !== undefined) frameScale = Math.max(0.5, Math.min(1.5, Number(d.scale) || 1.0));
            if (d.topRatio !== undefined) frameTopRatio = Math.max(0.0, Math.min(0.2, Number(d.topRatio)));
            if (d.sideRatio !== undefined) frameSideRatio = Math.max(0.0, Math.min(0.2, Number(d.sideRatio)));
            if (d.bottomRatio !== undefined) frameBottomRatio = Math.max(0.04, Math.min(0.3, Number(d.bottomRatio)));
            if (d.pad !== undefined) framePad = Math.max(0, Math.min(64, Math.round(Number(d.pad) || 0)));
            if (d.reserveNotch !== undefined) frameReserveNotch = Boolean(d.reserveNotch);
            if (d.reserveTab !== undefined) frameReserveTab = Boolean(d.reserveTab);
            if (d.font) frameFont = String(d.font);
            if (d.pinnedApps instanceof Array) pinnedApps = d.pinnedApps;
            if (d.inputPlaceholder !== undefined) inputPlaceholder = String(d.inputPlaceholder);
            if (d.inputButtonText !== undefined) inputButtonText = String(d.inputButtonText);
            if (d.frameBg) frameBgLight = Qt.color(normHex(d.frameBg));
            if (d.pillBg) framePillLight = Qt.color(normHex(d.pillBg));
            if (d.ink) frameInkLight = Qt.color(normHex(d.ink));
            if (d.inkSoft) frameInkSoftLight = Qt.color(normHex(d.inkSoft));
            if (d.indicator) frameIndicatorLight = Qt.color(normHex(d.indicator));
            if (d.hover) frameHoverLight = Qt.color(normHex(d.hover));
            if (d.accentA) frameAccentALight = Qt.color(normHex(d.accentA));
            if (d.accentB) frameAccentBLight = Qt.color(normHex(d.accentB));
            if (d.accentInk) frameAccentInkLight = Qt.color(normHex(d.accentInk));
        } catch (e) {
            // Keep the current frame settings if JSON is mid-write
        }
    }
}
