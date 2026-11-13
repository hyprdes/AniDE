// AniDE Quickshell Bar & Draggable Desktop LED Dot-Matrix Clock Widget (image-8.png bar + image-9.png clock widget)
// Top Frosted Sea-Glass Bar + Concave Screen Corners + Caffeine Toggle | Wallpaper LED Dot-Matrix Clock (Draggable + Color Customizer)
// GPL-3.0-or-later; see CREDITS.md.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: shellRoot

    Colors {
        id: theme
    }

    property string timeText: Qt.formatDateTime(new Date(), "HH:mm")
    property string dateText: Qt.formatDateTime(new Date(), "dd/MM")
    property string clock12HourDigits: "0151"
    property string clock24HourDigits: "1351"
    property string clockAmPm: "PM"
    property int volumeLevel: 65
    property bool volumeMuted: false
    property bool micMuted: false
    property int brightnessLevel: 100
    property real cpuUsage: 0.03     // 0.0 .. 1.0
    property real memoryUsage: 0.36  // 0.0 .. 1.0
    property real swapUsage: 0.08    // 0.0 .. 1.0 (Swap / Root disk fallback)
    property real batteryLevel: 0.92 // 0.0 .. 1.0 (defaults to 0.92 on desktop AC)
    property bool batteryCharging: true
    property string networkName: "wlan0"
    property bool bluetoothOn: true
    property bool bluetoothConnected: false
    property bool caffeineActive: false
    property string activeWinClass: ""
    property string activeWinTitle: ""
    property var wsClasses: ({})     // map of wsId -> window class string
    property string wallStamp: ""
    property string wallBlurUrl: ""
    property string wallDynamicHex: "#67e8f9"
    property int paintGeneration: 0

    // ── Draggable Desktop LED Dot-Matrix Clock Widget State (image-9.png) ──
    property bool clockWidgetVisible: true
    property int clockWidgetX: 72
    property int clockWidgetY: 96
    property color clockLedColor: "#ffffff"
    property color clockBgColor: "#050507"
    property real clockBgOpacity: 0.94
    property real clockGlowIntensity: 0.88
    property bool clockUse12Hour: true
    property real clockScale: 1.0
    property bool clockSyncWallpaper: false
    property bool clockCustomizerOpen: false
    property int clockPaintTick: 0

    readonly property string clockConfigPath: Quickshell.env("XDG_CONFIG_HOME")
        ? (Quickshell.env("XDG_CONFIG_HOME") + "/quickshell/clock_widget.json")
        : ((Quickshell.env("HOME") || "") + "/.config/quickshell/clock_widget.json")

    function runCmd(args) {
        Quickshell.execDetached(args);
    }

    function cssRgba(c, a) {
        var r = Math.round((c && c.r !== undefined ? c.r : 0.85) * 255);
        var g = Math.round((c && c.g !== undefined ? c.g : 0.92) * 255);
        var b = Math.round((c && c.b !== undefined ? c.b : 0.96) * 255);
        var alpha = Math.max(0.0, Math.min(1.0, a));
        return "rgba(" + r + "," + g + "," + b + "," + alpha.toFixed(3) + ")";
    }

    function colorToHex(c) {
        if (!c) return "#ffffff";
        var r = Math.max(0, Math.min(255, Math.round((c.r !== undefined ? c.r : 1) * 255)));
        var g = Math.max(0, Math.min(255, Math.round((c.g !== undefined ? c.g : 1) * 255)));
        var b = Math.max(0, Math.min(255, Math.round((c.b !== undefined ? c.b : 1) * 255)));
        var hr = (r < 16 ? "0" : "") + r.toString(16);
        var hg = (g < 16 ? "0" : "") + g.toString(16);
        var hb = (b < 16 ? "0" : "") + b.toString(16);
        return "#" + hr + hg + hb;
    }

    function updateClockTimeStrings() {
        var now = new Date();
        shellRoot.timeText = Qt.formatDateTime(now, "HH:mm");
        shellRoot.dateText = Qt.formatDateTime(now, "dd/MM");
        var h24 = now.getHours();
        var m = now.getMinutes();
        shellRoot.clockAmPm = (h24 >= 12) ? "PM" : "AM";
        var h12 = h24 % 12;
        if (h12 === 0) h12 = 12;
        var sH12 = (h12 < 10 ? "0" : "") + h12.toString();
        var sH24 = (h24 < 10 ? "0" : "") + h24.toString();
        var sM = (m < 10 ? "0" : "") + m.toString();
        shellRoot.clock12HourDigits = sH12 + sM;
        shellRoot.clock24HourDigits = sH24 + sM;
        shellRoot.clockPaintTick += 1;
    }

    function applyClockConfigJson(raw) {
        if (!raw) return;
        try {
            var d = JSON.parse(raw);
            if (d.visible !== undefined) shellRoot.clockWidgetVisible = Boolean(d.visible);
            if (d.x !== undefined) shellRoot.clockWidgetX = Math.max(8, Number(d.x) || 72);
            if (d.y !== undefined) shellRoot.clockWidgetY = Math.max(48, Number(d.y) || 96);
            if (d.ledColor) shellRoot.clockLedColor = Qt.color(d.ledColor);
            if (d.bgColor) shellRoot.clockBgColor = Qt.color(d.bgColor);
            if (d.bgOpacity !== undefined) shellRoot.clockBgOpacity = Math.max(0.0, Math.min(1.0, Number(d.bgOpacity)));
            if (d.glowIntensity !== undefined) shellRoot.clockGlowIntensity = Math.max(0.0, Math.min(1.5, Number(d.glowIntensity)));
            if (d.use12Hour !== undefined) shellRoot.clockUse12Hour = Boolean(d.use12Hour);
            if (d.scale !== undefined) shellRoot.clockScale = Math.max(0.7, Math.min(1.5, Number(d.scale) || 1.0));
            if (d.syncWallpaper !== undefined) shellRoot.clockSyncWallpaper = Boolean(d.syncWallpaper);
            shellRoot.clockPaintTick += 1;
        } catch (e) {
            // Ignore malformed JSON during write
        }
    }

    function saveClockConfig() {
        var payload = JSON.stringify({
            visible: shellRoot.clockWidgetVisible,
            x: Math.round(shellRoot.clockWidgetX),
            y: Math.round(shellRoot.clockWidgetY),
            ledColor: shellRoot.colorToHex(shellRoot.clockLedColor),
            bgColor: shellRoot.colorToHex(shellRoot.clockBgColor),
            bgOpacity: Number(shellRoot.clockBgOpacity.toFixed(2)),
            glowIntensity: Number(shellRoot.clockGlowIntensity.toFixed(2)),
            use12Hour: shellRoot.clockUse12Hour,
            scale: Number(shellRoot.clockScale.toFixed(2)),
            syncWallpaper: shellRoot.clockSyncWallpaper
        }, null, 2);
        shellRoot.runCmd([
            "sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1\"",
            "sh",
            shellRoot.clockConfigPath,
            payload
        ]);
    }

    function iconForClass(cls) {
        if (!cls) return "󰋜";
        var c = cls.toLowerCase();
        if (c.indexOf("firefox") >= 0 || c.indexOf("zen") >= 0 || c.indexOf("floorp") >= 0) return "󰈹";
        if (c.indexOf("chrom") >= 0 || c.indexOf("brave") >= 0) return "";
        if (c.indexOf("kitty") >= 0 || c.indexOf("alacritty") >= 0 || c.indexOf("wezterm") >= 0 || c.indexOf("foot") >= 0 || c.indexOf("term") >= 0) return "";
        if (c.indexOf("code") >= 0 || c.indexOf("codium") >= 0 || c.indexOf("nvim") >= 0 || c.indexOf("zed") >= 0) return "󰨞";
        if (c.indexOf("tweak") >= 0 || c.indexOf("setting") >= 0 || c.indexOf("control") >= 0 || c.indexOf("anide") >= 0) return "󰒓";
        if (c.indexOf("dolphin") >= 0 || c.indexOf("nautilus") >= 0 || c.indexOf("thunar") >= 0 || c.indexOf("files") >= 0) return "󰉋";
        if (c.indexOf("discord") >= 0 || c.indexOf("vesktop") >= 0 || c.indexOf("telegram") >= 0) return "󰙯";
        if (c.indexOf("spotify") >= 0 || c.indexOf("mpv") >= 0 || c.indexOf("vlc") >= 0) return "󰎁";
        if (c.indexOf("obs") >= 0) return "󰑋";
        if (c.indexOf("git") >= 0) return "";
        if (c.indexOf("steam") >= 0 || c.indexOf("lutris") >= 0) return "󰓓";
        return "󰋜";
    }

    // Default workspace slot icons matching image-8.png: Home, Check-circle, Calendar, Target, Terminal
    function iconForWorkspaceSlot(slotIndex) {
        var icons = ["󰋜", "󰄲", "󰃭", "󰓾", "󰆍"];
        return icons[slotIndex % icons.length];
    }

    // Live theme.json hot-reload
    FileView {
        id: themeFile
        path: Quickshell.env("XDG_CONFIG_HOME")
            ? (Quickshell.env("XDG_CONFIG_HOME") + "/quickshell/theme.json")
            : ((Quickshell.env("HOME") || "") + "/.config/quickshell/theme.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            theme.applyJson(text());
            if (theme.wallBlurPath !== "") {
                shellRoot.wallBlurUrl = "file://" + theme.wallBlurPath;
            }
            shellRoot.paintGeneration += 1;
        }
    }

    // Live clock_widget.json load
    FileView {
        id: clockConfigFile
        path: shellRoot.clockConfigPath
        watchChanges: false
        onLoaded: {
            shellRoot.applyClockConfigJson(text());
        }
    }

    // Clock, system telemetry, caffeine state & live wallpaper (.dcol) polling
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            shellRoot.updateClockTimeStrings();
            if (!statusProc.running) {
                statusProc.running = true;
            }
        }
    }

    Process {
        id: statusProc
        command: [
            "sh", "-c",
            "vol=$(pamixer --get-volume 2>/dev/null || echo 65); " +
            "mute=$(pamixer --get-mute 2>/dev/null || echo false); " +
            "micm=$(pamixer --default-source --get-mute 2>/dev/null || echo false); " +
            "br=$(brightnessctl -m 2>/dev/null | awk -F, '{gsub(/%/,\"\",$4); print $4}' | head -n1); " +
            "[ -n \"$br\" ] || br=100; " +
            "ram=$(awk '/MemTotal:/ {t=$2} /MemAvailable:/ {a=$2} END {if(t>0) printf \"%d\", (t-a)*100/t; else print 36}' /proc/meminfo 2>/dev/null || echo 36); " +
            "swp=$(awk '/SwapTotal:/ {t=$2} /SwapFree:/ {f=$2} END {if(t>0) printf \"%d\", (t-f)*100/t; else print -1}' /proc/meminfo 2>/dev/null || echo -1); " +
            "if [ \"$swp\" -le 0 ] 2>/dev/null; then swp=$(df -P / 2>/dev/null | awk 'NR==2 {gsub(/%/,\"\",$5); print $5}' || echo 8); fi; " +
            "cpu_stat=/tmp/anide_qs_cpu.stat; " +
            "read -r _ u n s i io ir so st _ < /proc/stat; " +
            "tot=$((u+n+s+i+io+ir+so+st)); idle=$((i+io)); cpu=3; " +
            "if [ -r \"$cpu_stat\" ]; then " +
            "  read -r ptot pidle < \"$cpu_stat\" || true; " +
            "  dt=$((tot - ptot)); di=$((idle - pidle)); " +
            "  if [ \"$dt\" -gt 0 ]; then cpu=$(( (dt - di) * 100 / dt )); fi; " +
            "fi; " +
            "printf '%s %s\\n' \"$tot\" \"$idle\" > \"$cpu_stat\"; " +
            "bat=92; bstat='Charging'; " +
            "for b in /sys/class/power_supply/BAT*; do " +
            "  if [ -r \"$b/capacity\" ]; then bat=$(cat \"$b/capacity\"); bstat=$(cat \"$b/status\" 2>/dev/null); break; fi; " +
            "done; " +
            "net=$(nmcli -t -f NAME connection show --active 2>/dev/null | grep -v '^lo$' | head -n1); " +
            "bton=$(bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2}' | head -n1); " +
            "btcon=$(bluetoothctl info 2>/dev/null | awk '/Connected:/ {print $2}' | head -n1); " +
            "wclass=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty' 2>/dev/null || true); " +
            "wtitle=$(hyprctl activewindow -j 2>/dev/null | jq -r '.title // empty' 2>/dev/null || true); " +
            "wsmap=$(hyprctl clients -j 2>/dev/null | jq -r '[.[] | select(.workspace.id != null and .class != null) | \"\\(.workspace.id):\\(.class)\"] | join(\",\")' 2>/dev/null || true); " +
            "chome=\"${XDG_CACHE_HOME:-$HOME/.cache}/hyde\"; " +
            "wblr=''; " +
            "if [ -e \"$chome/wall.blur\" ]; then wblr=$(readlink -f \"$chome/wall.blur\" 2>/dev/null || echo \"$chome/wall.blur\"); " +
            "elif [ -e \"$chome/wall.set\" ]; then wblr=$(readlink -f \"$chome/wall.set\" 2>/dev/null || echo \"$chome/wall.set\"); fi; " +
            "dfile=''; " +
            "if [ -f \"$chome/wall.dcol\" ]; then dfile=$(readlink -f \"$chome/wall.dcol\" 2>/dev/null || echo \"$chome/wall.dcol\"); " +
            "elif [ -f \"$chome/wallbash/shell-colors\" ]; then dfile=\"$chome/wallbash/shell-colors\"; fi; " +
            "wstamp=''; dcols=''; " +
            "if [ -n \"$dfile\" ] && [ -r \"$dfile\" ]; then " +
            "  wstamp=$(stat -c '%Y' \"$dfile\" 2>/dev/null || echo 1); " +
            "  . \"$dfile\" 2>/dev/null || true; " +
            "  p1=\"${dcol_pry1:-${wallbash_pry1:-}}\"; " +
            "  x12=\"${dcol_1xa2:-${wallbash_1xa2:-}}\"; " +
            "  x13=\"${dcol_1xa3:-${wallbash_1xa3:-}}\"; " +
            "  x16=\"${dcol_1xa6:-${wallbash_1xa6:-}}\"; " +
            "  x19=\"${dcol_1xa9:-${wallbash_1xa9:-}}\"; " +
            "  x23=\"${dcol_2xa3:-${wallbash_2xa3:-}}\"; " +
            "  x28=\"${dcol_2xa8:-${wallbash_2xa8:-}}\"; " +
            "  x29=\"${dcol_2xa9:-${wallbash_2xa9:-}}\"; " +
            "  dcols=\"${p1},${x12},${x13},${x16},${x19},${x23},${x28},${x29}\"; " +
            "fi; " +
            "caf=0; cfile=\"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hyde/caffeine\"; " +
            "if [ -r \"$cfile\" ]; then " +
            "  IFS='|' read -r cint cpid < \"$cfile\" || true; " +
            "  if [ \"$cint\" = \"1\" ] && [ -n \"$cpid\" ] && kill -0 \"$cpid\" 2>/dev/null; then caf=1; fi; " +
            "fi; " +
            "printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\\n' " +
            "\"$vol\" \"$mute\" \"$micm\" \"$br\" \"$cpu\" \"$ram\" \"$swp\" \"$bat\" \"$bstat\" \"$net\" \"$bton\" \"$btcon\" \"$wclass\" \"$wtitle\" \"$wsmap\" \"$wblr\" \"$wstamp\" \"$dcols\" \"$caf\""
        ]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|");
                if (parts.length >= 15) {
                    shellRoot.volumeLevel = parseInt(parts[0], 10) || 0;
                    shellRoot.volumeMuted = (parts[1] === "true");
                    shellRoot.micMuted = (parts[2] === "true");
                    shellRoot.brightnessLevel = parseInt(parts[3], 10) || 100;
                    var c = Math.max(0, Math.min(100, parseInt(parts[4], 10) || 0));
                    var r = Math.max(0, Math.min(100, parseInt(parts[5], 10) || 0));
                    var s = Math.max(0, Math.min(100, parseInt(parts[6], 10) || 0));
                    shellRoot.cpuUsage = c / 100.0;
                    shellRoot.memoryUsage = r / 100.0;
                    shellRoot.swapUsage = s / 100.0;
                    var b = parseInt(parts[7], 10);
                    shellRoot.batteryLevel = (isNaN(b) || b < 0) ? 0.92 : (b / 100.0);
                    shellRoot.batteryCharging = (parts[8] === "Charging" || parts[8] === "Full" || parts[8] === "");
                    shellRoot.networkName = parts[9] || "";
                    shellRoot.bluetoothOn = (parts[10] === "yes");
                    shellRoot.bluetoothConnected = (parts[11] === "yes");
                    shellRoot.activeWinClass = parts[12] || "";
                    shellRoot.activeWinTitle = parts[13] || "";

                    var mapRaw = parts[14] || "";
                    var newMap = {};
                    if (mapRaw !== "") {
                        var pairs = mapRaw.split(",");
                        for (var i = 0; i < pairs.length; i++) {
                            var kv = pairs[i].split(":");
                            if (kv.length >= 2 && kv[0]) {
                                newMap[kv[0]] = kv[1];
                            }
                        }
                    }
                    shellRoot.wsClasses = newMap;
                }
                if (parts.length >= 18) {
                    var wblr = parts[15] || "";
                    var wstamp = parts[16] || "";
                    var dcols = parts[17] || "";
                    if (wblr !== "" && ("file://" + wblr) !== shellRoot.wallBlurUrl) {
                        shellRoot.wallBlurUrl = "file://" + wblr;
                        shellRoot.paintGeneration += 1;
                    }
                    if (dcols !== "" && wstamp !== shellRoot.wallStamp) {
                        shellRoot.wallStamp = wstamp;
                        var dc = dcols.split(",");
                        if (dc.length >= 8 && dc[0] !== "") {
                            theme.barBg = theme.subtleTint("#0f1c22", dc[0], 0.14);
                            theme.mainBg = theme.subtleTint("#14252d", dc[0], 0.14);
                            if (dc[1]) theme.surfaceBg = theme.subtleTint("#1c343f", dc[1], 0.14);
                            if (dc[2]) theme.layer2Bg = theme.subtleTint("#274755", dc[2], 0.14);
                            if (dc[3]) theme.subFg = theme.subtleTint("#7e9aa6", dc[3], 0.12);
                            if (dc[4]) theme.mainFg = theme.subtleTint("#f4f9fc", dc[4], 0.08);
                            if (dc[5]) theme.accentSecondary = theme.subtleTint("#2c434d", dc[5], 0.14);
                            if (dc[6]) {
                                theme.actBg = theme.subtleTint("#374c56", dc[6], 0.14);
                                theme.glowColor = theme.subtleTint("#cbeaf5", dc[6], 0.16);
                                shellRoot.wallDynamicHex = theme.normHex(dc[6]);
                                if (shellRoot.clockSyncWallpaper && shellRoot.wallDynamicHex !== "") {
                                    shellRoot.clockLedColor = Qt.color(shellRoot.wallDynamicHex);
                                    shellRoot.clockPaintTick += 1;
                                }
                            }
                            if (dc[7]) {
                                theme.secondaryFg = theme.subtleTint("#a9c1ca", dc[7], 0.10);
                                theme.glowSecondary = theme.subtleTint("#94c5d6", dc[7], 0.16);
                            }
                            shellRoot.paintGeneration += 1;
                        }
                    }
                }
                if (parts.length >= 19) {
                    shellRoot.caffeineActive = (parts[18] === "1");
                }
            }
        }
    }

    // ── Reusable Frosted Sea-Glass Pill Components (image-8.png style) ──

    // 0. DreamyMistCanvas: Renders the Frosted Sea-Glass Stadium Sheen + 1.2px Diagonal Specular Rim of image-8.png
    component DreamyMistCanvas: Canvas {
        id: mistCanvas
        property color baseColor: theme.surfaceBg
        property color glowPrimary: theme.glowColor
        property color glowAlt: theme.glowSecondary
        property real baseOpacity: theme.barOpacity
        property int generation: shellRoot.paintGeneration

        anchors.fill: parent
        antialiasing: true
        smooth: true

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onBaseColorChanged: requestPaint()
        onGlowPrimaryChanged: requestPaint()
        onGlowAltChanged: requestPaint()
        onBaseOpacityChanged: requestPaint()
        onGenerationChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (width <= 4 || height <= 4) return;
            var r = height / 2;
            var inset = 0.75;
            var ri = Math.max(1, r - inset);

            // 1. Main Translucent Sea-Glass Horizontal-Diagonal Gradient (deep left -> luminous right, matching image-8.png)
            ctx.beginPath();
            ctx.moveTo(inset + ri, inset);
            ctx.lineTo(width - inset - ri, inset);
            ctx.arc(width - inset - ri, height / 2, ri, -Math.PI / 2, Math.PI / 2, false);
            ctx.lineTo(inset + ri, height - inset);
            ctx.arc(inset + ri, height / 2, ri, Math.PI / 2, -Math.PI / 2, false);
            ctx.closePath();

            var bodyGrad = ctx.createLinearGradient(0, height * 0.2, width, height * 0.8);
            bodyGrad.addColorStop(0.0, shellRoot.cssRgba(theme.barBg, 0.82));
            bodyGrad.addColorStop(0.48, shellRoot.cssRgba(theme.surfaceBg, 0.76));
            bodyGrad.addColorStop(1.0, shellRoot.cssRgba(theme.layer2Bg, 0.70));
            ctx.fillStyle = bodyGrad;
            ctx.fill();

            // 2. Right-Side Frosted Sea-Glass Inner Diffusion + Top Frost Veil
            ctx.save();
            ctx.clip();
            var rightGlow = ctx.createRadialGradient(width * 0.88, height * 0.48, 2, width * 0.85, height * 0.5, width * 0.52);
            rightGlow.addColorStop(0.0, shellRoot.cssRgba(glowPrimary, 0.14));
            rightGlow.addColorStop(0.55, shellRoot.cssRgba(glowAlt, 0.05));
            rightGlow.addColorStop(1.0, "rgba(0,0,0,0)");
            ctx.fillStyle = rightGlow;
            ctx.fillRect(0, 0, width, height);

            var sheenGrad = ctx.createLinearGradient(0, 0, 0, height);
            sheenGrad.addColorStop(0.0, "rgba(225, 245, 252, 0.10)");
            sheenGrad.addColorStop(0.45, "rgba(185, 222, 236, 0.02)");
            sheenGrad.addColorStop(1.0, "rgba(6, 14, 18, 0.16)");
            ctx.fillStyle = sheenGrad;
            ctx.fillRect(0, 0, width, height);
            ctx.restore();

            // 3. Crisp 1.25px Diagonal Specular Glass Rim (brighter at top-left & bottom-right curves, matching image-8.png)
            ctx.beginPath();
            ctx.moveTo(inset + ri, inset);
            ctx.lineTo(width - inset - ri, inset);
            ctx.arc(width - inset - ri, height / 2, ri, -Math.PI / 2, Math.PI / 2, false);
            ctx.lineTo(inset + ri, height - inset);
            ctx.arc(inset + ri, height / 2, ri, Math.PI / 2, -Math.PI / 2, false);
            ctx.closePath();

            var rimGrad = ctx.createLinearGradient(0, 0, width, height);
            rimGrad.addColorStop(0.0, shellRoot.cssRgba(glowPrimary, 0.55));
            rimGrad.addColorStop(0.32, shellRoot.cssRgba(glowAlt, 0.22));
            rimGrad.addColorStop(0.68, shellRoot.cssRgba(glowAlt, 0.20));
            rimGrad.addColorStop(1.0, shellRoot.cssRgba(glowPrimary, 0.48));
            ctx.lineWidth = 1.25;
            ctx.strokeStyle = rimGrad;
            ctx.stroke();
        }
    }

    // 1. BarGroup: Hardware-rounded Stadium Pill Capsule (height: 36, radius: 18, matching image-8.png)
    component BarGroup: Rectangle {
        id: grpRoot
        property real padding: 4
        width: implicitWidth
        height: 36
        radius: 18
        color: Qt.alpha(theme.surfaceBg, 0.78)
        border.width: 1
        border.color: Qt.alpha(theme.borderColor, 0.42)

        DreamyMistCanvas {
            anchors.fill: parent
            baseColor: theme.surfaceBg
            baseOpacity: theme.barOpacity
        }
    }

    // 2. CircularResourceRing: Clean Frosted Ice-Silver Circular Progress Ring (18x18) sitting directly on the glass
    component CircularResourceRing: Item {
        id: ringRoot
        property real value: 0.0 // 0.0 .. 1.0
        property string iconText: "󰍛"
        property color primaryColor: theme.secondaryFg
        property color trackColor: theme.accentSecondary
        property int size: 18

        implicitWidth: size
        implicitHeight: size

        onValueChanged: ringCanvas.requestPaint()
        onPrimaryColorChanged: ringCanvas.requestPaint()
        onTrackColorChanged: ringCanvas.requestPaint()

        Canvas {
            id: ringCanvas
            anchors.fill: parent
            antialiasing: true
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var cx = width / 2;
                var cy = height / 2;
                var rOuter = (width / 2) - 1.2;

                ctx.beginPath();
                ctx.arc(cx, cy, rOuter, 0, Math.PI * 2, false);
                ctx.lineWidth = 1.6;
                ctx.strokeStyle = shellRoot.cssRgba(ringRoot.primaryColor, 0.25);
                ctx.stroke();

                var clamped = Math.max(0.0, Math.min(1.0, ringRoot.value));
                if (clamped > 0.01) {
                    ctx.beginPath();
                    ctx.arc(cx, cy, rOuter, -Math.PI / 2, -Math.PI / 2 + clamped * Math.PI * 2, false);
                    ctx.lineWidth = 1.7;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = ringRoot.primaryColor;
                    ctx.stroke();
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: ringRoot.iconText
            color: ringRoot.primaryColor
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 9
        }
    }

    // 3. CircleUtilButton: Clean Icon Button sitting directly on the glass capsule (soft inner frosted pill when active/hovered)
    component CircleUtilButton: Rectangle {
        id: utilBtn
        property string iconText: ""
        property bool activeState: false
        signal triggered()
        signal rightTriggered()

        implicitWidth: 28
        implicitHeight: 28
        radius: 14
        color: utilBtn.activeState
            ? Qt.rgba(0.86, 0.94, 0.98, 0.22)
            : (utilMouse.containsMouse ? Qt.rgba(0.84, 0.93, 0.96, 0.16) : "transparent")
        border.width: utilBtn.activeState ? 1 : 0
        border.color: Qt.rgba(0.92, 0.97, 1.0, 0.14)

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        Text {
            anchors.centerIn: parent
            text: utilBtn.iconText
            color: (utilBtn.activeState || utilMouse.containsMouse) ? theme.mainFg : theme.secondaryFg
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
        }

        MouseArea {
            id: utilMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    utilBtn.rightTriggered();
                } else {
                    utilBtn.triggered();
                }
            }
        }
    }

    // 4. DesktopClockCanvas: 5x7 Rounded-Square LED Dot-Matrix Clock Renderer (exact match to image-9.png)
    component DesktopClockCanvas: Canvas {
        id: ledCanvas
        property string digits: shellRoot.clockUse12Hour ? shellRoot.clock12HourDigits : shellRoot.clock24HourDigits
        property string amPm: shellRoot.clockAmPm
        property bool showAmPm: shellRoot.clockUse12Hour
        property color ledColor: shellRoot.clockLedColor
        property real glowAmount: shellRoot.clockGlowIntensity
        property real scaleFactor: shellRoot.clockScale
        property int tick: shellRoot.clockPaintTick

        anchors.fill: parent
        antialiasing: true
        smooth: true

        onDigitsChanged: requestPaint()
        onAmPmChanged: requestPaint()
        onShowAmPmChanged: requestPaint()
        onLedColorChanged: requestPaint()
        onGlowAmountChanged: requestPaint()
        onScaleFactorChanged: requestPaint()
        onTickChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        // 5x7 dot-matrix patterns matching image-9.png (including '0' with internal diagonal slash, '1', '5', 'P', 'M', 'A')
        function getMatrixPattern(ch) {
            if (ch === "0") return ["01110", "10001", "10011", "10101", "11001", "10001", "01110"];
            if (ch === "1") return ["00100", "01100", "00100", "00100", "00100", "00100", "01110"];
            if (ch === "2") return ["01110", "10001", "00001", "00010", "00100", "01000", "11111"];
            if (ch === "3") return ["11111", "00010", "00100", "00010", "00001", "10001", "01110"];
            if (ch === "4") return ["00010", "00110", "01010", "10010", "11111", "00010", "00010"];
            if (ch === "5") return ["11111", "10000", "11110", "00001", "00001", "10001", "01110"];
            if (ch === "6") return ["00110", "01000", "10000", "11110", "10001", "10001", "01110"];
            if (ch === "7") return ["11111", "00001", "00010", "00100", "01000", "01000", "01000"];
            if (ch === "8") return ["01110", "10001", "10001", "01110", "10001", "10001", "01110"];
            if (ch === "9") return ["01110", "10001", "10001", "01111", "00001", "00010", "01100"];
            if (ch === "P") return ["11110", "10001", "10001", "11110", "10000", "10000", "10000"];
            if (ch === "A") return ["01110", "10001", "10001", "11111", "10001", "10001", "10001"];
            if (ch === "M") return ["10001", "11011", "10101", "10101", "10001", "10001", "10001"];
            if (ch === "H") return ["10001", "10001", "10001", "11111", "10001", "10001", "10001"];
            return ["00000", "00000", "00000", "00000", "00000", "00000", "00000"];
        }

        function fillRoundedRect(ctx, rx, ry, rw, rh, rad) {
            var r = Math.min(rad, rw / 2, rh / 2);
            ctx.beginPath();
            ctx.moveTo(rx + r, ry);
            ctx.lineTo(rx + rw - r, ry);
            ctx.arc(rx + rw - r, ry + r, r, -Math.PI / 2, 0, false);
            ctx.lineTo(rx + rw, ry + rh - r);
            ctx.arc(rx + rw - r, ry + rh - r, r, 0, Math.PI / 2, false);
            ctx.lineTo(rx + r, ry + rh);
            ctx.arc(rx + r, ry + rh - r, r, Math.PI / 2, Math.PI, false);
            ctx.lineTo(rx, ry + r);
            ctx.arc(rx + r, ry + r, r, Math.PI, -Math.PI / 2, false);
            ctx.closePath();
            ctx.fill();
        }

        function drawMatrixGlyph(ctx, ch, originX, originY, cellSz, gapSz, cellRad, unlitRgba, litCss, coreCss, glowAlpha) {
            var rows = getMatrixPattern(ch);
            var pitch = cellSz + gapSz;
            var r = 0;
            var c = 0;

            // Pass 1: Unlit 5x7 background grid cells
            ctx.fillStyle = unlitRgba;
            for (r = 0; r < 7; r++) {
                var rowStr = rows[r];
                for (c = 0; c < 5; c++) {
                    if (rowStr.charAt(c) !== "1") {
                        fillRoundedRect(ctx, originX + c * pitch, originY + r * pitch, cellSz, cellSz, cellRad);
                    }
                }
            }

            // Pass 2: Soft Radial LED Bloom around every lit cell
            if (glowAlpha > 0.01) {
                var bloomR = cellSz * 1.85;
                for (r = 0; r < 7; r++) {
                    var bRow = rows[r];
                    for (c = 0; c < 5; c++) {
                        if (bRow.charAt(c) === "1") {
                            var cx = originX + c * pitch + cellSz * 0.5;
                            var cy = originY + r * pitch + cellSz * 0.5;
                            var bg = ctx.createRadialGradient(cx, cy, cellSz * 0.1, cx, cy, bloomR);
                            bg.addColorStop(0.0, shellRoot.cssRgba(ledCanvas.ledColor, 0.42 * glowAlpha));
                            bg.addColorStop(0.45, shellRoot.cssRgba(ledCanvas.ledColor, 0.14 * glowAlpha));
                            bg.addColorStop(1.0, "rgba(0,0,0,0)");
                            ctx.fillStyle = bg;
                            ctx.fillRect(cx - bloomR, cy - bloomR, bloomR * 2, bloomR * 2);
                        }
                    }
                }
            }

            // Pass 3: Crisp Lit Rounded-Square LED Cells + White-Hot Diode Core
            for (r = 0; r < 7; r++) {
                var lRow = rows[r];
                for (c = 0; c < 5; c++) {
                    if (lRow.charAt(c) === "1") {
                        var lx = originX + c * pitch;
                        var ly = originY + r * pitch;
                        ctx.fillStyle = litCss;
                        fillRoundedRect(ctx, lx, ly, cellSz, cellSz, cellRad);
                        ctx.fillStyle = coreCss;
                        fillRoundedRect(ctx, lx + cellSz * 0.14, ly + cellSz * 0.14, cellSz * 0.72, cellSz * 0.72, cellRad * 0.72);
                    }
                }
            }
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (width <= 10 || height <= 10) return;

            var s = ledCanvas.scaleFactor;
            var padX = 32 * s;
            var topAmPmY = 22 * s;
            var digitsY = 64 * s;

            var unlitColor = "rgba(255, 255, 255, 0.075)";
            var litColorCss = shellRoot.cssRgba(ledCanvas.ledColor, 0.96);
            var coreColorCss = "rgba(255, 255, 255, 0.58)";

            // 1. Top-Left AM / PM (or 24H) 5x7 Mini Dot-Matrix Indicator (exact match to PM in image-9.png)
            var miniCell = 3.2 * s;
            var miniGap = 1.2 * s;
            var miniRad = 0.85 * s;
            var miniLetterWidth = 5 * (miniCell + miniGap) - miniGap;
            var badgeText = ledCanvas.showAmPm ? ledCanvas.amPm : "24H";
            for (var bi = 0; bi < badgeText.length; bi++) {
                var bx = padX + bi * (miniLetterWidth + 5.5 * s);
                drawMatrixGlyph(
                    ctx,
                    badgeText.charAt(bi),
                    bx,
                    topAmPmY,
                    miniCell,
                    miniGap,
                    miniRad,
                    unlitColor,
                    litColorCss,
                    coreColorCss,
                    ledCanvas.glowAmount
                );
            }

            // 2. Main 4 Digits (H1, H2, M1, M2) in 5x7 Rounded-Square Dot Matrix
            var cellSz = 11.0 * s;
            var gapSz = 3.2 * s;
            var cellRad = 2.8 * s;
            var pitch = cellSz + gapSz;
            var digitW = 5 * pitch - gapSz; // 67.8 * s
            var pairGap = 16.0 * s;

            var dStr = (ledCanvas.digits && ledCanvas.digits.length >= 4) ? ledCanvas.digits : "0151";
            var x0 = padX;
            var x1 = x0 + digitW + pairGap;
            var x3 = width - padX - digitW;
            var x2 = x3 - pairGap - digitW;

            drawMatrixGlyph(ctx, dStr.charAt(0), x0, digitsY, cellSz, gapSz, cellRad, unlitColor, litColorCss, coreColorCss, ledCanvas.glowAmount);
            drawMatrixGlyph(ctx, dStr.charAt(1), x1, digitsY, cellSz, gapSz, cellRad, unlitColor, litColorCss, coreColorCss, ledCanvas.glowAmount);
            drawMatrixGlyph(ctx, dStr.charAt(2), x2, digitsY, cellSz, gapSz, cellRad, unlitColor, litColorCss, coreColorCss, ledCanvas.glowAmount);
            drawMatrixGlyph(ctx, dStr.charAt(3), x3, digitsY, cellSz, gapSz, cellRad, unlitColor, litColorCss, coreColorCss, ledCanvas.glowAmount);

            // 3. Center Colon (Two glowing rounded-square dots at Row 1.25 and Row 4.75, no unlit grid around them — matching image-9.png)
            var colonX = (x1 + digitW + x2 - cellSz) * 0.5;
            var colonY1 = digitsY + 1.25 * pitch;
            var colonY2 = digitsY + 4.75 * pitch;
            var colonBloomR = cellSz * 2.0;

            if (ledCanvas.glowAmount > 0.01) {
                var c1x = colonX + cellSz * 0.5;
                var c1y = colonY1 + cellSz * 0.5;
                var g1 = ctx.createRadialGradient(c1x, c1y, cellSz * 0.1, c1x, c1y, colonBloomR);
                g1.addColorStop(0.0, shellRoot.cssRgba(ledCanvas.ledColor, 0.48 * ledCanvas.glowAmount));
                g1.addColorStop(0.45, shellRoot.cssRgba(ledCanvas.ledColor, 0.16 * ledCanvas.glowAmount));
                g1.addColorStop(1.0, "rgba(0,0,0,0)");
                ctx.fillStyle = g1;
                ctx.fillRect(c1x - colonBloomR, c1y - colonBloomR, colonBloomR * 2, colonBloomR * 2);

                var c2x = colonX + cellSz * 0.5;
                var c2y = colonY2 + cellSz * 0.5;
                var g2 = ctx.createRadialGradient(c2x, c2y, cellSz * 0.1, c2x, c2y, colonBloomR);
                g2.addColorStop(0.0, shellRoot.cssRgba(ledCanvas.ledColor, 0.48 * ledCanvas.glowAmount));
                g2.addColorStop(0.45, shellRoot.cssRgba(ledCanvas.ledColor, 0.16 * ledCanvas.glowAmount));
                g2.addColorStop(1.0, "rgba(0,0,0,0)");
                ctx.fillStyle = g2;
                ctx.fillRect(c2x - colonBloomR, c2y - colonBloomR, colonBloomR * 2, colonBloomR * 2);
            }

            ctx.fillStyle = litColorCss;
            fillRoundedRect(ctx, colonX, colonY1, cellSz, cellSz, cellRad);
            fillRoundedRect(ctx, colonX, colonY2, cellSz, cellSz, cellRad);
            ctx.fillStyle = coreColorCss;
            fillRoundedRect(ctx, colonX + cellSz * 0.14, colonY1 + cellSz * 0.14, cellSz * 0.72, cellSz * 0.72, cellRad * 0.72);
            fillRoundedRect(ctx, colonX + cellSz * 0.14, colonY2 + cellSz * 0.14, cellSz * 0.72, cellSz * 0.72, cellRad * 0.72);
        }
    }

    // ── SINGLE TOP BAR WITH CONCAVE ROUNDED CORNERS + FROSTED SEA-GLASS STADIUM CAPSULES (image-8.png style) ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData

            readonly property int barHeight: 44
            readonly property int cornerSize: theme.cornerRadius
            readonly property int activeWsId: (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace)
                ? Hyprland.focusedMonitor.activeWorkspace.id
                : 1
            readonly property int activeWsIndex: Math.max(0, Math.min(9, ((activeWsId - 1) % 10)))
            readonly property int bankOffset: activeWsIndex >= 5 ? 5 : 0
            readonly property int localOrbIndex: activeWsIndex - bankOffset

            anchors {
                top: true
                left: true
                right: true
            }
            margins {
                top: 0
                left: 0
                right: 0
            }

            exclusiveZone: barHeight
            implicitHeight: barHeight + cornerSize
            color: "transparent"

            mask: Region {
                item: barContent
            }

            // Main Top Bar Backdrop seamlessly connecting into Top-Left & Top-Right Concave RoundCorners
            Rectangle {
                id: barContent
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: barWindow.barHeight
                color: Qt.alpha(theme.barBg, theme.barOpacity)

                Behavior on color {
                    ColorAnimation { duration: 300 }
                }

                // ── 1. TOP-LEFT FROSTED SEA-GLASS STADIUM CAPSULE (`leftCenterGroup`) ──
                MouseArea {
                    id: leftSideArea
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        left: parent.left
                        right: middleCenterGroup.left
                    }
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onWheel: event => {
                        if (event.angleDelta.y > 0) {
                            shellRoot.runCmd(["brightnessctl", "set", "+5%"]);
                        } else if (event.angleDelta.y < 0) {
                            shellRoot.runCmd(["brightnessctl", "set", "5%-"]);
                        }
                        statusProc.running = true;
                    }

                    BarGroup {
                        id: leftCenterGroup
                        anchors {
                            left: parent.left
                            leftMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        padding: 4
                        implicitWidth: leftPillRow.implicitWidth + 14

                        RowLayout {
                            id: leftPillRow
                            anchors {
                                left: parent.left
                                leftMargin: 4
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 11

                            // Leftmost Active-Style Soft Frosted Inner Pill (matches the Home pill on the left of image-8.png!)
                            Rectangle {
                                id: leftSidebarBtn
                                implicitWidth: 44
                                implicitHeight: 28
                                radius: 14
                                color: leftBtnMouse.containsMouse
                                    ? Qt.rgba(0.86, 0.94, 0.98, 0.26)
                                    : Qt.rgba(0.84, 0.93, 0.96, 0.18)
                                border.width: 1
                                border.color: Qt.rgba(0.92, 0.97, 1.0, 0.12)

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰋜"
                                    color: theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 15
                                }

                                MouseArea {
                                    id: leftBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
                                            shellRoot.runCmd(["hyde-shell", "rofi.movie"]);
                                        } else {
                                            shellRoot.runCmd(["hyde-shell", "rofilaunch", "d"]);
                                        }
                                    }
                                }
                            }

                            // Clean Frosted Silver-Ice Resource Indicators sitting directly on the glass (NO nested boxes!)
                            RowLayout {
                                id: resRow
                                spacing: 10

                                RowLayout {
                                    spacing: 4
                                    CircularResourceRing {
                                        value: shellRoot.memoryUsage
                                        iconText: "󰍛"
                                        primaryColor: shellRoot.memoryUsage >= 0.90 ? theme.errorColor : theme.secondaryFg
                                    }
                                    Text {
                                        text: Math.round(shellRoot.memoryUsage * 100).toString() + "%"
                                        color: theme.secondaryFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                    }
                                }

                                RowLayout {
                                    spacing: 4
                                    CircularResourceRing {
                                        value: shellRoot.swapUsage
                                        iconText: "󰓡"
                                        primaryColor: shellRoot.swapUsage >= 0.90 ? theme.errorColor : theme.secondaryFg
                                    }
                                    Text {
                                        text: Math.round(shellRoot.swapUsage * 100).toString() + "%"
                                        color: theme.secondaryFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                    }
                                }

                                RowLayout {
                                    spacing: 4
                                    CircularResourceRing {
                                        value: shellRoot.cpuUsage
                                        iconText: "󰻠"
                                        primaryColor: shellRoot.cpuUsage >= 0.90 ? theme.errorColor : theme.secondaryFg
                                    }
                                    Text {
                                        text: Math.round(shellRoot.cpuUsage * 100).toString() + "%"
                                        color: theme.secondaryFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                    }
                                }
                            }

                            // Delicate 1px glass separator
                            Rectangle {
                                implicitWidth: 1
                                implicitHeight: 14
                                color: Qt.rgba(0.82, 0.92, 0.96, 0.14)
                            }

                            // Media / AniSub sitting directly on the glass capsule
                            Rectangle {
                                id: mediaSlot
                                readonly property var activePlayer: (Mpris.players && Mpris.players.values && Mpris.players.values.length > 0)
                                    ? Mpris.players.values[0]
                                    : null
                                readonly property bool hasTrack: activePlayer !== null && activePlayer.trackTitle !== ""
                                implicitWidth: mediaRow.implicitWidth + 14
                                implicitHeight: 28
                                radius: 14
                                color: mediaMouse.containsMouse
                                    ? Qt.rgba(0.84, 0.93, 0.96, 0.16)
                                    : "transparent"

                                RowLayout {
                                    id: mediaRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: (mediaSlot.hasTrack && mediaSlot.activePlayer.isPlaying) ? "" : "󰎈"
                                        color: mediaMouse.containsMouse ? theme.mainFg : theme.secondaryFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        Layout.maximumWidth: 96
                                        elide: Text.ElideRight
                                        text: mediaSlot.hasTrack
                                            ? mediaSlot.activePlayer.trackTitle
                                            : "AniSub"
                                        color: mediaMouse.containsMouse ? theme.mainFg : theme.secondaryFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                    }
                                }

                                MouseArea {
                                    id: mediaMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        if (!mediaSlot.hasTrack || mouse.button === Qt.LeftButton) {
                                            shellRoot.runCmd(["hyde-shell", "rofi.movie"]);
                                        } else if (mouse.button === Qt.MiddleButton && mediaSlot.activePlayer) {
                                            mediaSlot.activePlayer.togglePlaying();
                                        } else if (mouse.button === Qt.RightButton && mediaSlot.activePlayer) {
                                            mediaSlot.activePlayer.next();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 2. TOP-CENTER FROSTED SEA-GLASS STADIUM PILL (`middleCenterGroup` — 1:1 visual match to image-8.png) ──
                BarGroup {
                    id: middleCenterGroup
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                    }
                    padding: 4
                    implicitWidth: wsContainer.implicitWidth + 8

                    Item {
                        id: wsContainer
                        anchors.centerIn: parent
                        readonly property real pillWidth: 48
                        readonly property real pillHeight: 28
                        readonly property real pillPitch: 54
                        readonly property int targetIndex: barWindow.localOrbIndex

                        property real idx1: targetIndex
                        property real idx2: targetIndex
                        Behavior on idx1 {
                            NumberAnimation { duration: 110; easing.type: Easing.OutSine }
                        }
                        Behavior on idx2 {
                            NumberAnimation { duration: 280; easing.type: Easing.OutSine }
                        }

                        function isWsOccupied(id) {
                            if (shellRoot.wsClasses && shellRoot.wsClasses[id.toString()]) return true;
                            var list = Hyprland.workspaces ? Hyprland.workspaces.values : [];
                            for (var i = 0; i < list.length; i++) {
                                if (list[i].id === id) return true;
                            }
                            return false;
                        }

                        implicitWidth: pillPitch * 5 - (pillPitch - pillWidth)
                        implicitHeight: pillHeight

                        // Layer 1: Soft Frosted Inner Active Pill (`activeIndicator` — matches the soft frosted pill on the left of image-8.png)
                        Rectangle {
                            id: activeIndicator
                            z: 1
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.min(wsContainer.idx1, wsContainer.idx2) * wsContainer.pillPitch
                            width: Math.abs(wsContainer.idx1 - wsContainer.idx2) * wsContainer.pillPitch + wsContainer.pillWidth
                            height: wsContainer.pillHeight
                            radius: wsContainer.pillHeight / 2
                            color: Qt.rgba(0.84, 0.93, 0.96, 0.18)
                            border.width: 1
                            border.color: Qt.rgba(0.92, 0.97, 1.0, 0.12)
                        }

                        // Layer 2: 5 Workspace Slots sitting directly on the Frosted Sea-Glass Capsule (Home, Check-circle, Calendar, Target, Terminal)
                        Repeater {
                            model: 5

                            Item {
                                id: wsSlot
                                z: 2
                                required property int index
                                readonly property int wsId: barWindow.bankOffset + index + 1
                                readonly property bool isActive: (barWindow.localOrbIndex === index)
                                readonly property bool isOcc: wsContainer.isWsOccupied(wsId)

                                x: index * wsContainer.pillPitch
                                width: wsContainer.pillWidth
                                height: wsContainer.pillHeight

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    visible: wsHit.containsMouse && !wsSlot.isActive
                                    color: Qt.rgba(0.84, 0.93, 0.96, 0.09)
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: shellRoot.iconForWorkspaceSlot(wsSlot.index)
                                    color: wsSlot.isActive ? theme.mainFg : theme.secondaryFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: wsSlot.isActive ? 15 : 14

                                    Behavior on color {
                                        ColorAnimation { duration: 180 }
                                    }
                                }

                                Rectangle {
                                    visible: wsSlot.isOcc && !wsSlot.isActive
                                    anchors {
                                        bottom: parent.bottom
                                        bottomMargin: 2.5
                                        horizontalCenter: parent.horizontalCenter
                                    }
                                    width: 3.5
                                    height: 3.5
                                    radius: 1.75
                                    color: Qt.alpha(theme.secondaryFg, 0.72)
                                }

                                MouseArea {
                                    id: wsHit
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Hyprland.dispatch("workspace " + wsSlot.wsId)
                                    onWheel: event => {
                                        if (event.angleDelta.y < 0) {
                                            Hyprland.dispatch("workspace r+1");
                                        } else if (event.angleDelta.y > 0) {
                                            Hyprland.dispatch("workspace r-1");
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 3. TOP-RIGHT FROSTED SEA-GLASS STADIUM CAPSULE (`rightCenterGroup`) ──
                MouseArea {
                    id: rightSideArea
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        left: middleCenterGroup.right
                        right: parent.right
                    }
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onWheel: event => {
                        if (event.angleDelta.y > 0) {
                            shellRoot.runCmd(["pamixer", "-i", "5"]);
                        } else if (event.angleDelta.y < 0) {
                            shellRoot.runCmd(["pamixer", "-d", "5"]);
                        }
                        statusProc.running = true;
                    }

                    BarGroup {
                        id: rightCenterGroup
                        anchors {
                            right: parent.right
                            rightMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        padding: 4
                        implicitWidth: rightDockRow.implicitWidth + 14

                        RowLayout {
                            id: rightDockRow
                            anchors {
                                right: parent.right
                                rightMargin: 4
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 9

                            // Coffee / Caffeine Toggle Button (`󰅶` when active, `󰛊` when inactive)
                            CircleUtilButton {
                                id: caffeineBtn
                                iconText: shellRoot.caffeineActive ? "󰅶" : "󰛊"
                                activeState: shellRoot.caffeineActive
                                onTriggered: {
                                    shellRoot.caffeineActive = !shellRoot.caffeineActive;
                                    shellRoot.runCmd(["hyde-shell", "caffeine", "-t"]);
                                }
                                onRightTriggered: {
                                    shellRoot.caffeineActive = !shellRoot.caffeineActive;
                                    shellRoot.runCmd(["hyde-shell", "caffeine", "-t"]);
                                }
                            }

                            // Screenshot utility button (left-click: region snip `s`, right-click: full screen `p`)
                            CircleUtilButton {
                                iconText: "󰆞"
                                onTriggered: shellRoot.runCmd(["hyde-shell", "screenshot", "s"])
                                onRightTriggered: shellRoot.runCmd(["hyde-shell", "screenshot", "p"])
                            }

                            // Color Picker utility button
                            CircleUtilButton {
                                iconText: "󰈊"
                                onTriggered: shellRoot.runCmd(["hyprpicker", "-a"])
                                onRightTriggered: shellRoot.runCmd(["hyprpicker", "-a"])
                            }

                            // System Tray icons
                            RowLayout {
                                visible: SystemTray.items && SystemTray.items.values && SystemTray.items.values.length > 0
                                spacing: 4

                                Repeater {
                                    model: SystemTray.items

                                    Rectangle {
                                        id: traySlot
                                        required property var modelData
                                        implicitWidth: 24
                                        implicitHeight: 24
                                        radius: 12
                                        color: trayMouse.containsMouse
                                            ? Qt.rgba(0.84, 0.93, 0.96, 0.16)
                                            : "transparent"

                                        Image {
                                            anchors.centerIn: parent
                                            width: 14
                                            height: 14
                                            source: traySlot.modelData.icon || ""
                                            sourceSize.width: 14
                                            sourceSize.height: 14
                                        }

                                        MouseArea {
                                            id: trayMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: mouse => {
                                                if (mouse.button === Qt.RightButton) {
                                                    traySlot.modelData.secondaryActivate();
                                                } else {
                                                    traySlot.modelData.activate();
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Bluetooth icon
                            Text {
                                text: shellRoot.bluetoothConnected
                                    ? "󰂱"
                                    : (shellRoot.bluetoothOn ? "󰂯" : "󰂲")
                                color: theme.secondaryFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: shellRoot.runCmd(["blueman-manager"])
                                }
                            }

                            // Wi-Fi icon
                            Text {
                                text: shellRoot.networkName !== "" ? "󰤨" : "󰤭"
                                color: theme.secondaryFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: shellRoot.runCmd(["nm-connection-editor"])
                                }
                            }

                            // Microphone icon
                            Text {
                                text: shellRoot.micMuted ? "󰍭" : "󰍬"
                                color: theme.secondaryFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        shellRoot.runCmd(["pamixer", "--default-source", "-t"]);
                                        statusProc.running = true;
                                    }
                                }
                            }

                            // Volume icon + sleek frosted glass slider bar
                            RowLayout {
                                spacing: 5

                                Text {
                                    text: shellRoot.volumeMuted
                                        ? "󰝟"
                                        : (shellRoot.volumeLevel < 35 ? "󰕿" : (shellRoot.volumeLevel < 70 ? "󰖀" : "󰕾"))
                                    color: theme.secondaryFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14

                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.RightButton) {
                                                shellRoot.runCmd(["pavucontrol"]);
                                            } else {
                                                shellRoot.runCmd(["pamixer", "-t"]);
                                                statusProc.running = true;
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    implicitWidth: 34
                                    implicitHeight: 4
                                    radius: 2
                                    color: Qt.rgba(0.82, 0.92, 0.96, 0.18)
                                    clip: true

                                    Rectangle {
                                        width: shellRoot.volumeMuted
                                            ? 0
                                            : Math.max(4, parent.width * Math.max(0.0, Math.min(1.0, shellRoot.volumeLevel / 100.0)))
                                        height: parent.height
                                        radius: 2
                                        color: theme.mainFg
                                    }
                                }
                            }

                            // Clean Frosted Battery Indicator
                            RowLayout {
                                spacing: 3

                                Text {
                                    text: shellRoot.batteryCharging ? "󰂄" : "󰁹"
                                    color: (shellRoot.batteryLevel <= 0.20 && !shellRoot.batteryCharging)
                                        ? theme.errorColor
                                        : theme.secondaryFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }

                                Text {
                                    text: Math.round(Math.max(0, shellRoot.batteryLevel * 100)).toString() + "%"
                                    color: theme.secondaryFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                }
                            }

                            // Rightmost Active-Style Soft Frosted Inner Pill: Clock, Date & Settings (middle-click toggles Desktop Clock Widget!)
                            Rectangle {
                                id: rightClockPill
                                implicitWidth: clockPillRow.implicitWidth + 20
                                implicitHeight: 28
                                radius: 14
                                color: rightClockMouse.containsMouse
                                    ? Qt.rgba(0.86, 0.94, 0.98, 0.26)
                                    : Qt.rgba(0.84, 0.93, 0.96, 0.18)
                                border.width: 1
                                border.color: Qt.rgba(0.92, 0.97, 1.0, 0.12)

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                RowLayout {
                                    id: clockPillRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: shellRoot.timeText
                                        color: theme.mainFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                    }

                                    Text {
                                        text: "•"
                                        color: theme.secondaryFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                    }

                                    Text {
                                        text: shellRoot.dateText
                                        color: theme.secondaryFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                    }

                                    Text {
                                        text: "󰒓"
                                        color: theme.mainFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                    }
                                }

                                MouseArea {
                                    id: rightClockMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.MiddleButton) {
                                            shellRoot.clockWidgetVisible = !shellRoot.clockWidgetVisible;
                                            shellRoot.saveClockConfig();
                                        } else if (mouse.button === Qt.RightButton) {
                                            shellRoot.runCmd(["hyde-shell", "logoutlaunch", "1"]);
                                        } else {
                                            shellRoot.runCmd(["hyde-shell", "anide-settings"]);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Top-Left & Top-Right Concave Rounded Bar Corners ("bo góc lõm thanh bar") ──
            RoundCorner {
                anchors {
                    top: barContent.bottom
                    left: parent.left
                }
                corner: "top-left"
                cornerSize: barWindow.cornerSize
                fillColor: theme.barBg
                fillAlpha: theme.barOpacity
            }

            RoundCorner {
                anchors {
                    top: barContent.bottom
                    right: parent.right
                }
                corner: "top-right"
                cornerSize: barWindow.cornerSize
                fillColor: theme.barBg
                fillAlpha: theme.barOpacity
            }
        }
    }

    // ── BOTTOM CONCAVE SCREEN CORNERS ONLY (NO bottom bar! exclusiveZone: 0, click-through mask) ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bottomCornerWindow
            required property var modelData
            screen: modelData

            readonly property int cornerSize: theme.cornerRadius

            anchors {
                bottom: true
                left: true
                right: true
            }
            margins {
                bottom: 0
                left: 0
                right: 0
            }

            exclusiveZone: 0
            implicitHeight: cornerSize
            color: "transparent"

            mask: Region {}

            RoundCorner {
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                }
                corner: "bottom-left"
                cornerSize: bottomCornerWindow.cornerSize
                fillColor: theme.barBg
                fillAlpha: theme.barOpacity
            }

            RoundCorner {
                anchors {
                    bottom: parent.bottom
                    right: parent.right
                }
                corner: "bottom-right"
                cornerSize: bottomCornerWindow.cornerSize
                fillColor: theme.barBg
                fillAlpha: theme.barOpacity
            }
        }
    }

    // ── DRAGGABLE DESKTOP WALLPAPER LED DOT-MATRIX CLOCK WIDGET (image-9.png style) ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: desktopClockWindow
            required property var modelData
            screen: modelData
            visible: shellRoot.clockWidgetVisible

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusiveZone: 0
            aboveWindows: false
            color: "transparent"

            // Input region: only the clock card is clickable when idle; expands while dragging or when the color customizer is open
            mask: Region {
                item: clockWidgetHitBox
            }

            Item {
                id: desktopSurface
                anchors.fill: parent

                // Dynamic input mask target
                Item {
                    id: clockWidgetHitBox
                    x: (clockDragArea.pressed || shellRoot.clockCustomizerOpen) ? 0 : clockCard.x
                    y: (clockDragArea.pressed || shellRoot.clockCustomizerOpen) ? 0 : clockCard.y
                    width: (clockDragArea.pressed || shellRoot.clockCustomizerOpen) ? parent.width : clockCard.width
                    height: (clockDragArea.pressed || shellRoot.clockCustomizerOpen) ? parent.height : clockCard.height
                }

                // Backdrop click-catcher to close the color customizer when clicking outside the widget
                MouseArea {
                    anchors.fill: parent
                    enabled: shellRoot.clockCustomizerOpen
                    visible: shellRoot.clockCustomizerOpen
                    onClicked: {
                        shellRoot.clockCustomizerOpen = false;
                    }
                }

                // ── Main Draggable LED Dot-Matrix Clock Card (exact match to image-9.png) ──
                Rectangle {
                    id: clockCard
                    x: shellRoot.clockWidgetX
                    y: shellRoot.clockWidgetY
                    width: Math.round(396 * shellRoot.clockScale)
                    height: Math.round(196 * shellRoot.clockScale)
                    radius: Math.round(16 * shellRoot.clockScale)
                    color: Qt.alpha(shellRoot.clockBgColor, shellRoot.clockBgOpacity)
                    border.width: clockDragArea.pressed ? 1.5 : (shellRoot.clockBgOpacity > 0.05 ? 1 : 0)
                    border.color: clockDragArea.pressed
                        ? Qt.alpha(shellRoot.clockLedColor, 0.65)
                        : Qt.rgba(1, 1, 1, 0.11)

                    // Sync external coordinate updates when not actively dragging
                    Connections {
                        target: shellRoot
                        function onClockWidgetXChanged() {
                            if (!clockDragArea.pressed) clockCard.x = shellRoot.clockWidgetX;
                        }
                        function onClockWidgetYChanged() {
                            if (!clockDragArea.pressed) clockCard.y = shellRoot.clockWidgetY;
                        }
                    }

                    // 5x7 Rounded-Square LED Dot-Matrix Renderer (`PM` + `01 : 51`)
                    DesktopClockCanvas {
                        id: matrixCanvas
                        anchors.fill: parent
                    }

                    // Drag & Right-Click Customizer MouseArea
                    MouseArea {
                        id: clockDragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: clockCard
                        drag.axis: Drag.XAndYAxis
                        drag.minimumX: 12
                        drag.maximumX: Math.max(12, desktopSurface.width - clockCard.width - 12)
                        drag.minimumY: 52
                        drag.maximumY: Math.max(52, desktopSurface.height - clockCard.height - 12)

                        onReleased: {
                            shellRoot.clockWidgetX = Math.round(clockCard.x);
                            shellRoot.clockWidgetY = Math.round(clockCard.y);
                            shellRoot.saveClockConfig();
                        }

                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                shellRoot.clockCustomizerOpen = !shellRoot.clockCustomizerOpen;
                            }
                        }
                    }

                    // Floating Color Palette Button (`󰏘`) in top-right corner of the widget (appears on hover or when customizer is open)
                    Rectangle {
                        id: paletteTriggerBtn
                        anchors {
                            top: parent.top
                            right: parent.right
                            topMargin: Math.round(10 * shellRoot.clockScale)
                            rightMargin: Math.round(12 * shellRoot.clockScale)
                        }
                        width: 26
                        height: 26
                        radius: 13
                        opacity: (clockDragArea.containsMouse || paletteTriggerMouse.containsMouse || shellRoot.clockCustomizerOpen) ? 1.0 : 0.0
                        color: (paletteTriggerMouse.containsMouse || shellRoot.clockCustomizerOpen)
                            ? Qt.rgba(1, 1, 1, 0.22)
                            : Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.22)

                        Behavior on opacity {
                            NumberAnimation { duration: 160 }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰏘"
                            color: "#ffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: paletteTriggerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                shellRoot.clockCustomizerOpen = !shellRoot.clockCustomizerOpen;
                            }
                        }
                    }
                }

                // ── Interactive Widget Color & Style Customizer Popover ──
                Rectangle {
                    id: clockCustomizerPopup
                    visible: shellRoot.clockCustomizerOpen
                    z: 10
                    width: 340
                    height: customizerCol.implicitHeight + 24
                    x: Math.max(12, Math.min(desktopSurface.width - width - 12, clockCard.x + (clockCard.width - width) * 0.5))
                    y: (clockCard.y + clockCard.height + height + 16 <= desktopSurface.height)
                        ? (clockCard.y + clockCard.height + 10)
                        : Math.max(52, clockCard.y - height - 10)
                    radius: 16
                    color: Qt.rgba(0.05, 0.07, 0.09, 0.95)
                    border.width: 1
                    border.color: Qt.rgba(0.75, 0.90, 0.96, 0.28)

                    // Prevent clicks inside the popover from closing it
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                    }

                    ColumnLayout {
                        id: customizerCol
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 12
                        }
                        spacing: 10

                        // Header Row
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "󰏘  Clock Widget Color & Style"
                                color: "#f4f9fc"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                implicitWidth: 22
                                implicitHeight: 22
                                radius: 11
                                color: closePopupMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: "#a9c1ca"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                }

                                MouseArea {
                                    id: closePopupMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: shellRoot.clockCustomizerOpen = false
                                }
                            }
                        }

                        // Section 1: 12 LED Color Swatches
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: [
                                    "#ffffff", // Pure White (image-9.png default)
                                    "#67e8f9", // Ice Cyan
                                    "#2dd4bf", // Neon Teal
                                    "#4ade80", // Matrix Green
                                    "#a3e635", // Volt Lime
                                    "#fbbf24", // Amber Nixie
                                    "#fb923c", // Sunset Orange
                                    "#f87171", // Crimson Red
                                    "#fb7185", // Rose Coral
                                    "#f472b6", // Sakura Pink
                                    "#c084fc", // Cyber Violet
                                    "#60a5fa"  // Electric Blue
                                ]

                                Rectangle {
                                    id: swatchDot
                                    required property string modelData
                                    readonly property bool isSelected: !shellRoot.clockSyncWallpaper
                                        && (shellRoot.colorToHex(shellRoot.clockLedColor).toLowerCase() === modelData.toLowerCase())
                                    width: 21
                                    height: 21
                                    radius: 10.5
                                    color: modelData
                                    border.width: isSelected ? 2.2 : 1
                                    border.color: isSelected ? "#ffffff" : Qt.rgba(0, 0, 0, 0.45)
                                    scale: (swatchMouse.containsMouse || isSelected) ? 1.14 : 1.0

                                    Behavior on scale {
                                        NumberAnimation { duration: 120 }
                                    }

                                    MouseArea {
                                        id: swatchMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            shellRoot.clockSyncWallpaper = false;
                                            shellRoot.clockLedColor = Qt.color(swatchDot.modelData);
                                            shellRoot.clockPaintTick += 1;
                                            shellRoot.saveClockConfig();
                                        }
                                    }
                                }
                            }
                        }

                        // Section 2: Continuous 360° Rainbow Hue Slider + Wallpaper Auto Sync Button
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                id: hueBar
                                Layout.fillWidth: true
                                height: 16
                                radius: 8
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.25)

                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.00; color: "#ff3b30" }
                                    GradientStop { position: 0.17; color: "#ffcc00" }
                                    GradientStop { position: 0.33; color: "#34c759" }
                                    GradientStop { position: 0.50; color: "#00e5ff" }
                                    GradientStop { position: 0.67; color: "#007aff" }
                                    GradientStop { position: 0.83; color: "#af52de" }
                                    GradientStop { position: 1.00; color: "#ff2d55" }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    function pickHue(mx) {
                                        var h = Math.max(0.0, Math.min(1.0, mx / Math.max(1, hueBar.width)));
                                        shellRoot.clockSyncWallpaper = false;
                                        shellRoot.clockLedColor = Qt.hsla(h, 0.92, 0.66, 1.0);
                                        shellRoot.clockPaintTick += 1;
                                    }
                                    onPressed: mouse => pickHue(mouse.x)
                                    onPositionChanged: mouse => {
                                        if (pressed) pickHue(mouse.x);
                                    }
                                    onReleased: shellRoot.saveClockConfig()
                                }
                            }

                            // Wallpaper Dynamic Color Sync Button
                            Rectangle {
                                implicitWidth: 68
                                implicitHeight: 22
                                radius: 11
                                color: shellRoot.clockSyncWallpaper
                                    ? Qt.rgba(0.40, 0.90, 0.98, 0.26)
                                    : Qt.rgba(1, 1, 1, 0.10)
                                border.width: 1
                                border.color: shellRoot.clockSyncWallpaper
                                    ? "#67e8f9"
                                    : Qt.rgba(1, 1, 1, 0.16)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰸉 Auto"
                                    color: "#f4f9fc"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        shellRoot.clockSyncWallpaper = !shellRoot.clockSyncWallpaper;
                                        if (shellRoot.clockSyncWallpaper && shellRoot.wallDynamicHex !== "") {
                                            shellRoot.clockLedColor = Qt.color(shellRoot.wallDynamicHex);
                                        }
                                        shellRoot.clockPaintTick += 1;
                                        shellRoot.saveClockConfig();
                                    }
                                }
                            }
                        }

                        // Section 3: Card Background Presets (Obsidian Black, Sea-Glass, Slate, Clear)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "Card:"
                                color: "#a9c1ca"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                            }

                            Repeater {
                                model: [
                                    { label: "Black", bg: "#050507", op: 0.94 },
                                    { label: "Glass", bg: "#0f1c22", op: 0.76 },
                                    { label: "Slate", bg: "#14161e", op: 0.88 },
                                    { label: "Clear", bg: "#050507", op: 0.00 }
                                ]

                                Rectangle {
                                    id: bgPresetBtn
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 24
                                    radius: 12
                                    color: bgPresetMouse.containsMouse
                                        ? Qt.rgba(1, 1, 1, 0.18)
                                        : Qt.rgba(1, 1, 1, 0.09)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.16)

                                    Text {
                                        anchors.centerIn: parent
                                        text: bgPresetBtn.modelData.label
                                        color: "#f4f9fc"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                    }

                                    MouseArea {
                                        id: bgPresetMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            shellRoot.clockBgColor = Qt.color(bgPresetBtn.modelData.bg);
                                            shellRoot.clockBgOpacity = bgPresetBtn.modelData.op;
                                            shellRoot.clockPaintTick += 1;
                                            shellRoot.saveClockConfig();
                                        }
                                    }
                                }
                            }
                        }

                        // Section 4: Format (12H AM/PM vs 24H) + Size (S / M / L)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            // 12H / 24H Toggle
                            Rectangle {
                                implicitWidth: 88
                                implicitHeight: 24
                                radius: 12
                                color: Qt.rgba(0.84, 0.93, 0.96, 0.15)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.18)

                                Text {
                                    anchors.centerIn: parent
                                    text: shellRoot.clockUse12Hour ? "Mode: 12H" : "Mode: 24H"
                                    color: "#f4f9fc"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        shellRoot.clockUse12Hour = !shellRoot.clockUse12Hour;
                                        shellRoot.clockPaintTick += 1;
                                        shellRoot.saveClockConfig();
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "Size:"
                                color: "#a9c1ca"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                            }

                            Repeater {
                                model: [
                                    { label: "S", val: 0.80 },
                                    { label: "M", val: 1.00 },
                                    { label: "L", val: 1.20 }
                                ]

                                Rectangle {
                                    id: scaleBtn
                                    required property var modelData
                                    readonly property bool isSelected: Math.abs(shellRoot.clockScale - modelData.val) < 0.05
                                    implicitWidth: 32
                                    implicitHeight: 24
                                    radius: 12
                                    color: isSelected
                                        ? Qt.rgba(0.84, 0.93, 0.96, 0.24)
                                        : Qt.rgba(1, 1, 1, 0.09)
                                    border.width: 1
                                    border.color: isSelected ? "#ffffff" : Qt.rgba(1, 1, 1, 0.14)

                                    Text {
                                        anchors.centerIn: parent
                                        text: scaleBtn.modelData.label
                                        color: "#f4f9fc"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        font.bold: isSelected
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            shellRoot.clockScale = scaleBtn.modelData.val;
                                            shellRoot.clockPaintTick += 1;
                                            shellRoot.saveClockConfig();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
