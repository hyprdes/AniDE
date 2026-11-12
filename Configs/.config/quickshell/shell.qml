// AniDE Quickshell Shell — Illogical Impulse (end-4) Screen-Framing Top Bar
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
    property int brightnessLevel: 100
    property int cpuPercent: 0
    property int ramPercent: 0
    property int batteryPercent: -1
    property string batteryStatus: ""
    property string networkName: ""

    function runCmd(args) {
        Quickshell.execDetached(args);
    }

    function appIconFor(title) {
        var t = (title || "").toLowerCase();
        if (t.indexOf("firefox") !== -1 || t.indexOf("mozilla") !== -1 || t.indexOf("chrome") !== -1) return "󰈹";
        if (t.indexOf("kitty") !== -1 || t.indexOf("zsh") !== -1 || t.indexOf("fish") !== -1 || t.indexOf("tmux") !== -1 || t.indexOf("~") !== -1) return "󰄛";
        if (t.indexOf("code") !== -1 || t.indexOf("nvim") !== -1 || t.indexOf("vim") !== -1) return "󰨞";
        if (t.indexOf("dolphin") !== -1 || t.indexOf("files") !== -1) return "󰉋";
        if (t.indexOf("mpv") !== -1 || t.indexOf("anisub") !== -1 || t.indexOf("vlc") !== -1) return "󰕼";
        if (t.indexOf("spotify") !== -1 || t.indexOf("music") !== -1) return "󰓇";
        if (t.indexOf("discord") !== -1 || t.indexOf("telegram") !== -1) return "󰙯";
        if (t.indexOf("settings") !== -1) return "󰒓";
        return "󰍹";
    }

    // Live Wallbash theme.json hot-reload
    FileView {
        id: themeFile
        path: Quickshell.env("XDG_CONFIG_HOME")
            ? (Quickshell.env("XDG_CONFIG_HOME") + "/quickshell/theme.json")
            : ((Quickshell.env("HOME") || "") + "/.config/quickshell/theme.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: theme.applyJson(text())
    }

    // Clock & system telemetry polling
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
            "br=$(brightnessctl -m 2>/dev/null | awk -F, '{gsub(/%/,\"\",$4); print $4}' | head -n1); " +
            "[ -n \"$br\" ] || br=100; " +
            "ram=$(awk '/MemTotal:/ {t=$2} /MemAvailable:/ {a=$2} END {if(t>0) printf \"%d\", (t-a)*100/t; else print 0}' /proc/meminfo 2>/dev/null || echo 0); " +
            "cpu_stat=/tmp/anide_qs_cpu.stat; " +
            "read -r _ u n s i io ir so st _ < /proc/stat; " +
            "tot=$((u+n+s+i+io+ir+so+st)); idle=$((i+io)); cpu=0; " +
            "if [ -r \"$cpu_stat\" ]; then " +
            "  read -r ptot pidle < \"$cpu_stat\" || true; " +
            "  dt=$((tot - ptot)); di=$((idle - pidle)); " +
            "  if [ \"$dt\" -gt 0 ]; then cpu=$(( (dt - di) * 100 / dt )); fi; " +
            "fi; " +
            "printf '%s %s\\n' \"$tot\" \"$idle\" > \"$cpu_stat\"; " +
            "bat=-1; bstat=''; " +
            "for b in /sys/class/power_supply/BAT*; do " +
            "  if [ -r \"$b/capacity\" ]; then bat=$(cat \"$b/capacity\"); bstat=$(cat \"$b/status\" 2>/dev/null); break; fi; " +
            "done; " +
            "net=$(nmcli -t -f NAME connection show --active 2>/dev/null | grep -v '^lo$' | head -n1); " +
            "printf '%s|%s|%s|%s|%s|%s|%s|%s\\n' \"$vol\" \"$mute\" \"$br\" \"$cpu\" \"$ram\" \"$bat\" \"$bstat\" \"$net\""
        ]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|");
                if (parts.length >= 8) {
                    shellRoot.volumeLevel = parseInt(parts[0], 10) || 0;
                    shellRoot.volumeMuted = (parts[1] === "true");
                    shellRoot.brightnessLevel = parseInt(parts[2], 10) || 100;
                    shellRoot.cpuPercent = Math.max(0, Math.min(100, parseInt(parts[3], 10) || 0));
                    shellRoot.ramPercent = Math.max(0, Math.min(100, parseInt(parts[4], 10) || 0));
                    shellRoot.batteryPercent = parseInt(parts[5], 10);
                    shellRoot.batteryStatus = parts[6] || "";
                    shellRoot.networkName = parts[7] || "";
                }
            }
        }
    }

    // ── TOP BAR + TOP CONCAVE CORNERS + SCULPTED CENTER NOTCH ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData

            readonly property int barHeight: 40
            readonly property int cornerSize: theme.cornerRadius

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

            // Input mask restricted to the top bar so clicks in the concave corner spandrels pass through
            mask: Region {
                item: barContainer
            }

            // Main top bar surface flush with the top/left/right screen edges
            Rectangle {
                id: barContainer
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: barWindow.barHeight
                color: theme.barBg

                // Subtle bottom luminous hairline
                Rectangle {
                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                        leftMargin: barWindow.cornerSize
                        rightMargin: barWindow.cornerSize
                    }
                    height: 1
                    opacity: 0.35
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.25; color: theme.actBg }
                        GradientStop { position: 0.5; color: theme.accentSecondary }
                        GradientStop { position: 0.75; color: theme.actBg }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // ── LEFT SECTION: Brand Orb + Morphing Workspaces + Active Window ──
                RowLayout {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10
                    }
                    spacing: 8

                    // 1. AniDE Brand / Launcher Orb
                    Rectangle {
                        implicitWidth: 38
                        implicitHeight: 28
                        radius: 14
                        scale: launcherMouse.containsMouse ? 1.05 : 1.0
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: theme.actBg }
                            GradientStop { position: 1.0; color: theme.accentSecondary }
                        }

                        Behavior on scale {
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰣇"
                            color: theme.actFg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            font.bold: true
                        }

                        MouseArea {
                            id: launcherMouse
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

                    // 2. Morphing Workspaces Capsule
                    Rectangle {
                        implicitHeight: 28
                        implicitWidth: wsRow.implicitWidth + 14
                        radius: 14
                        color: theme.surfaceBg
                        border.width: 1
                        border.color: Qt.alpha(theme.borderColor, 0.85)

                        WheelHandler {
                            onWheel: event => {
                                if (event.angleDelta.y > 0) {
                                    Hyprland.dispatch("workspace e-1");
                                } else if (event.angleDelta.y < 0) {
                                    Hyprland.dispatch("workspace e+1");
                                }
                            }
                        }

                        RowLayout {
                            id: wsRow
                            anchors.centerIn: parent
                            spacing: 4

                            Repeater {
                                model: 10

                                Rectangle {
                                    id: wsPill
                                    readonly property int wsId: index + 1
                                    readonly property bool isFocused: Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace
                                        ? (Hyprland.focusedMonitor.activeWorkspace.id === wsId)
                                        : (wsId === 1)
                                    readonly property bool isOccupied: {
                                        var list = Hyprland.workspaces ? Hyprland.workspaces.values : [];
                                        for (var i = 0; i < list.length; i++) {
                                            if (list[i].id === wsId) return true;
                                        }
                                        return false;
                                    }

                                    implicitWidth: isFocused ? 34 : (isOccupied ? 22 : (wsMouse.containsMouse ? 20 : 14))
                                    implicitHeight: 20
                                    radius: 10
                                    color: isFocused
                                        ? theme.actBg
                                        : (wsMouse.containsMouse
                                            ? theme.hvrBg
                                            : (isOccupied ? Qt.alpha(theme.actBg, 0.16) : "transparent"))

                                    Behavior on implicitWidth {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                                    }

                                    // Gradient overlay when focused
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        visible: wsPill.isFocused
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: theme.actBg }
                                            GradientStop { position: 1.0; color: theme.accentSecondary }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: (wsPill.isFocused || wsPill.isOccupied || wsMouse.containsMouse)
                                            ? wsPill.wsId.toString()
                                            : "•"
                                        color: wsPill.isFocused
                                            ? theme.actFg
                                            : (wsPill.isOccupied ? theme.mainFg : theme.subFg)
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: (wsPill.isFocused || wsPill.isOccupied || wsMouse.containsMouse) ? 11 : 13
                                        font.bold: wsPill.isFocused
                                    }

                                    MouseArea {
                                        id: wsMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Hyprland.dispatch("workspace " + wsPill.wsId)
                                    }
                                }
                            }
                        }
                    }

                    // 3. Active Window Chip with App Icon Badge
                    Rectangle {
                        readonly property string winTitle: (Hyprland.activeToplevel && Hyprland.activeToplevel.title)
                            ? Hyprland.activeToplevel.title
                            : "AniDE Desktop"
                        implicitHeight: 28
                        implicitWidth: Math.min(winRow.implicitWidth + 16, 260)
                        radius: 14
                        color: theme.surfaceBg
                        border.width: 1
                        border.color: Qt.alpha(theme.borderColor, 0.75)

                        RowLayout {
                            id: winRow
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 8
                                rightMargin: 10
                            }
                            spacing: 6

                            Rectangle {
                                implicitWidth: 18
                                implicitHeight: 18
                                radius: 9
                                color: Qt.alpha(theme.actBg, 0.18)

                                Text {
                                    anchors.centerIn: parent
                                    text: shellRoot.appIconFor(parent.parent.parent.winTitle)
                                    color: theme.actBg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.maximumWidth: 210
                                elide: Text.ElideRight
                                text: parent.parent.winTitle
                                color: theme.mainFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                            }
                        }
                    }
                }

                // ── CENTER SECTION: Sculpted Dynamic Island (Media + Clock + Date) ──
                Rectangle {
                    id: centerIsland
                    anchors.centerIn: parent
                    implicitHeight: 30
                    implicitWidth: centerRow.implicitWidth + 20
                    radius: 15
                    color: theme.surfaceBg
                    border.width: 1
                    border.color: Qt.alpha(theme.actBg, 0.35)

                    RowLayout {
                        id: centerRow
                        anchors.centerIn: parent
                        spacing: 10

                        // Media / AniSub Quick Chip
                        RowLayout {
                            id: mediaChip
                            readonly property var activePlayer: (Mpris.players && Mpris.players.values && Mpris.players.values.length > 0)
                                ? Mpris.players.values[0]
                                : null
                            readonly property bool hasTrack: activePlayer !== null && activePlayer.trackTitle !== ""
                            spacing: 6

                            // Mini equalizer / AniSub icon badge
                            Rectangle {
                                implicitWidth: mediaChip.hasTrack ? 22 : 68
                                implicitHeight: 20
                                radius: 10
                                color: mediaMouse.containsMouse
                                    ? Qt.alpha(theme.actBg, 0.30)
                                    : Qt.alpha(theme.actBg, 0.16)

                                Text {
                                    anchors.centerIn: parent
                                    text: mediaChip.hasTrack
                                        ? (mediaChip.activePlayer.isPlaying ? "󰎈" : "󰏤")
                                        : "󰿎 AniSub"
                                    color: theme.actBg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                MouseArea {
                                    id: mediaMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        if (!mediaChip.hasTrack || mouse.button === Qt.RightButton) {
                                            shellRoot.runCmd(["hyde-shell", "rofi.movie"]);
                                        } else if (mediaChip.activePlayer) {
                                            mediaChip.activePlayer.togglePlaying();
                                        }
                                    }
                                }
                            }

                            // Active track title + micro controls
                            Text {
                                visible: mediaChip.hasTrack
                                Layout.maximumWidth: 160
                                elide: Text.ElideRight
                                text: mediaChip.hasTrack ? mediaChip.activePlayer.trackTitle : ""
                                color: theme.mainFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
                                            shellRoot.runCmd(["hyde-shell", "rofi.movie"]);
                                        } else if (mediaChip.activePlayer) {
                                            mediaChip.activePlayer.togglePlaying();
                                        }
                                    }
                                }
                            }
                        }

                        // Glowing Accent Separator Dot
                        Rectangle {
                            implicitWidth: 5
                            implicitHeight: 5
                            radius: 2.5
                            color: theme.actBg
                        }

                        // Crisp Time Display
                        Text {
                            text: " " + shellRoot.timeText
                            color: theme.mainFg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.bold: true
                        }

                        // Date Badge Pill
                        Rectangle {
                            implicitHeight: 20
                            implicitWidth: dateLabel.implicitWidth + 14
                            radius: 10
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.alpha(theme.actBg, 0.22) }
                                GradientStop { position: 1.0; color: Qt.alpha(theme.accentSecondary, 0.22) }
                            }

                            Text {
                                id: dateLabel
                                anchors.centerIn: parent
                                text: shellRoot.dateText
                                color: theme.actBg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }
                }

                // ── RIGHT SECTION: Telemetry + Tray + Hardware Capsule + AniDE Dock + Power ──
                RowLayout {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: 10
                    }
                    spacing: 8

                    // 1. CPU & RAM Live Telemetry Capsule
                    Rectangle {
                        implicitHeight: 28
                        implicitWidth: telemetryRow.implicitWidth + 16
                        radius: 14
                        color: theme.surfaceBg
                        border.width: 1
                        border.color: Qt.alpha(theme.borderColor, 0.8)

                        RowLayout {
                            id: telemetryRow
                            anchors.centerIn: parent
                            spacing: 10

                            // CPU meter
                            RowLayout {
                                spacing: 4
                                Text {
                                    text: ""
                                    color: theme.actBg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                }
                                Text {
                                    text: shellRoot.cpuPercent + "%"
                                    color: theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }

                            // RAM meter
                            RowLayout {
                                spacing: 4
                                Text {
                                    text: ""
                                    color: theme.accentSecondary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                }
                                Text {
                                    text: shellRoot.ramPercent + "%"
                                    color: theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                        }
                    }

                    // 2. System Tray Capsule
                    Rectangle {
                        visible: SystemTray.items && SystemTray.items.values && SystemTray.items.values.length > 0
                        implicitHeight: 28
                        implicitWidth: trayRow.implicitWidth + 14
                        radius: 14
                        color: theme.surfaceBg
                        border.width: 1
                        border.color: Qt.alpha(theme.borderColor, 0.8)

                        RowLayout {
                            id: trayRow
                            anchors.centerIn: parent
                            spacing: 6

                            Repeater {
                                model: SystemTray.items

                                Rectangle {
                                    required property var modelData
                                    implicitWidth: 20
                                    implicitHeight: 20
                                    radius: 6
                                    color: trayMouse.containsMouse ? theme.hvrBg : "transparent"

                                    Image {
                                        anchors.centerIn: parent
                                        width: 15
                                        height: 15
                                        source: parent.modelData.icon || ""
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
                                                parent.modelData.secondaryActivate();
                                            } else {
                                                parent.modelData.activate();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 3. Hardware Capsule (Audio + Brightness + Network + Battery)
                    Rectangle {
                        implicitHeight: 28
                        implicitWidth: hwRow.implicitWidth + 18
                        radius: 14
                        color: theme.surfaceBg
                        border.width: 1
                        border.color: Qt.alpha(theme.borderColor, 0.8)

                        RowLayout {
                            id: hwRow
                            anchors.centerIn: parent
                            spacing: 10

                            // Audio Volume (scroll to adjust, click mute, right-click pavucontrol)
                            RowLayout {
                                spacing: 4

                                Text {
                                    text: shellRoot.volumeMuted
                                        ? "󰝟"
                                        : (shellRoot.volumeLevel < 35 ? "󰕿" : (shellRoot.volumeLevel < 70 ? "󰖀" : "󰕾"))
                                    color: shellRoot.volumeMuted ? theme.dangerColor : theme.actBg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }

                                Text {
                                    text: shellRoot.volumeLevel + "%"
                                    color: shellRoot.volumeMuted ? theme.subFg : theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    font.bold: true
                                }

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

                                WheelHandler {
                                    onWheel: event => {
                                        if (event.angleDelta.y > 0) {
                                            shellRoot.runCmd(["pamixer", "-i", "5"]);
                                        } else if (event.angleDelta.y < 0) {
                                            shellRoot.runCmd(["pamixer", "-d", "5"]);
                                        }
                                        statusProc.running = true;
                                    }
                                }
                            }

                            // Screen Brightness (scroll to adjust)
                            RowLayout {
                                spacing: 4

                                Text {
                                    text: "󰃠"
                                    color: theme.warnColor
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }

                                Text {
                                    text: shellRoot.brightnessLevel + "%"
                                    color: theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                WheelHandler {
                                    onWheel: event => {
                                        if (event.angleDelta.y > 0) {
                                            shellRoot.runCmd(["brightnessctl", "set", "+5%"]);
                                        } else if (event.angleDelta.y < 0) {
                                            shellRoot.runCmd(["brightnessctl", "set", "5%-"]);
                                        }
                                        statusProc.running = true;
                                    }
                                }
                            }

                            // Network status
                            RowLayout {
                                spacing: 4

                                Text {
                                    text: shellRoot.networkName !== "" ? "󰤨" : "󰤭"
                                    color: shellRoot.networkName !== "" ? theme.successColor : theme.subFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }

                                Text {
                                    visible: shellRoot.networkName !== ""
                                    Layout.maximumWidth: 90
                                    elide: Text.ElideRight
                                    text: shellRoot.networkName
                                    color: theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: shellRoot.runCmd(["nm-connection-editor"])
                                }
                            }

                            // Battery (when present)
                            RowLayout {
                                visible: shellRoot.batteryPercent >= 0
                                spacing: 4

                                Text {
                                    text: shellRoot.batteryStatus === "Charging" ? "󰂄" : "󰁹"
                                    color: shellRoot.batteryStatus === "Charging"
                                        ? theme.successColor
                                        : (shellRoot.batteryPercent <= 20 ? theme.dangerColor : theme.actBg)
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }

                                Text {
                                    text: shellRoot.batteryPercent + "%"
                                    color: theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                        }
                    }

                    // 4. AniDE Quick Control Dock (Theme, Wallpaper, Keybinds, Night Light, Settings)
                    Rectangle {
                        implicitHeight: 28
                        implicitWidth: dockRow.implicitWidth + 12
                        radius: 14
                        color: theme.surfaceBg
                        border.width: 1
                        border.color: Qt.alpha(theme.borderColor, 0.8)

                        RowLayout {
                            id: dockRow
                            anchors.centerIn: parent
                            spacing: 4

                            Repeater {
                                model: [
                                    { icon: "󰸌", cmd: ["hyde-shell", "app", "-t", "scope", "--", "theme.select.sh"] },
                                    { icon: "󰸉", cmd: ["hyde-shell", "wallpaper", "--select", "--global"] },
                                    { icon: "󰌌", cmd: ["hyde-shell", "keybinds_hint"] },
                                    { icon: "󰖔", cmd: ["hyde-shell", "hyprsunset", "--toggle"] },
                                    { icon: "󰒓", cmd: ["hyde-shell", "anide-settings"] }
                                ]

                                Rectangle {
                                    required property var modelData
                                    implicitWidth: 24
                                    implicitHeight: 22
                                    radius: 11
                                    color: dockMouse.containsMouse ? Qt.alpha(theme.actBg, 0.22) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.modelData.icon
                                        color: dockMouse.containsMouse ? theme.actBg : theme.mainFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                    }

                                    MouseArea {
                                        id: dockMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: shellRoot.runCmd(parent.modelData.cmd)
                                    }
                                }
                            }
                        }
                    }

                    // 5. Power / Logout Orb
                    Rectangle {
                        implicitWidth: 30
                        implicitHeight: 28
                        radius: 14
                        color: powerMouse.containsMouse
                            ? theme.dangerColor
                            : Qt.alpha(theme.dangerColor, 0.18)
                        border.width: 1
                        border.color: Qt.alpha(theme.dangerColor, 0.45)

                        Text {
                            anchors.centerIn: parent
                            text: "⏻"
                            color: powerMouse.containsMouse ? theme.actFg : theme.dangerColor
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.bold: true
                        }

                        MouseArea {
                            id: powerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: shellRoot.runCmd(["hyde-shell", "logoutlaunch", "1"])
                        }
                    }
                }
            }

            // ── Top-Left & Top-Right Concave Inverted Corners ("bo góc lõm sát mép trên") ──
            RoundCorner {
                anchors {
                    top: barContainer.bottom
                    left: parent.left
                }
                corner: "top-left"
                cornerSize: barWindow.cornerSize
                fillColor: theme.barBg
            }

            RoundCorner {
                anchors {
                    top: barContainer.bottom
                    right: parent.right
                }
                corner: "top-right"
                cornerSize: barWindow.cornerSize
                fillColor: theme.barBg
            }
        }
    }

    // ── BOTTOM SCREEN CONCAVE CORNERS (completes the 4-corner Illogical Impulse screen frame) ──
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

            // Empty input mask so the bottom corners are 100% click-through
            mask: Region {}

            RoundCorner {
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                }
                corner: "bottom-left"
                cornerSize: bottomCornerWindow.cornerSize
                fillColor: theme.barBg
            }

            RoundCorner {
                anchors {
                    bottom: parent.bottom
                    right: parent.right
                }
                corner: "bottom-right"
                cornerSize: bottomCornerWindow.cornerSize
                fillColor: theme.barBg
            }
        }
    }
}
