// AniDE Quickshell Bar — Single Top Bar in @bee_ui.ux Sculpted Dark Matte-Glass Style (image-7.png)
// Top-Left Frosted White Pill + Soft Oblong Resource Pill | Top-Center Sculpted 3D Orb Notch | Top-Right Multi-Pill Dock Capsule
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
    property string dateText: Qt.formatDateTime(new Date(), "ddd, dd/MM")
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
        var r = Math.round((c && c.r !== undefined ? c.r : 0.9) * 255);
        var g = Math.round((c && c.g !== undefined ? c.g : 0.85) * 255);
        var b = Math.round((c && c.b !== undefined ? c.b : 0.95) * 255);
        var alpha = Math.max(0.0, Math.min(1.0, a));
        return "rgba(" + r + "," + g + "," + b + "," + alpha.toFixed(3) + ")";
    }

    function iconForClass(cls) {
        if (!cls) return "󰣆";
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
        return "󰣆";
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
            shellRoot.dateText = Qt.formatDateTime(now, "ddd, dd/MM");
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
                            // Subtle 14% atmospheric wallpaper tint on top of the @bee_ui.ux dark smoky matte-glass palette
                            theme.barBg = theme.subtleTint("#0c0f13", dc[0], 0.14);
                            theme.mainBg = theme.subtleTint("#11151a", dc[0], 0.14);
                            if (dc[1]) theme.surfaceBg = theme.subtleTint("#1d2229", dc[1], 0.14);
                            if (dc[2]) theme.layer2Bg = theme.subtleTint("#2c333d", dc[2], 0.14);
                            if (dc[3]) theme.subFg = theme.subtleTint("#8c96a4", dc[3], 0.12);
                            if (dc[4]) theme.mainFg = theme.subtleTint("#e8edf3", dc[4], 0.10);
                            if (dc[5]) theme.accentSecondary = theme.subtleTint("#323944", dc[5], 0.14);
                            if (dc[6]) {
                                theme.actBg = theme.subtleTint("#e4e9f0", dc[6], 0.12);
                                theme.glowColor = theme.subtleTint("#93c5fd", dc[6], 0.20);
                            }
                            if (dc[7]) {
                                theme.secondaryFg = theme.subtleTint("#dde4ed", dc[7], 0.12);
                                theme.glowSecondary = theme.subtleTint("#cbd5e1", dc[7], 0.15);
                            }
                            shellRoot.paintGeneration += 1;
                        }
                    }
                }
            }
        }
    }

    // ── Reusable @bee_ui.ux Sculpted Matte-Glass Components (image-7.png) ──

    // 0. DreamyMistCanvas: Soft vertical matte-glass sheen inside sculpted capsules
    component DreamyMistCanvas: Canvas {
        id: mistCanvas
        property color baseColor: theme.surfaceBg
        property real baseOpacity: theme.pillOpacity
        anchors.fill: parent
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onBaseColorChanged: requestPaint()
        onBaseOpacityChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (width <= 2 || height <= 2) return;
            var r = height / 2;
            ctx.beginPath();
            ctx.moveTo(r, 0);
            ctx.lineTo(width - r, 0);
            ctx.arc(width - r, r, r, -Math.PI / 2, Math.PI / 2, false);
            ctx.lineTo(r, height);
            ctx.arc(r, r, r, Math.PI / 2, -Math.PI / 2, false);
            ctx.closePath();
            ctx.fillStyle = Qt.alpha(baseColor, baseOpacity);
            ctx.fill();
        }
    }

    // 1. BarGroup: Soft matte-charcoal oblong inner pill (`(═══)` inside sculpted dock capsule, matching image-7.png)
    component BarGroup: Rectangle {
        id: grpRoot
        property real padding: 10
        height: 26
        radius: 13
        color: Qt.alpha(theme.layer2Bg, theme.pillOpacity)
        border.width: 1
        border.color: Qt.alpha(theme.borderColor, 0.35)

        Behavior on color {
            ColorAnimation { duration: 300 }
        }
    }

    // 2. CircularResourceRing: Soft matte-glass circular progress ring (18x18)
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
                var rOuter = width / 2;
                var rInner = rOuter - 2.2;

                // 1. Softly translucent matte circle track
                ctx.beginPath();
                ctx.arc(cx, cy, rOuter, 0, Math.PI * 2, false);
                ctx.fillStyle = Qt.alpha(ringRoot.trackColor, 0.42);
                ctx.fill();

                // 2. Progress arc in frosted silver-white
                var clamped = Math.max(0.0, Math.min(1.0, ringRoot.value));
                if (clamped > 0.01) {
                    ctx.beginPath();
                    ctx.moveTo(cx, cy);
                    ctx.arc(cx, cy, rOuter, -Math.PI / 2, -Math.PI / 2 + clamped * Math.PI * 2, false);
                    ctx.closePath();
                    ctx.fillStyle = ringRoot.primaryColor;
                    ctx.fill();
                }

                // 3. Inner dark matte cutout
                ctx.beginPath();
                ctx.arc(cx, cy, rInner, 0, Math.PI * 2, false);
                ctx.fillStyle = Qt.alpha(theme.surfaceBg, 0.85);
                ctx.fill();
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

    // 3. CircleUtilButton: 3D matte circular icon orb (22x22)
    component CircleUtilButton: Rectangle {
        id: utilBtn
        property string iconText: ""
        signal triggered()

        implicitWidth: 22
        implicitHeight: 22
        radius: 11
        color: utilMouse.containsMouse ? Qt.alpha(theme.hvrBg, 0.78) : Qt.alpha(theme.layer2Bg, 0.52)
        border.width: 1
        border.color: Qt.alpha(theme.borderColor, 0.36)

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        Text {
            anchors.centerIn: parent
            text: utilBtn.iconText
            color: theme.mainFg
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
        }

        MouseArea {
            id: utilMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: utilBtn.triggered()
        }
    }

    // ── SINGLE TOP SCULPTED BAR WINDOW (matching @bee_ui.ux image-7.png — NO bottom bar!) ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData

            readonly property int barHeight: 42
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

            // Main Top Sculpted Dark Matte-Glass Frame Band
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

                // Crisp 1px bottom specular rim along the top frame (matching image-7.png)
                Rectangle {
                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                    }
                    height: 1
                    color: Qt.alpha(theme.borderColor, 0.42)
                }

                // ── 1. TOP-LEFT SECTION: Frosted White Pill (`[ ✦ ]`) + Soft Oblong Resource Pill (`leftCenterGroup`) + Active Window ──
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

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8

                        // Signature Frosted White Capsule Pill in top-left corner (exact match to top-left of image-7.png)
                        Rectangle {
                            id: leftSidebarBtn
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: 14
                            implicitWidth: 34
                            implicitHeight: 19
                            radius: 9.5
                            color: leftBtnMouse.containsMouse
                                ? theme.mainFg
                                : Qt.alpha(theme.actBg, 0.92)

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "✦"
                                color: theme.actFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.bold: true
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

                        // Sculpted Left Capsule containing Oblong Resource Pill + Oblong Media Pill
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: leftDockRow.implicitWidth + 10
                            height: 34
                            radius: 17
                            border.width: 1
                            border.color: Qt.alpha(theme.borderColor, 0.55)

                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0.0; color: Qt.alpha(theme.barBg, 0.90) }
                                GradientStop { position: 0.65; color: Qt.alpha(theme.surfaceBg, 0.78) }
                                GradientStop { position: 1.0; color: Qt.alpha(theme.layer2Bg, 0.70) }
                            }

                            RowLayout {
                                id: leftDockRow
                                anchors.centerIn: parent
                                spacing: 6

                                // Oblong Pill 1: Resources (RAM, Swap, CPU)
                                BarGroup {
                                    id: leftCenterGroup
                                    padding: 8
                                    implicitWidth: resRow.implicitWidth + padding * 2

                                    RowLayout {
                                        id: resRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        RowLayout {
                                            spacing: 3
                                            CircularResourceRing {
                                                value: shellRoot.memoryUsage
                                                iconText: "󰍛"
                                                primaryColor: shellRoot.memoryUsage >= 0.90 ? theme.errorColor : theme.secondaryFg
                                            }
                                            Text {
                                                text: Math.round(shellRoot.memoryUsage * 100).toString()
                                                color: theme.mainFg
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 11
                                            }
                                        }

                                        RowLayout {
                                            spacing: 3
                                            CircularResourceRing {
                                                value: shellRoot.swapUsage
                                                iconText: "󰓡"
                                                primaryColor: shellRoot.swapUsage >= 0.90 ? theme.errorColor : theme.secondaryFg
                                            }
                                            Text {
                                                text: Math.round(shellRoot.swapUsage * 100).toString()
                                                color: theme.mainFg
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 11
                                            }
                                        }

                                        RowLayout {
                                            spacing: 3
                                            CircularResourceRing {
                                                value: shellRoot.cpuUsage
                                                iconText: "󰻠"
                                                primaryColor: shellRoot.cpuUsage >= 0.90 ? theme.errorColor : theme.secondaryFg
                                            }
                                            Text {
                                                text: Math.round(shellRoot.cpuUsage * 100).toString()
                                                color: theme.mainFg
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 11
                                            }
                                        }
                                    }
                                }

                                // Oblong Pill 2: Media / AniSub ("No media" / active track)
                                BarGroup {
                                    id: mediaPillGroup
                                    padding: 8
                                    implicitWidth: mediaWidget.implicitWidth + padding * 2

                                    RowLayout {
                                        id: mediaWidget
                                        anchors.centerIn: parent
                                        readonly property var activePlayer: (Mpris.players && Mpris.players.values && Mpris.players.values.length > 0)
                                            ? Mpris.players.values[0]
                                            : null
                                        readonly property bool hasTrack: activePlayer !== null && activePlayer.trackTitle !== ""
                                        spacing: 5

                                        CircularResourceRing {
                                            value: (mediaWidget.activePlayer && mediaWidget.activePlayer.length > 0)
                                                ? (mediaWidget.activePlayer.position / mediaWidget.activePlayer.length)
                                                : (mediaWidget.hasTrack && mediaWidget.activePlayer.isPlaying ? 0.65 : 0.0)
                                            iconText: (mediaWidget.hasTrack && mediaWidget.activePlayer.isPlaying) ? "" : "󰎈"
                                            primaryColor: theme.secondaryFg
                                        }

                                        Item {
                                            implicitWidth: 82
                                            implicitHeight: 20

                                            Text {
                                                anchors.centerIn: parent
                                                width: parent.width
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                                text: mediaWidget.hasTrack
                                                    ? (mediaWidget.activePlayer.trackTitle + (mediaWidget.activePlayer.trackArtist ? (" • " + mediaWidget.activePlayer.trackArtist) : ""))
                                                    : "No media"
                                                color: theme.mainFg
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 11
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: mouse => {
                                                    if (!mediaWidget.hasTrack || mouse.button === Qt.LeftButton) {
                                                        shellRoot.runCmd(["hyde-shell", "rofi.movie"]);
                                                    } else if (mouse.button === Qt.MiddleButton && mediaWidget.activePlayer) {
                                                        mediaWidget.activePlayer.togglePlaying();
                                                    } else if (mouse.button === Qt.RightButton && mediaWidget.activePlayer) {
                                                        mediaWidget.activePlayer.next();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }

                // ── 2. TOP-CENTER SCULPTED NOTCH ISLAND: 5 Circular 3D Matte Orbs `[ ●  ●  ●  ●  ● ]` (exact match to top-center of image-7.png) ──
                Rectangle {
                    id: middleCenterGroup
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                    }
                    width: wsContainer.implicitWidth + 28
                    height: 34
                    radius: 17
                    border.width: 1
                    border.color: Qt.alpha(theme.borderColor, 0.65)

                    // Sculpted 3D dark-to-smoky-silver vertical gradient matching the top notch in image-7.png
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: Qt.alpha(theme.barBg, 0.95) }
                        GradientStop { position: 0.60; color: Qt.alpha(theme.surfaceBg, 0.86) }
                        GradientStop { position: 1.0; color: Qt.alpha(theme.layer2Bg, 0.80) }
                    }

                    Item {
                        id: wsContainer
                        anchors.centerIn: parent
                        readonly property real orbSize: 18
                        readonly property real orbPitch: 30 // 18px orb + 12px spacing
                        readonly property int targetIndex: barWindow.localOrbIndex

                        property real idx1: targetIndex
                        property real idx2: targetIndex
                        Behavior on idx1 {
                            NumberAnimation { duration: 100; easing.type: Easing.OutSine }
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

                        implicitWidth: orbPitch * 5 - (orbPitch - orbSize)
                        implicitHeight: 22

                        // Layer 1: 5 Circular 3D Matte Workspace Orbs (exact match to top-center 5 orbs in image-7.png)
                        Repeater {
                            model: 5

                            Item {
                                id: wsSlot
                                required property int index
                                readonly property int wsId: barWindow.bankOffset + index + 1
                                readonly property bool isActive: (barWindow.localOrbIndex === index)
                                readonly property bool isOcc: wsContainer.isWsOccupied(wsId)
                                readonly property string winClass: (shellRoot.wsClasses && shellRoot.wsClasses[wsId.toString()])
                                    ? shellRoot.wsClasses[wsId.toString()]
                                    : (isActive && shellRoot.activeWinClass !== "" ? shellRoot.activeWinClass : "")

                                x: index * wsContainer.orbPitch
                                width: wsContainer.orbSize
                                height: parent.height

                                // 3D Matte Circular Orb
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: wsContainer.orbSize
                                    height: wsContainer.orbSize
                                    radius: wsContainer.orbSize / 2
                                    border.width: 1
                                    border.color: wsSlot.isOcc
                                        ? Qt.alpha(theme.borderColor, 0.60)
                                        : Qt.alpha(theme.borderColor, 0.28)

                                    gradient: Gradient {
                                        orientation: Gradient.Vertical
                                        GradientStop {
                                            position: 0.0
                                            color: wsSlot.isOcc
                                                ? Qt.alpha(theme.layer2Bg, 0.88)
                                                : Qt.alpha(theme.surfaceBg, 0.72)
                                        }
                                        GradientStop {
                                            position: 1.0
                                            color: wsSlot.isOcc
                                                ? Qt.alpha(theme.surfaceBg, 0.92)
                                                : Qt.alpha(theme.barBg, 0.88)
                                        }
                                    }

                                    // Subtle center dot for occupied non-active orb
                                    Rectangle {
                                        visible: wsSlot.isOcc && !wsSlot.isActive
                                        anchors.centerIn: parent
                                        width: 4.5
                                        height: 4.5
                                        radius: 2.25
                                        color: Qt.alpha(theme.secondaryFg, 0.75)
                                    }
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

                        // Layer 2: Liquid Stretchy Frosted-White Active Orb Indicator
                        Rectangle {
                            id: activeIndicator
                            z: 2
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.min(wsContainer.idx1, wsContainer.idx2) * wsContainer.orbPitch
                            width: Math.abs(wsContainer.idx1 - wsContainer.idx2) * wsContainer.orbPitch + wsContainer.orbSize
                            height: wsContainer.orbSize
                            radius: wsContainer.orbSize / 2
                            color: Qt.alpha(theme.actBg, 0.92)
                            border.width: 1
                            border.color: theme.mainFg

                            Behavior on color {
                                ColorAnimation { duration: 300 }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: shellRoot.iconForClass(shellRoot.activeWinClass)
                                color: theme.actFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                            }
                        }
                    }
                }

                // ── 3. TOP-RIGHT SCULPTED CAPSULE: Oblong Clock Pill + Oblong `[ • ───── • ]` Status Pill + Circular `(●)` Orb ──
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

                    Rectangle {
                        id: rightCenterGroup
                        anchors {
                            right: parent.right
                            rightMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        implicitWidth: rightDockRow.implicitWidth + 10
                        height: 34
                        radius: 17
                        border.width: 1
                        border.color: Qt.alpha(theme.borderColor, 0.55)

                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: Qt.alpha(theme.barBg, 0.90) }
                            GradientStop { position: 0.65; color: Qt.alpha(theme.surfaceBg, 0.78) }
                            GradientStop { position: 1.0; color: Qt.alpha(theme.layer2Bg, 0.70) }
                        }

                        RowLayout {
                            id: rightDockRow
                            anchors.centerIn: parent
                            spacing: 6

                            // Oblong Pill A: Clock & Date (HH:mm • ddd, dd/MM)
                            BarGroup {
                                id: clockPillGroup
                                padding: 10
                                implicitWidth: clockRow.implicitWidth + padding * 2

                                RowLayout {
                                    id: clockRow
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: shellRoot.timeText
                                        color: theme.mainFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }

                                    Text {
                                        text: "•"
                                        color: theme.subFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                    }

                                    Text {
                                        text: shellRoot.dateText
                                        color: theme.secondaryFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                    }
                                }
                            }

                            // Oblong Pill B: Top-Right Pocket Style `[ •  ──────   • ]` + Quick Status Icons & Battery
                            BarGroup {
                                id: statusPillGroup
                                padding: 8
                                implicitWidth: statusPillRow.implicitWidth + padding * 2

                                RowLayout {
                                    id: statusPillRow
                                    anchors.centerIn: parent
                                    spacing: 7

                                    CircleUtilButton {
                                        iconText: "󰆞"
                                        onTriggered: shellRoot.runCmd(["hyde-shell", "screenshot", "s"])
                                    }

                                    CircleUtilButton {
                                        iconText: "󰈊"
                                        onTriggered: shellRoot.runCmd(["hyprpicker", "-a"])
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
                                                implicitWidth: 20
                                                implicitHeight: 20
                                                radius: 10
                                                color: trayMouse.containsMouse ? theme.hvrBg : "transparent"

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

                                    // Bluetooth
                                    Text {
                                        text: shellRoot.bluetoothConnected
                                            ? "󰂱"
                                            : (shellRoot.bluetoothOn ? "󰂯" : "󰂲")
                                        color: theme.mainFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: shellRoot.runCmd(["blueman-manager"])
                                        }
                                    }

                                    // Wi-Fi
                                    Text {
                                        text: shellRoot.networkName !== "" ? "󰤨" : "󰤭"
                                        color: theme.mainFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: shellRoot.runCmd(["nm-connection-editor"])
                                        }
                                    }

                                    // Mic
                                    Text {
                                        text: shellRoot.micMuted ? "󰍭" : "󰍬"
                                        color: theme.mainFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                shellRoot.runCmd(["pamixer", "--default-source", "-t"]);
                                                statusProc.running = true;
                                            }
                                        }
                                    }

                                    // Volume icon + sleek frosted horizontal bar (`──────` from top-right pill of image-7.png)
                                    RowLayout {
                                        spacing: 4

                                        Text {
                                            text: shellRoot.volumeMuted
                                                ? "󰝟"
                                                : (shellRoot.volumeLevel < 35 ? "󰕿" : (shellRoot.volumeLevel < 70 ? "󰖀" : "󰕾"))
                                            color: theme.mainFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 13

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
                                            implicitWidth: 38
                                            implicitHeight: 6
                                            radius: 3
                                            color: Qt.alpha(theme.barBg, 0.75)
                                            clip: true

                                            Rectangle {
                                                width: shellRoot.volumeMuted
                                                    ? 0
                                                    : Math.max(4, parent.width * Math.max(0.0, Math.min(1.0, shellRoot.volumeLevel / 100.0)))
                                                height: parent.height
                                                radius: 3
                                                color: Qt.alpha(theme.actBg, 0.90)
                                            }
                                        }
                                    }

                                    // Frosted White Battery Badge (`92`, matching the right dot/pill in image-7.png)
                                    Item {
                                        implicitWidth: 30
                                        implicitHeight: 16

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 8
                                            color: Qt.alpha(theme.accentSecondary, 0.55)
                                            clip: true

                                            Rectangle {
                                                width: Math.max(6, parent.width * Math.max(0.0, Math.min(1.0, shellRoot.batteryLevel)))
                                                height: parent.height
                                                radius: 8
                                                color: (shellRoot.batteryLevel <= 0.20 && !shellRoot.batteryCharging)
                                                    ? theme.errorColor
                                                    : Qt.alpha(theme.actBg, 0.92)
                                            }

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 0

                                                Text {
                                                    visible: shellRoot.batteryCharging
                                                    text: ""
                                                    color: theme.actFg
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 8
                                                }

                                                Text {
                                                    text: Math.round(Math.max(0, shellRoot.batteryLevel * 100)).toString()
                                                    color: theme.actFg
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Rightmost 3D Matte Circular Orb (`(●)` on the far right of the capsule in image-7.png)
                            Rectangle {
                                id: rightOrbBtn
                                implicitWidth: 26
                                implicitHeight: 26
                                radius: 13
                                color: rightOrbMouse.containsMouse
                                    ? Qt.alpha(theme.hvrBg, 0.85)
                                    : Qt.alpha(theme.layer2Bg, 0.62)
                                border.width: 1
                                border.color: Qt.alpha(theme.borderColor, 0.45)

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒓"
                                    color: theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    id: rightOrbMouse
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

            // ── Top-Left & Top-Right Concave Screen Corners ──
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

    // ── BOTTOM SCREEN CORNERS ONLY (NO bottom bar! Zero exclusiveZone, pass-through input mask) ──
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
}
