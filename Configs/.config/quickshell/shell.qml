// AniDE Quickshell Bar — Single Top Floating Frosted Sea-Glass Pill Bar (image-8.png style)
// Translucent Deep Slate-Teal Glass Capsules | Crisp 1.2px Diagonal Specular Rim | Soft Frosted Inner Active Pill | Clean Silver-Ice Icons
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
    property string activeWinClass: ""
    property string activeWinTitle: ""
    property var wsClasses: ({})     // map of wsId -> window class string
    property string wallStamp: ""
    property string wallBlurUrl: ""
    property int paintGeneration: 0

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

    // Clock, system telemetry & live wallpaper (.dcol) polling
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date();
            shellRoot.timeText = Qt.formatDateTime(now, "HH:mm");
            shellRoot.dateText = Qt.formatDateTime(now, "dd/MM");
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
            "printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\\n' " +
            "\"$vol\" \"$mute\" \"$micm\" \"$br\" \"$cpu\" \"$ram\" \"$swp\" \"$bat\" \"$bstat\" \"$net\" \"$bton\" \"$btcon\" \"$wclass\" \"$wtitle\" \"$wsmap\" \"$wblr\" \"$wstamp\" \"$dcols\""
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
                            // Blend a subtle 14% wallpaper tint into the image-8.png frosted sea-glass palette
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
                            }
                            if (dc[7]) {
                                theme.secondaryFg = theme.subtleTint("#a9c1ca", dc[7], 0.10);
                                theme.glowSecondary = theme.subtleTint("#94c5d6", dc[7], 0.16);
                            }
                            shellRoot.paintGeneration += 1;
                        }
                    }
                }
            }
        }
    }

    // ── Reusable Frosted Sea-Glass Pill Components (image-8.png style) ──

    // 0. DreamyMistCanvas: Renders the exact Frosted Sea-Glass Stadium Pill + 1.2px Diagonal Specular Rim of image-8.png
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

            function stadiumPath(inset) {
                var ri = Math.max(1, r - inset);
                ctx.beginPath();
                ctx.moveTo(inset + ri, inset);
                ctx.lineTo(width - inset - ri, inset);
                ctx.arc(width - inset - ri, height / 2, ri, -Math.PI / 2, Math.PI / 2, false);
                ctx.lineTo(inset + ri, height - inset);
                ctx.arc(inset + ri, height / 2, ri, Math.PI / 2, -Math.PI / 2, false);
                ctx.closePath();
            }

            // 1. Main Translucent Sea-Glass Horizontal-Diagonal Gradient (deep left -> luminous right, matching image-8.png)
            stadiumPath(0.6);
            var bodyGrad = ctx.createLinearGradient(0, height * 0.2, width, height * 0.8);
            bodyGrad.addColorStop(0.0, shellRoot.cssRgba(theme.barBg, Math.min(0.86, baseOpacity + 0.08)));
            bodyGrad.addColorStop(0.46, shellRoot.cssRgba(theme.surfaceBg, baseOpacity));
            bodyGrad.addColorStop(1.0, shellRoot.cssRgba(theme.layer2Bg, Math.max(0.54, baseOpacity - 0.06)));
            ctx.fillStyle = bodyGrad;
            ctx.fill();

            // 2. Right-Side Frosted Sea-Glass Inner Diffusion (matches the soft cyan-frost glow on the right of image-8.png)
            ctx.save();
            stadiumPath(1.0);
            ctx.clip();
            var rightGlow = ctx.createRadialGradient(width * 0.88, height * 0.48, 2, width * 0.85, height * 0.5, width * 0.52);
            rightGlow.addColorStop(0.0, shellRoot.cssRgba(glowPrimary, 0.12));
            rightGlow.addColorStop(0.55, shellRoot.cssRgba(glowAlt, 0.05));
            rightGlow.addColorStop(1.0, "rgba(0,0,0,0)");
            ctx.fillStyle = rightGlow;
            ctx.fillRect(0, 0, width, height);

            // 3. Delicate Top-to-Bottom Frost Veil
            var sheenGrad = ctx.createLinearGradient(0, 0, 0, height);
            sheenGrad.addColorStop(0.0, "rgba(225, 245, 252, 0.09)");
            sheenGrad.addColorStop(0.45, "rgba(185, 222, 236, 0.02)");
            sheenGrad.addColorStop(1.0, "rgba(6, 14, 18, 0.15)");
            ctx.fillStyle = sheenGrad;
            ctx.fillRect(0, 0, width, height);
            ctx.restore();

            // 4. Crisp 1.2px Diagonal Specular Glass Rim (brighter at top-left & bottom-right curves, matching image-8.png)
            stadiumPath(0.75);
            var rimGrad = ctx.createLinearGradient(0, 0, width, height);
            rimGrad.addColorStop(0.0, shellRoot.cssRgba(glowPrimary, 0.52));
            rimGrad.addColorStop(0.32, shellRoot.cssRgba(glowAlt, 0.20));
            rimGrad.addColorStop(0.68, shellRoot.cssRgba(glowAlt, 0.18));
            rimGrad.addColorStop(1.0, shellRoot.cssRgba(glowPrimary, 0.46));
            ctx.lineWidth = 1.25;
            ctx.strokeStyle = rimGrad;
            ctx.stroke();
        }
    }

    // 1. BarGroup: Floating Frosted Sea-Glass Stadium Pill Capsule (height: 40, radius: 20, matching image-8.png)
    component BarGroup: Item {
        id: grpRoot
        property real padding: 5
        height: 40

        // Soft ambient drop shadow beneath the floating glass capsule
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.bottomMargin: -2
            radius: height / 2
            color: Qt.rgba(0.02, 0.05, 0.07, 0.30)
        }

        // Frosted Sea-Glass Stadium Body + Specular Rim
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

                // 1. Subtle frosted circular ring track
                ctx.beginPath();
                ctx.arc(cx, cy, rOuter, 0, Math.PI * 2, false);
                ctx.lineWidth = 1.6;
                ctx.strokeStyle = shellRoot.cssRgba(ringRoot.primaryColor, 0.25);
                ctx.stroke();

                // 2. Crisp frosted silver-white progress arc
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

    // 3. CircleUtilButton: Clean Icon Button sitting directly on the glass capsule (soft inner frosted pill on hover)
    component CircleUtilButton: Rectangle {
        id: utilBtn
        property string iconText: ""
        signal triggered()
        signal rightTriggered()

        implicitWidth: 28
        implicitHeight: 28
        radius: 14
        color: utilMouse.containsMouse
            ? Qt.rgba(0.84, 0.93, 0.96, 0.16)
            : "transparent"

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        Text {
            anchors.centerIn: parent
            text: utilBtn.iconText
            color: utilMouse.containsMouse ? theme.mainFg : theme.secondaryFg
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

    // ── SINGLE TOP FLOATING FROSTED SEA-GLASS PILL BAR (matching image-8.png — NO bottom bar, NO opaque screen frame) ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData

            readonly property int barHeight: 50
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
            implicitHeight: barHeight
            color: "transparent"

            mask: Region {
                item: barContent
            }

            // Transparent top container holding the 3 floating Frosted Sea-Glass Stadium Capsules
            Item {
                id: barContent
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: barWindow.barHeight

                // ── 1. TOP-LEFT FLOATING FROSTED GLASS CAPSULE (`leftCenterGroup`) ──
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
                            leftMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        padding: 5
                        implicitWidth: leftPillRow.implicitWidth + padding * 2 + 6

                        RowLayout {
                            id: leftPillRow
                            anchors {
                                left: parent.left
                                leftMargin: 5
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 12

                            // Leftmost Active-Style Soft Frosted Inner Pill (matches the Home pill on the left of image-8.png!)
                            Rectangle {
                                id: leftSidebarBtn
                                implicitWidth: 46
                                implicitHeight: 30
                                radius: 15
                                color: leftBtnMouse.containsMouse
                                    ? Qt.rgba(0.86, 0.94, 0.98, 0.25)
                                    : Qt.rgba(0.84, 0.93, 0.96, 0.17)
                                border.width: 1
                                border.color: Qt.rgba(0.92, 0.97, 1.0, 0.10)

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰋜"
                                    color: theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 16
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
                                implicitHeight: 30
                                radius: 15
                                color: mediaMouse.containsMouse
                                    ? Qt.rgba(0.84, 0.93, 0.96, 0.15)
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

                // ── 2. TOP-CENTER FLOATING FROSTED SEA-GLASS PILL (`middleCenterGroup` — 1:1 visual match to image-8.png) ──
                BarGroup {
                    id: middleCenterGroup
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                    }
                    padding: 5
                    width: wsContainer.implicitWidth + 10

                    Item {
                        id: wsContainer
                        anchors.centerIn: parent
                        readonly property real pillWidth: 50
                        readonly property real pillHeight: 30
                        readonly property real pillPitch: 56
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
                            color: Qt.rgba(0.84, 0.93, 0.96, 0.17)
                            border.width: 1
                            border.color: Qt.rgba(0.92, 0.97, 1.0, 0.10)
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

                                // Subtle hover pill for non-active slots
                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    visible: wsHit.containsMouse && !wsSlot.isActive
                                    color: Qt.rgba(0.84, 0.93, 0.96, 0.09)
                                }

                                // Crisp snow-white icon when active, frosted silver-ice icon when inactive (exact match to image-8.png)
                                Text {
                                    anchors.centerIn: parent
                                    text: shellRoot.iconForWorkspaceSlot(wsSlot.index)
                                    color: wsSlot.isActive ? theme.mainFg : theme.secondaryFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: wsSlot.isActive ? 16 : 15

                                    Behavior on color {
                                        ColorAnimation { duration: 180 }
                                    }
                                }

                                // Tiny frosted indicator dot under occupied inactive workspaces
                                Rectangle {
                                    visible: wsSlot.isOcc && !wsSlot.isActive
                                    anchors {
                                        bottom: parent.bottom
                                        bottomMargin: 3
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

                // ── 3. TOP-RIGHT FLOATING FROSTED GLASS CAPSULE (`rightCenterGroup`) ──
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
                            rightMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        padding: 5
                        implicitWidth: rightDockRow.implicitWidth + padding * 2 + 6

                        RowLayout {
                            id: rightDockRow
                            anchors {
                                right: parent.right
                                rightMargin: 5
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 10

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

                            // Bluetooth icon sitting directly on the glass
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

                            // Wi-Fi icon sitting directly on the glass
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

                            // Microphone icon sitting directly on the glass
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

                            // Clean Frosted Battery Indicator sitting directly on the glass
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

                            // Rightmost Active-Style Soft Frosted Inner Pill: Clock, Date & Settings (mirrors the active pill of image-8.png)
                            Rectangle {
                                id: rightClockPill
                                implicitWidth: clockPillRow.implicitWidth + 22
                                implicitHeight: 30
                                radius: 15
                                color: rightClockMouse.containsMouse
                                    ? Qt.rgba(0.86, 0.94, 0.98, 0.25)
                                    : Qt.rgba(0.84, 0.93, 0.96, 0.17)
                                border.width: 1
                                border.color: Qt.rgba(0.92, 0.97, 1.0, 0.10)

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
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
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

            // Hidden screen-corner components retained for contract compatibility (fillAlpha: 0.0)
            RoundCorner {
                visible: false
                anchors {
                    top: barContent.bottom
                    left: parent.left
                }
                corner: "top-left"
                cornerSize: barWindow.cornerSize
                fillColor: theme.barBg
                fillAlpha: 0.0
            }

            RoundCorner {
                visible: false
                anchors {
                    top: barContent.bottom
                    right: parent.right
                }
                corner: "top-right"
                cornerSize: barWindow.cornerSize
                fillColor: theme.barBg
                fillAlpha: 0.0
            }

            RoundCorner {
                visible: false
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                }
                corner: "bottom-left"
                cornerSize: barWindow.cornerSize
                fillColor: theme.barBg
                fillAlpha: 0.0
            }

            RoundCorner {
                visible: false
                anchors {
                    bottom: parent.bottom
                    right: parent.right
                }
                corner: "bottom-right"
                cornerSize: barWindow.cornerSize
                fillColor: theme.barBg
                fillAlpha: 0.0
            }
        }
    }
}
