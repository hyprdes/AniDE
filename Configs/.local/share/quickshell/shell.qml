// AniDE Quickshell Bar — Faithfully modeled on end-4/dots-hyprland (Illogical Impulse `ii` Tonal Spot + Hug style)
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
    property int volumeLevel: 0
    property bool volumeMuted: false
    property bool micMuted: false
    property int brightnessLevel: 100
    property real cpuUsage: 0.03     // 0.0 .. 1.0
    property real memoryUsage: 0.36  // 0.0 .. 1.0
    property real swapUsage: 0.70    // 0.0 .. 1.0 (Swap / Root disk fallback)
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
            "vol=$(pamixer --get-volume 2>/dev/null || echo 0); " +
            "mute=$(pamixer --get-mute 2>/dev/null || echo false); " +
            "micm=$(pamixer --default-source --get-mute 2>/dev/null || echo false); " +
            "br=$(brightnessctl -m 2>/dev/null | awk -F, '{gsub(/%/,\"\",$4); print $4}' | head -n1); " +
            "[ -n \"$br\" ] || br=100; " +
            "ram=$(awk '/MemTotal:/ {t=$2} /MemAvailable:/ {a=$2} END {if(t>0) printf \"%d\", (t-a)*100/t; else print 36}' /proc/meminfo 2>/dev/null || echo 36); " +
            "swp=$(awk '/SwapTotal:/ {t=$2} /SwapFree:/ {f=$2} END {if(t>0) printf \"%d\", (t-f)*100/t; else print -1}' /proc/meminfo 2>/dev/null || echo -1); " +
            "if [ \"$swp\" -le 0 ] 2>/dev/null; then swp=$(df -P / 2>/dev/null | awk 'NR==2 {gsub(/%/,\"\",$5); print $5}' || echo 70); fi; " +
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
                            theme.barBg = theme.normHex(dc[0]);
                            theme.mainBg = theme.normHex(dc[0]);
                            if (dc[1]) theme.surfaceBg = theme.normHex(dc[1]);
                            if (dc[2]) theme.layer2Bg = theme.normHex(dc[2]);
                            if (dc[3]) theme.subFg = theme.normHex(dc[3]);
                            if (dc[4]) theme.mainFg = theme.normHex(dc[4]);
                            if (dc[5]) theme.accentSecondary = theme.normHex(dc[5]);
                            if (dc[6]) {
                                theme.actBg = theme.normHex(dc[6]);
                                theme.glowColor = theme.normHex(dc[6]);
                            }
                            if (dc[7]) {
                                theme.secondaryFg = theme.normHex(dc[7]);
                                theme.glowSecondary = theme.normHex(dc[7]);
                            }
                            theme.actFg = theme.normHex(dc[0]);
                            shellRoot.paintGeneration += 1;
                        }
                    }
                }
            }
        }
    }

    // ── Reusable end-4 Illogical Impulse (ii) Components (matching image-5.png) ──

    // 0. DreamyMistCanvas: Subtle Material 3 Tonal Spot surface fill inside BarGroup capsules
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

    // 1. end-4 BarGroup: Clean borderless Material 3 colLayer1 capsule (32px height inside 40px bar, radius: 16)
    component BarGroup: Rectangle {
        id: grpRoot
        property real padding: 8
        height: 32
        radius: 16
        color: Qt.alpha(theme.surfaceBg, theme.pillOpacity)

        Behavior on color {
            ColorAnimation { duration: 300 }
        }
    }

    // 2. end-4 ClippedFilledCircularProgress (Filled tonal circle with progress arc + center icon cutout, 20x20)
    component CircularResourceRing: Item {
        id: ringRoot
        property real value: 0.0 // 0.0 .. 1.0
        property string iconText: "󰍛"
        property color primaryColor: theme.secondaryFg
        property color trackColor: theme.accentSecondary
        property int size: 20

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
                var rInner = rOuter - 2.6;

                // 1. Filled tonal circle background (softly translucent colSecondaryContainer)
                ctx.beginPath();
                ctx.arc(cx, cy, rOuter, 0, Math.PI * 2, false);
                ctx.fillStyle = Qt.alpha(ringRoot.trackColor, 0.45);
                ctx.fill();

                // 2. Progress pie/arc in colOnSecondaryContainer
                var clamped = Math.max(0.0, Math.min(1.0, ringRoot.value));
                if (clamped > 0.01) {
                    ctx.beginPath();
                    ctx.moveTo(cx, cy);
                    ctx.arc(cx, cy, rOuter, -Math.PI / 2, -Math.PI / 2 + clamped * Math.PI * 2, false);
                    ctx.closePath();
                    ctx.fillStyle = ringRoot.primaryColor;
                    ctx.fill();
                }

                // 3. Inner circle for crisp icon contrast
                ctx.beginPath();
                ctx.arc(cx, cy, rInner, 0, Math.PI * 2, false);
                ctx.fillStyle = Qt.alpha(theme.surfaceBg, 0.78);
                ctx.fill();
            }
        }

        Text {
            anchors.centerIn: parent
            text: ringRoot.iconText
            color: ringRoot.primaryColor
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
        }
    }

    // 3. end-4 CircleUtilButton (22x22 borderless colLayer2 circular icon button)
    component CircleUtilButton: Rectangle {
        id: utilBtn
        property string iconText: ""
        signal triggered()

        implicitWidth: 22
        implicitHeight: 22
        radius: 11
        color: utilMouse.containsMouse ? Qt.alpha(theme.hvrBg, 0.75) : Qt.alpha(theme.layer2Bg, 0.48)

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

    // ── TOP BAR WINDOW (end-4 Bar.qml + BarContent.qml, 40px height, Bar style: Hug) ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData

            readonly property int barHeight: 40
            readonly property int cornerSize: theme.cornerRadius
            readonly property int activeWsId: (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace)
                ? Hyprland.focusedMonitor.activeWorkspace.id
                : 1
            readonly property int activeWsIndex: Math.max(0, Math.min(9, ((activeWsId - 1) % 10)))

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

            // BarContent (40px height, clean Material 3 colLayer0 background)
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

                // ── 1. LEFT SECTION (Sparkle LeftSidebarButton + Two-line ActiveWindow; scroll for Brightness) ──
                MouseArea {
                    id: leftSideArea
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        left: parent.left
                        right: middleSection.left
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

                        // LeftSidebarButton (Sparkle icon at leftMargin = 18px, matching image-5.png)
                        Rectangle {
                            id: leftSidebarBtn
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: 18
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: 14
                            color: leftBtnMouse.containsMouse ? theme.hvrBg : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "✦"
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

                        // end-4 ActiveWindow (Two-line stacked directly on colLayer0: appId on top, window title on bottom)
                        ColumnLayout {
                            Layout.rightMargin: 16
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: -3

                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: shellRoot.activeWinClass !== ""
                                    ? shellRoot.activeWinClass
                                    : ((Hyprland.activeToplevel && Hyprland.activeToplevel.title) ? "application" : "Desktop")
                                color: theme.subFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                            }

                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: (Hyprland.activeToplevel && Hyprland.activeToplevel.title)
                                    ? Hyprland.activeToplevel.title
                                    : (shellRoot.activeWinTitle !== "" ? shellRoot.activeWinTitle : ("Workspace " + barWindow.activeWsId))
                                color: theme.mainFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                        }
                    }
                }

                // ── 2. MIDDLE SECTION (Three end-4 BarGroup capsules with spacing: 4) ──
                Row {
                    id: middleSection
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        horizontalCenter: parent.horizontalCenter
                    }
                    spacing: 4

                    // 2A. Left-Center BarGroup: Resources (RAM, Swap, CPU circular rings + numbers) + Media ("No media" / track)
                    BarGroup {
                        id: leftCenterGroup
                        anchors.verticalCenter: parent.verticalCenter
                        padding: 8
                        implicitWidth: leftCenterRow.implicitWidth + padding * 2

                        RowLayout {
                            id: leftCenterRow
                            anchors.centerIn: parent
                            spacing: 6

                            // RAM Resource (36)
                            RowLayout {
                                spacing: 4
                                CircularResourceRing {
                                    value: shellRoot.memoryUsage
                                    iconText: "󰍛"
                                    primaryColor: shellRoot.memoryUsage >= 0.90 ? theme.errorColor : theme.secondaryFg
                                }
                                Text {
                                    text: Math.round(shellRoot.memoryUsage * 100).toString()
                                    color: theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                }
                            }

                            // Swap / Disk Resource (70)
                            RowLayout {
                                Layout.leftMargin: 6
                                spacing: 4
                                CircularResourceRing {
                                    value: shellRoot.swapUsage
                                    iconText: "󰓡"
                                    primaryColor: shellRoot.swapUsage >= 0.90 ? theme.errorColor : theme.secondaryFg
                                }
                                Text {
                                    text: Math.round(shellRoot.swapUsage * 100).toString()
                                    color: theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                }
                            }

                            // CPU Resource (3)
                            RowLayout {
                                Layout.leftMargin: 6
                                spacing: 4
                                CircularResourceRing {
                                    value: shellRoot.cpuUsage
                                    iconText: "󰻠"
                                    primaryColor: shellRoot.cpuUsage >= 0.90 ? theme.errorColor : theme.secondaryFg
                                }
                                Text {
                                    text: Math.round(shellRoot.cpuUsage * 100).toString()
                                    color: theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                }
                            }

                            // Media (MPRIS circular icon + centered "No media" / track title, matching image-5.png)
                            RowLayout {
                                id: mediaWidget
                                Layout.leftMargin: 8
                                readonly property var activePlayer: (Mpris.players && Mpris.players.values && Mpris.players.values.length > 0)
                                    ? Mpris.players.values[0]
                                    : null
                                readonly property bool hasTrack: activePlayer !== null && activePlayer.trackTitle !== ""
                                spacing: 6

                                CircularResourceRing {
                                    value: (mediaWidget.activePlayer && mediaWidget.activePlayer.length > 0)
                                        ? (mediaWidget.activePlayer.position / mediaWidget.activePlayer.length)
                                        : (mediaWidget.hasTrack && mediaWidget.activePlayer.isPlaying ? 0.65 : 0.0)
                                    iconText: (mediaWidget.hasTrack && mediaWidget.activePlayer.isPlaying) ? "" : "󰎈"
                                    primaryColor: theme.secondaryFg
                                }

                                Item {
                                    implicitWidth: 115
                                    implicitHeight: 24

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
                                        font.pixelSize: 12
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

                    // 2B. Middle-Center BarGroup: Workspaces (Connected Occupied Pill + App Icons + Subtle Dots for empty slots)
                    BarGroup {
                        id: middleCenterGroup
                        anchors.verticalCenter: parent.verticalCenter
                        padding: 5
                        implicitWidth: wsContainer.implicitWidth + padding * 2

                        Item {
                            id: wsContainer
                            anchors.centerIn: parent
                            readonly property real wsBtnWidth: 26
                            readonly property real activeMargin: 2
                            readonly property real activeSize: wsBtnWidth - activeMargin * 2 // 22px
                            readonly property int targetIndex: barWindow.activeWsIndex

                            // AnimatedTabIndexPair (end-4's signature liquid stretch: idx1=100ms, idx2=300ms)
                            property real idx1: targetIndex
                            property real idx2: targetIndex
                            Behavior on idx1 {
                                NumberAnimation { duration: 100; easing.type: Easing.OutSine }
                            }
                            Behavior on idx2 {
                                NumberAnimation { duration: 300; easing.type: Easing.OutSine }
                            }

                            function isWsOccupied(id) {
                                if (shellRoot.wsClasses && shellRoot.wsClasses[id.toString()]) return true;
                                var list = Hyprland.workspaces ? Hyprland.workspaces.values : [];
                                for (var i = 0; i < list.length; i++) {
                                    if (list[i].id === id) return true;
                                }
                                return false;
                            }

                            implicitWidth: wsBtnWidth * 10
                            implicitHeight: 32

                            // Layer 1: Connected Occupied Workspace Capsules (colSecondaryContainer stretching across adjacent occupied slots)
                            Repeater {
                                model: 10

                                Item {
                                    id: occSlot
                                    required property int index
                                    readonly property int wsId: index + 1
                                    readonly property bool curOcc: wsContainer.isWsOccupied(wsId)
                                    readonly property bool prevOcc: index > 0 && wsContainer.isWsOccupied(wsId - 1)
                                    readonly property bool nextOcc: index < 9 && wsContainer.isWsOccupied(wsId + 1)

                                    x: index * wsContainer.wsBtnWidth
                                    width: wsContainer.wsBtnWidth
                                    height: wsContainer.height

                                    Rectangle {
                                        visible: occSlot.curOcc
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: occSlot.prevOcc ? -wsContainer.activeMargin : wsContainer.activeMargin
                                        width: wsContainer.activeSize
                                            + (occSlot.prevOcc ? wsContainer.activeMargin * 2 : 0)
                                            + (occSlot.nextOcc ? wsContainer.activeMargin * 2 : 0)
                                        height: wsContainer.activeSize
                                        radius: wsContainer.activeSize / 2
                                        color: Qt.alpha(theme.accentSecondary, 0.46)
                                    }
                                }
                            }

                            // Layer 2: Liquid Stretchy Active Indicator (TrailingIndicator in colPrimary)
                            Rectangle {
                                id: activeIndicator
                                z: 2
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.min(wsContainer.idx1, wsContainer.idx2) * wsContainer.wsBtnWidth + wsContainer.activeMargin
                                width: Math.abs(wsContainer.idx1 - wsContainer.idx2) * wsContainer.wsBtnWidth + wsContainer.activeSize
                                height: wsContainer.activeSize
                                radius: wsContainer.activeSize / 2
                                color: theme.actBg

                                Behavior on color {
                                    ColorAnimation { duration: 300 }
                                }
                            }

                            // Layer 3: App Icons (for occupied workspaces) + Small Dots (for empty workspaces, matching image-5.png)
                            Repeater {
                                model: 10

                                Item {
                                    id: wsSlot
                                    required property int index
                                    readonly property int wsId: index + 1
                                    readonly property bool isActive: (barWindow.activeWsIndex === index)
                                    readonly property bool isOcc: wsContainer.isWsOccupied(wsId)
                                    readonly property string winClass: (shellRoot.wsClasses && shellRoot.wsClasses[wsId.toString()])
                                        ? shellRoot.wsClasses[wsId.toString()]
                                        : (isActive && shellRoot.activeWinClass !== "" ? shellRoot.activeWinClass : "")

                                    z: 3
                                    x: index * wsContainer.wsBtnWidth
                                    width: wsContainer.wsBtnWidth
                                    height: wsContainer.height

                                    // Small 4.5px dot for empty workspaces (slots 4, 5, 7, 8, 9, 10 in image-5.png)
                                    Rectangle {
                                        visible: !wsSlot.isOcc && !wsSlot.isActive
                                        anchors.centerIn: parent
                                        width: 4.5
                                        height: 4.5
                                        radius: 2.25
                                        color: theme.subFg
                                    }

                                    // App icon badge for occupied or active workspaces (slots 1, 2, 3, 6 in image-5.png)
                                    Rectangle {
                                        visible: wsSlot.isOcc || wsSlot.isActive
                                        anchors.centerIn: parent
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: shellRoot.iconForClass(wsSlot.winClass)
                                            color: wsSlot.isActive
                                                ? theme.actFg
                                                : theme.secondaryFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
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
                        }
                    }

                    // 2C. Right-Center BarGroup: ClockWidget (23:47 • Sat, 11/04) + 3 CircleUtilButtons + OneUI Battery Pill (⚡92)
                    BarGroup {
                        id: rightCenterGroup
                        anchors.verticalCenter: parent.verticalCenter
                        padding: 8
                        implicitWidth: rightCenterRow.implicitWidth + padding * 2

                        RowLayout {
                            id: rightCenterRow
                            anchors.centerIn: parent
                            spacing: 6

                            // ClockWidget (Single-tone clean M3 typography matching image-5.png)
                            RowLayout {
                                spacing: 4

                                Text {
                                    text: shellRoot.timeText
                                    color: theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }

                                Text {
                                    text: "•"
                                    color: theme.subFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                }

                                Text {
                                    text: shellRoot.dateText
                                    color: theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                }
                            }

                            // 3 CircleUtilButtons (Screen Snip, Color Picker, Keyboard/Movie — matching image-5.png)
                            RowLayout {
                                Layout.leftMargin: 6
                                spacing: 4

                                CircleUtilButton {
                                    iconText: "󰆞"
                                    onTriggered: shellRoot.runCmd(["hyde-shell", "screenshot", "s"])
                                }
                                CircleUtilButton {
                                    iconText: "󰈊"
                                    onTriggered: shellRoot.runCmd(["hyprpicker", "-a"])
                                }
                                CircleUtilButton {
                                    iconText: "󰌌"
                                    onTriggered: shellRoot.runCmd(["hyde-shell", "rofi.movie"])
                                }
                            }

                            // end-4 OneUI 7 ClippedProgressBar BatteryIndicator (⚡92)
                            Item {
                                Layout.leftMargin: 4
                                implicitWidth: 32
                                implicitHeight: 18

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 9
                                    color: Qt.alpha(theme.accentSecondary, 0.48)
                                    clip: true

                                    Rectangle {
                                        width: Math.max(6, parent.width * Math.max(0.0, Math.min(1.0, shellRoot.batteryLevel)))
                                        height: parent.height
                                        radius: 9
                                        color: (shellRoot.batteryLevel <= 0.20 && !shellRoot.batteryCharging)
                                            ? theme.errorColor
                                            : theme.secondaryFg
                                    }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 0

                                        Text {
                                            visible: shellRoot.batteryCharging
                                            text: ""
                                            color: theme.actFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 9
                                        }

                                        Text {
                                            text: Math.round(Math.max(0, shellRoot.batteryLevel * 100)).toString()
                                            color: theme.actFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 3. RIGHT SECTION (SysTray + Clean Monochrome Right Status Icons; scroll for Volume) ──
                MouseArea {
                    id: rightSideArea
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        left: middleSection.right
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

                    RowLayout {
                        anchors.fill: parent
                        layoutDirection: Qt.RightToLeft
                        spacing: 10

                        // RightSidebarButton status indicator pill (clean monochrome icons at rightMargin = 18px, matching image-5.png)
                        Rectangle {
                            id: rightStatusPill
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            Layout.rightMargin: 18
                            implicitWidth: rightIndicators.implicitWidth + 16
                            implicitHeight: 28
                            radius: 14
                            color: rightSideArea.containsMouse ? theme.hvrBg : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            RowLayout {
                                id: rightIndicators
                                anchors.centerIn: parent
                                spacing: 12

                                // Bluetooth indicator
                                Text {
                                    text: shellRoot.bluetoothConnected
                                        ? "󰂱"
                                        : (shellRoot.bluetoothOn ? "󰂯" : "󰂲")
                                    color: theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: shellRoot.runCmd(["blueman-manager"])
                                    }
                                }

                                // Network / Wi-Fi indicator
                                Text {
                                    text: shellRoot.networkName !== "" ? "󰤨" : "󰤭"
                                    color: theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: shellRoot.runCmd(["nm-connection-editor"])
                                    }
                                }

                                // Mic indicator (matching the mic_off icon in image-5.png)
                                Text {
                                    text: shellRoot.micMuted ? "󰍭" : "󰍬"
                                    color: theme.mainFg
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

                                // Audio / Volume indicator
                                Text {
                                    text: shellRoot.volumeMuted
                                        ? "󰝟"
                                        : (shellRoot.volumeLevel < 35 ? "󰕿" : (shellRoot.volumeLevel < 70 ? "󰖀" : "󰕾"))
                                    color: theme.mainFg
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
                                                shellRoot.runCmd(["hyde-shell", "anide-settings"]);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // System Tray (to the left of the right status icons, matching image-5.png)
                        RowLayout {
                            visible: SystemTray.items && SystemTray.items.values && SystemTray.items.values.length > 0
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 6

                            Repeater {
                                model: SystemTray.items

                                Rectangle {
                                    id: traySlot
                                    required property var modelData
                                    implicitWidth: 22
                                    implicitHeight: 22
                                    radius: 11
                                    color: trayMouse.containsMouse ? theme.hvrBg : "transparent"

                                    Image {
                                        anchors.centerIn: parent
                                        width: 15
                                        height: 15
                                        source: traySlot.modelData.icon || ""
                                        sourceSize.width: 15
                                        sourceSize.height: 15
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

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ── Top-Left & Top-Right Round Decorators (end-4 Bar.qml "Hug" style, seamless borderless concave curve) ──
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

    // ── BOTTOM SCREEN CORNERS (end-4 ScreenCorners.qml, seamless borderless concave curve) ──
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
