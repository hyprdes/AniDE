// AniDE Quickshell Bar — end-4 Illogical Impulse (ii) Rounded Layout + Dreamy Frosted Mist & Cyan Aura Glass
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

    property string timeText: Qt.formatDateTime(new Date(), "hh:mm")
    property string dateText: Qt.formatDateTime(new Date(), "ddd, dd/MM")
    property int volumeLevel: 0
    property bool volumeMuted: false
    property bool micMuted: false
    property int brightnessLevel: 100
    property real cpuUsage: 0.0      // 0.0 .. 1.0
    property real memoryUsage: 0.0   // 0.0 .. 1.0
    property real batteryLevel: -1.0 // -1 if no battery, else 0.0 .. 1.0
    property bool batteryCharging: false
    property string networkName: ""
    property bool bluetoothOn: false
    property bool bluetoothConnected: false
    property string kbLayout: "en"
    property string activeWinClass: ""
    property string activeWinTitle: ""

    function runCmd(args) {
        Quickshell.execDetached(args);
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
            shellRoot.timeText = Qt.formatDateTime(now, "hh:mm");
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
            "bton=$(bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2}' | head -n1); " +
            "btcon=$(bluetoothctl info 2>/dev/null | awk '/Connected:/ {print $2}' | head -n1); " +
            "wclass=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty' 2>/dev/null || true); " +
            "wtitle=$(hyprctl activewindow -j 2>/dev/null | jq -r '.title // empty' 2>/dev/null || true); " +
            "printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\\n' " +
            "\"$vol\" \"$mute\" \"$micm\" \"$br\" \"$cpu\" \"$ram\" \"$bat\" \"$bstat\" \"$net\" \"$bton\" \"$btcon\" \"$wclass\" \"$wtitle\""
        ]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|");
                if (parts.length >= 13) {
                    shellRoot.volumeLevel = parseInt(parts[0], 10) || 0;
                    shellRoot.volumeMuted = (parts[1] === "true");
                    shellRoot.micMuted = (parts[2] === "true");
                    shellRoot.brightnessLevel = parseInt(parts[3], 10) || 100;
                    var c = Math.max(0, Math.min(100, parseInt(parts[4], 10) || 0));
                    var r = Math.max(0, Math.min(100, parseInt(parts[5], 10) || 0));
                    shellRoot.cpuUsage = c / 100.0;
                    shellRoot.memoryUsage = r / 100.0;
                    var b = parseInt(parts[6], 10);
                    shellRoot.batteryLevel = (isNaN(b) || b < 0) ? -1.0 : (b / 100.0);
                    shellRoot.batteryCharging = (parts[7] === "Charging" || parts[7] === "Full");
                    shellRoot.networkName = parts[8] || "";
                    shellRoot.bluetoothOn = (parts[9] === "yes");
                    shellRoot.bluetoothConnected = (parts[10] === "yes");
                    shellRoot.activeWinClass = parts[11] || "";
                    shellRoot.activeWinTitle = parts[12] || "";
                }
            }
        }
    }

    // ── Reusable end-4 + Dreamy Frosted Mist Components ──

    // 0. DreamyMistCanvas: Renders soft radial cyan/accent mist clouds + fine frosted stipple grain inside rounded pills
    component DreamyMistCanvas: Canvas {
        id: mistCanvas
        property color glowPrimary: theme.glowColor
        property color glowSecondary: theme.glowSecondary
        property real mistIntensity: 0.30
        property real grainIntensity: 0.08
        property int seedOffset: 17

        anchors.fill: parent
        antialiasing: true
        smooth: true

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onGlowPrimaryChanged: requestPaint()
        onGlowSecondaryChanged: requestPaint()
        onMistIntensityChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (width <= 2 || height <= 2) return;

            var r = height / 2;

            // Clip strictly to the full stadium/capsule pill shape
            ctx.beginPath();
            ctx.moveTo(r, 0);
            ctx.lineTo(width - r, 0);
            ctx.arc(width - r, r, r, -Math.PI / 2, Math.PI / 2, false);
            ctx.lineTo(r, height);
            ctx.arc(r, r, r, Math.PI / 2, -Math.PI / 2, false);
            ctx.closePath();
            ctx.clip();

            // 1. Primary diagonal cyan/accent radial mist bloom (left-center, like the "profile" capsule in image-4)
            var gx1 = width * 0.28;
            var gy1 = height * 0.38;
            var gr1 = Math.max(width * 0.48, height * 1.35);
            var grad1 = ctx.createRadialGradient(gx1, gy1, 1, gx1, gy1, gr1);
            grad1.addColorStop(0.0, Qt.rgba(glowPrimary.r, glowPrimary.g, glowPrimary.b, mistIntensity));
            grad1.addColorStop(0.45, Qt.rgba(glowSecondary.r, glowSecondary.g, glowSecondary.b, mistIntensity * 0.48));
            grad1.addColorStop(1.0, Qt.rgba(glowPrimary.r, glowPrimary.g, glowPrimary.b, 0.0));
            ctx.fillStyle = grad1;
            ctx.fillRect(0, 0, width, height);

            // 2. Secondary dreamy counter-bloom (right-bottom soft mist)
            var gx2 = width * 0.76;
            var gy2 = height * 0.68;
            var gr2 = Math.max(width * 0.40, height * 1.15);
            var grad2 = ctx.createRadialGradient(gx2, gy2, 1, gx2, gy2, gr2);
            grad2.addColorStop(0.0, Qt.rgba(glowSecondary.r, glowSecondary.g, glowSecondary.b, mistIntensity * 0.65));
            grad2.addColorStop(0.55, Qt.rgba(glowPrimary.r, glowPrimary.g, glowPrimary.b, mistIntensity * 0.22));
            grad2.addColorStop(1.0, Qt.rgba(glowSecondary.r, glowSecondary.g, glowSecondary.b, 0.0));
            ctx.fillStyle = grad2;
            ctx.fillRect(0, 0, width, height);

            // 3. Soft top-edge frosty sheen
            var sheen = ctx.createLinearGradient(0, 0, 0, height * 0.55);
            sheen.addColorStop(0.0, Qt.rgba(1, 1, 1, 0.14));
            sheen.addColorStop(1.0, Qt.rgba(1, 1, 1, 0.0));
            ctx.fillStyle = sheen;
            ctx.fillRect(0, 0, width, height * 0.55);

            // 4. Deterministic frosted stipple / airbrush grain (like the stippled cyan glow in image-4)
            var dots = Math.min(180, Math.max(45, Math.floor((width * height) / 42)));
            var s = mistCanvas.seedOffset + Math.floor(width);
            for (var i = 0; i < dots; i++) {
                s = (s * 1103515245 + 12345) & 0x7fffffff;
                var px = (s % 1000) / 1000.0 * width;
                s = (s * 1103515245 + 12345) & 0x7fffffff;
                var py = (s % 1000) / 1000.0 * height;
                var useCyan = (i % 3 !== 0);
                var alpha = grainIntensity * (0.45 + ((s % 100) / 180.0));
                ctx.fillStyle = useCyan
                    ? Qt.rgba(glowSecondary.r, glowSecondary.g, glowSecondary.b, alpha)
                    : Qt.rgba(1.0, 1.0, 1.0, alpha * 0.85);
                ctx.fillRect(px, py, 1.25, 1.25);
            }
        }
    }

    // 1. end-4 BarGroup upgraded with Full Stadium Rounding + Dreamy Frosted Mist & Specular Glass Rim
    component BarGroup: Item {
        id: grpRoot
        property real padding: 10
        property real mistIntensity: 0.28
        property int seedOffset: 23
        default property alias items: grpRow.children
        implicitWidth: grpRow.implicitWidth + padding * 2
        implicitHeight: 42

        // Outer soft cyan ambient halo behind the capsule
        Rectangle {
            anchors {
                fill: pillBody
                margins: -2
            }
            radius: height / 2
            color: "transparent"
            border.width: 2
            border.color: Qt.alpha(theme.glowColor, 0.12)
        }

        // Main Frosted Obsidian-Cyan Pill Body (34px tall inside 42px bar -> full 17px stadium radius)
        Rectangle {
            id: pillBody
            anchors {
                fill: parent
                topMargin: 4
                bottomMargin: 4
            }
            radius: height / 2
            color: Qt.alpha(theme.surfaceBg, theme.pillOpacity)
            border.width: 1.2
            border.color: Qt.alpha(theme.borderColor, 0.36)

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.alpha(theme.surfaceBg, Math.min(0.92, theme.pillOpacity + 0.08)) }
                GradientStop { position: 0.5; color: Qt.alpha(theme.barBg, theme.pillOpacity) }
                GradientStop { position: 1.0; color: Qt.alpha(theme.surfaceBg, Math.min(0.92, theme.pillOpacity + 0.06)) }
            }

            DreamyMistCanvas {
                mistIntensity: grpRoot.mistIntensity
                seedOffset: grpRoot.seedOffset
            }

            // Crisp inner top specular rim highlight (like the white-silver capsule rim in image-4)
            Rectangle {
                anchors {
                    fill: parent
                    margins: 1
                }
                radius: height / 2
                color: "transparent"
                border.width: 0.8
                border.color: Qt.alpha("#ffffff", 0.18)
            }
        }

        RowLayout {
            id: grpRow
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                right: parent.right
                leftMargin: grpRoot.padding
                rightMargin: grpRoot.padding
            }
            spacing: 6
        }
    }

    // 2. end-4 CircularProgressWithIcon (Resource & Media progress ring with glowing cyan arc)
    component CircularResourceRing: Item {
        id: ringRoot
        property real value: 0.0 // 0.0 .. 1.0
        property string iconText: ""
        property color primaryColor: theme.actBg
        property color trackColor: Qt.alpha(theme.mainFg, 0.16)
        property int size: 20

        implicitWidth: size
        implicitHeight: size

        onValueChanged: ringCanvas.requestPaint()
        onPrimaryColorChanged: ringCanvas.requestPaint()

        Canvas {
            id: ringCanvas
            anchors.fill: parent
            antialiasing: true
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var cx = width / 2;
                var cy = height / 2;
                var r = (width / 2) - 2.2;

                // Track circle
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, Math.PI * 2, false);
                ctx.lineWidth = 2.2;
                ctx.strokeStyle = ringRoot.trackColor;
                ctx.stroke();

                // Soft glow + Value arc
                var clamped = Math.max(0.0, Math.min(1.0, ringRoot.value));
                if (clamped > 0.01) {
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + clamped * Math.PI * 2, false);
                    ctx.lineWidth = 3.8;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = Qt.rgba(ringRoot.primaryColor.r, ringRoot.primaryColor.g, ringRoot.primaryColor.b, 0.28);
                    ctx.stroke();

                    ctx.beginPath();
                    ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + clamped * Math.PI * 2, false);
                    ctx.lineWidth = 2.2;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = ringRoot.primaryColor;
                    ctx.stroke();
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: ringRoot.iconText
            color: theme.mainFg
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            font.bold: true
        }
    }

    // 3. end-4 CircleUtilButton (24x24 circular frosted glass micro-button inside rightCenterGroup)
    component CircleUtilButton: Rectangle {
        id: utilBtn
        property string iconText: ""
        signal triggered()

        implicitWidth: 24
        implicitHeight: 24
        radius: 12
        color: utilMouse.containsMouse
            ? Qt.alpha(theme.actBg, 0.28)
            : Qt.alpha(theme.layer2Bg, 0.78)
        border.width: 1
        border.color: utilMouse.containsMouse
            ? Qt.alpha(theme.borderColor, 0.65)
            : Qt.alpha("#ffffff", 0.16)

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }

        Text {
            anchors.centerIn: parent
            text: utilBtn.iconText
            color: utilMouse.containsMouse ? theme.hvrFg : theme.mainFg
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
        }

        MouseArea {
            id: utilMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: utilBtn.triggered()
        }
    }

    // ── TOP BAR WINDOW (end-4 Bar.qml + BarContent.qml with Frosted Glass Blur) ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "quickshell:bar"

            readonly property int barHeight: 42
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

            // BarContent (42px height, translucent obsidian-glass backdrop + subtle ambient mist)
            Rectangle {
                id: barContent
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: barWindow.barHeight
                color: Qt.alpha(theme.barBg, theme.barOpacity)

                // Subtle bottom luminous rim line connecting into the top-left & top-right RoundCorners
                Rectangle {
                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                    }
                    height: 1.2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.alpha(theme.borderColor, 0.28) }
                        GradientStop { position: 0.25; color: Qt.alpha("#ffffff", 0.14) }
                        GradientStop { position: 0.5; color: Qt.alpha(theme.glowColor, 0.34) }
                        GradientStop { position: 0.75; color: Qt.alpha("#ffffff", 0.14) }
                        GradientStop { position: 1.0; color: Qt.alpha(theme.borderColor, 0.28) }
                    }
                }

                // ── 1. LEFT SECTION (Frosted Distro Pill + Two-line ActiveWindow; scroll for Brightness) ──
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

                        // LeftSidebarButton: Frosted glowing circular capsule at leftMargin = screenRounding
                        Rectangle {
                            id: leftSidebarBtn
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: barWindow.cornerSize
                            implicitWidth: 34
                            implicitHeight: 34
                            radius: 17
                            color: leftBtnMouse.containsMouse
                                ? Qt.alpha(theme.actBg, 0.24)
                                : Qt.alpha(theme.surfaceBg, theme.pillOpacity)
                            border.width: 1.2
                            border.color: leftBtnMouse.containsMouse
                                ? Qt.alpha(theme.actBg, 0.75)
                                : Qt.alpha(theme.borderColor, 0.38)

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            DreamyMistCanvas {
                                mistIntensity: leftBtnMouse.containsMouse ? 0.42 : 0.26
                                seedOffset: 7
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰣇"
                                color: theme.mainFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 17
                            }

                            // Tiny cyan ping dot at bottom-right (like end-4 LeftSidebarButton + image-4 accent)
                            Rectangle {
                                anchors {
                                    bottom: parent.bottom
                                    right: parent.right
                                    bottomMargin: 2
                                    rightMargin: 2
                                }
                                width: 7
                                height: 7
                                radius: 3.5
                                color: theme.actBg
                                border.width: 1
                                border.color: theme.barBg
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

                        // end-4 ActiveWindow (Two-line stacked: small misty app class on top, crisp title on bottom)
                        ColumnLayout {
                            Layout.rightMargin: 12
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: -2

                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: shellRoot.activeWinClass !== ""
                                    ? ("#" + shellRoot.activeWinClass)
                                    : ((Hyprland.activeToplevel && Hyprland.activeToplevel.title) ? "#application" : "#AniDE • Desktop")
                                color: theme.actBg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
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

                // ── 2. MIDDLE SECTION (Three Rounded Dreamy Frosted BarGroup Capsules) ──
                Row {
                    id: middleSection
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        horizontalCenter: parent.horizontalCenter
                    }
                    spacing: 6

                    // 2A. Left-Center BarGroup: Resources (RAM + CPU glowing circular rings) + Media (MPRIS ring + track)
                    BarGroup {
                        id: leftCenterGroup
                        anchors.verticalCenter: parent.verticalCenter
                        padding: 11
                        mistIntensity: 0.28
                        seedOffset: 31

                        // RAM Resource
                        RowLayout {
                            spacing: 4
                            CircularResourceRing {
                                value: shellRoot.memoryUsage
                                iconText: ""
                                primaryColor: shellRoot.memoryUsage >= 0.85 ? theme.errorColor : theme.actBg
                            }
                            Text {
                                text: Math.round(shellRoot.memoryUsage * 100).toString() + "%"
                                color: theme.mainFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                        }

                        // CPU Resource
                        RowLayout {
                            Layout.leftMargin: 4
                            spacing: 4
                            CircularResourceRing {
                                value: shellRoot.cpuUsage
                                iconText: ""
                                primaryColor: shellRoot.cpuUsage >= 0.85 ? theme.errorColor : theme.glowSecondary
                            }
                            Text {
                                text: Math.round(shellRoot.cpuUsage * 100).toString() + "%"
                                color: theme.mainFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                        }

                        // Subtle vertical glass divider
                        Rectangle {
                            Layout.leftMargin: 2
                            Layout.rightMargin: 2
                            width: 1
                            height: 14
                            color: Qt.alpha("#ffffff", 0.16)
                        }

                        // Media (MPRIS / AniSub)
                        RowLayout {
                            id: mediaWidget
                            readonly property var activePlayer: (Mpris.players && Mpris.players.values && Mpris.players.values.length > 0)
                                ? Mpris.players.values[0]
                                : null
                            readonly property bool hasTrack: activePlayer !== null && activePlayer.trackTitle !== ""
                            spacing: 6

                            CircularResourceRing {
                                value: (mediaWidget.activePlayer && mediaWidget.activePlayer.length > 0)
                                    ? (mediaWidget.activePlayer.position / mediaWidget.activePlayer.length)
                                    : (mediaWidget.hasTrack && mediaWidget.activePlayer.isPlaying ? 0.65 : 0.35)
                                iconText: (mediaWidget.hasTrack && mediaWidget.activePlayer.isPlaying) ? "" : "󰎈"
                                primaryColor: theme.actBg
                            }

                            Text {
                                Layout.maximumWidth: 155
                                elide: Text.ElideRight
                                text: mediaWidget.hasTrack
                                    ? (mediaWidget.activePlayer.trackTitle + (mediaWidget.activePlayer.trackArtist ? (" • " + mediaWidget.activePlayer.trackArtist) : ""))
                                    : "AniSub • Phim"
                                color: theme.mainFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.weight: Font.Medium

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

                    // 2B. Middle-Center BarGroup: Workspaces with Connected Occupied Capsules + Dreamy Glowing Liquid Pill
                    BarGroup {
                        id: middleCenterGroup
                        anchors.verticalCenter: parent.verticalCenter
                        padding: 6
                        mistIntensity: 0.36
                        seedOffset: 73

                        Item {
                            id: wsContainer
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
                                var list = Hyprland.workspaces ? Hyprland.workspaces.values : [];
                                for (var i = 0; i < list.length; i++) {
                                    if (list[i].id === id) return true;
                                }
                                return false;
                            }

                            implicitWidth: wsBtnWidth * 10
                            implicitHeight: 34

                            WheelHandler {
                                onWheel: event => {
                                    if (event.angleDelta.y < 0) {
                                        Hyprland.dispatch("workspace r+1");
                                    } else if (event.angleDelta.y > 0) {
                                        Hyprland.dispatch("workspace r-1");
                                    }
                                }
                            }

                            // Layer 1: Connected Occupied Workspace Capsules (frosted glass pills stretching across occupied neighbors)
                            Repeater {
                                model: 10

                                Item {
                                    required property int index
                                    readonly property int wsId: index + 1
                                    readonly property bool curOcc: wsContainer.isWsOccupied(wsId)
                                    readonly property bool prevOcc: index > 0 && wsContainer.isWsOccupied(wsId - 1)
                                    readonly property bool nextOcc: index < 9 && wsContainer.isWsOccupied(wsId + 1)

                                    x: index * wsContainer.wsBtnWidth
                                    width: wsContainer.wsBtnWidth
                                    height: parent.height

                                    Rectangle {
                                        visible: parent.curOcc
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: parent.prevOcc ? -wsContainer.activeMargin : wsContainer.activeMargin
                                        width: wsContainer.activeSize
                                            + (parent.prevOcc ? wsContainer.activeMargin * 2 : 0)
                                            + (parent.nextOcc ? wsContainer.activeMargin * 2 : 0)
                                        height: wsContainer.activeSize
                                        radius: wsContainer.activeSize / 2
                                        color: Qt.alpha(theme.accentSecondary, 0.72)
                                        border.width: 1
                                        border.color: Qt.alpha(theme.borderColor, 0.22)
                                    }
                                }
                            }

                            // Layer 2A: Dreamy Cyan Aura Halo behind the Liquid Stretchy Active Indicator
                            Rectangle {
                                z: 1
                                anchors.verticalCenter: parent.verticalCenter
                                x: activeIndicator.x - 4
                                width: activeIndicator.width + 8
                                height: activeIndicator.height + 6
                                radius: height / 2
                                color: Qt.alpha(theme.glowColor, 0.28)
                                border.width: 1
                                border.color: Qt.alpha(theme.glowSecondary, 0.35)
                            }

                            // Layer 2B: Liquid Stretchy Active Indicator (TrailingIndicator with luminous cyan-ice gradient & rim)
                            Rectangle {
                                id: activeIndicator
                                z: 2
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.min(wsContainer.idx1, wsContainer.idx2) * wsContainer.wsBtnWidth + wsContainer.activeMargin
                                width: Math.abs(wsContainer.idx1 - wsContainer.idx2) * wsContainer.wsBtnWidth + wsContainer.activeSize
                                height: wsContainer.activeSize
                                radius: wsContainer.activeSize / 2
                                color: theme.actBg
                                border.width: 1.2
                                border.color: Qt.alpha("#ffffff", 0.72)

                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: theme.glowSecondary }
                                    GradientStop { position: 0.5; color: theme.actBg }
                                    GradientStop { position: 1.0; color: theme.glowColor }
                                }
                            }

                            // Layer 3: Workspace Numbers & Click Targets
                            Repeater {
                                model: 10

                                Item {
                                    required property int index
                                    readonly property int wsId: index + 1
                                    readonly property bool isActive: (barWindow.activeWsIndex === index)
                                    readonly property bool isOcc: wsContainer.isWsOccupied(wsId)

                                    z: 3
                                    x: index * wsContainer.wsBtnWidth
                                    width: wsContainer.wsBtnWidth
                                    height: parent.height

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: wsContainer.activeSize
                                        height: wsContainer.activeSize
                                        radius: wsContainer.activeSize / 2
                                        color: wsHit.containsMouse && !parent.isActive
                                            ? Qt.alpha(theme.actBg, 0.22)
                                            : "transparent"
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.wsId.toString()
                                        color: parent.isActive
                                            ? theme.actFg
                                            : (parent.isOcc ? theme.onSecondaryContainer : theme.subFg)
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        font.weight: parent.isActive ? Font.ExtraBold : Font.Medium
                                    }

                                    MouseArea {
                                        id: wsHit
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Hyprland.dispatch("workspace " + parent.wsId)
                                    }
                                }
                            }
                        }
                    }

                    // 2C. Right-Center BarGroup: ClockWidget + CircleUtilButtons + OneUI BatteryIndicator
                    BarGroup {
                        id: rightCenterGroup
                        anchors.verticalCenter: parent.verticalCenter
                        padding: 11
                        mistIntensity: 0.28
                        seedOffset: 109

                        // ClockWidget (Bold Time • Misty Date, styled like "2025" pill in image-4)
                        RowLayout {
                            spacing: 5

                            Text {
                                text: shellRoot.timeText
                                color: theme.mainFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }

                            Text {
                                text: "•"
                                color: theme.actBg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Text {
                                text: shellRoot.dateText
                                color: theme.onSecondaryContainer
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                        }

                        // Subtle vertical glass divider
                        Rectangle {
                            Layout.leftMargin: 2
                            Layout.rightMargin: 2
                            width: 1
                            height: 14
                            color: Qt.alpha("#ffffff", 0.16)
                        }

                        // end-4 UtilButtons (Circular 24x24 frosted buttons)
                        RowLayout {
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
                                iconText: "󰿎"
                                onTriggered: shellRoot.runCmd(["hyde-shell", "rofi.movie"])
                            }
                            CircleUtilButton {
                                iconText: "󰸉"
                                onTriggered: shellRoot.runCmd(["hyde-shell", "wallpaper", "--select", "--global"])
                            }
                            CircleUtilButton {
                                iconText: "󰖔"
                                onTriggered: shellRoot.runCmd(["hyde-shell", "hyprsunset", "--toggle"])
                            }
                        }

                        // end-4 OneUI-style ClippedProgressBar BatteryIndicator
                        Item {
                            visible: shellRoot.batteryLevel >= 0.0
                            Layout.leftMargin: 4
                            implicitWidth: 36
                            implicitHeight: 19

                            Rectangle {
                                anchors.fill: parent
                                radius: 9.5
                                color: Qt.alpha(theme.accentSecondary, 0.72)
                                border.width: 1
                                border.color: Qt.alpha(theme.borderColor, 0.42)
                                clip: true

                                Rectangle {
                                    width: Math.max(4, parent.width * Math.max(0.0, Math.min(1.0, shellRoot.batteryLevel)))
                                    height: parent.height
                                    radius: 9.5
                                    color: (shellRoot.batteryLevel <= 0.20 && !shellRoot.batteryCharging)
                                        ? theme.errorColor
                                        : theme.actBg
                                }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 1

                                    Text {
                                        visible: shellRoot.batteryCharging
                                        text: ""
                                        color: theme.actFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 9
                                    }

                                    Text {
                                        text: Math.round(Math.max(0, shellRoot.batteryLevel * 100)).toString()
                                        color: (shellRoot.batteryLevel >= 0.45) ? theme.actFg : theme.mainFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 3. RIGHT SECTION (SysTray + Frosted Right Status Pill; scroll for Volume) ──
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
                        spacing: 8

                        // RightSidebarButton status capsule (frosted pill with luminous rim at rightMargin = screenRounding)
                        Rectangle {
                            id: rightStatusPill
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            Layout.rightMargin: barWindow.cornerSize
                            implicitWidth: rightIndicators.implicitWidth + 24
                            implicitHeight: 34
                            radius: 17
                            color: Qt.alpha(theme.surfaceBg, theme.pillOpacity)
                            border.width: 1.2
                            border.color: rightSideArea.containsMouse
                                ? Qt.alpha(theme.actBg, 0.65)
                                : Qt.alpha(theme.borderColor, 0.38)

                            Behavior on border.color {
                                ColorAnimation { duration: 150 }
                            }

                            DreamyMistCanvas {
                                mistIntensity: rightSideArea.containsMouse ? 0.36 : 0.24
                                seedOffset: 151
                            }

                            RowLayout {
                                id: rightIndicators
                                anchors.centerIn: parent
                                spacing: 11

                                // Volume indicator (click mute, right-click pavucontrol)
                                RowLayout {
                                    spacing: 4
                                    Text {
                                        text: shellRoot.volumeMuted
                                            ? "󰝟"
                                            : (shellRoot.volumeLevel < 35 ? "󰕿" : (shellRoot.volumeLevel < 70 ? "󰖀" : "󰕾"))
                                        color: shellRoot.volumeMuted ? theme.errorColor : theme.actBg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 15
                                    }
                                    Text {
                                        text: shellRoot.volumeLevel + "%"
                                        color: theme.mainFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
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
                                }

                                // Mic mute indicator (auto-revealed when muted)
                                Text {
                                    visible: shellRoot.micMuted
                                    text: "󰍭"
                                    color: theme.errorColor
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 15
                                }

                                // Network indicator
                                Text {
                                    text: shellRoot.networkName !== "" ? "󰤨" : "󰤭"
                                    color: shellRoot.networkName !== "" ? theme.mainFg : theme.subFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 15

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: shellRoot.runCmd(["nm-connection-editor"])
                                    }
                                }

                                // Bluetooth indicator
                                Text {
                                    text: shellRoot.bluetoothConnected
                                        ? "󰂱"
                                        : (shellRoot.bluetoothOn ? "󰂯" : "󰂲")
                                    color: shellRoot.bluetoothConnected ? theme.actBg : theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 15

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: shellRoot.runCmd(["blueman-manager"])
                                    }
                                }

                                // AniDE Settings button
                                Text {
                                    text: "󰒓"
                                    color: theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 15

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: shellRoot.runCmd(["hyde-shell", "anide-settings"])
                                    }
                                }

                                // Session / Power button
                                Text {
                                    text: "⏻"
                                    color: theme.errorColor
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: shellRoot.runCmd(["hyde-shell", "logoutlaunch", "1"])
                                    }
                                }
                            }
                        }

                        // System Tray (to the left of the right status pill)
                        RowLayout {
                            visible: SystemTray.items && SystemTray.items.values && SystemTray.items.values.length > 0
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 6

                            Repeater {
                                model: SystemTray.items

                                Rectangle {
                                    required property var modelData
                                    implicitWidth: 24
                                    implicitHeight: 24
                                    radius: 12
                                    color: trayMouse.containsMouse
                                        ? Qt.alpha(theme.actBg, 0.24)
                                        : Qt.alpha(theme.surfaceBg, 0.55)
                                    border.width: 1
                                    border.color: Qt.alpha("#ffffff", 0.14)

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

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ── Top-Left & Top-Right Round Decorators (end-4 Bar.qml roundDecorators + luminous corner arc) ──
            RoundCorner {
                anchors {
                    top: barContent.bottom
                    left: parent.left
                }
                corner: "top-left"
                cornerSize: barWindow.cornerSize
                fillColor: Qt.alpha(theme.barBg, theme.barOpacity)
                strokeColor: Qt.alpha(theme.borderColor, 0.30)
            }

            RoundCorner {
                anchors {
                    top: barContent.bottom
                    right: parent.right
                }
                corner: "top-right"
                cornerSize: barWindow.cornerSize
                fillColor: Qt.alpha(theme.barBg, theme.barOpacity)
                strokeColor: Qt.alpha(theme.borderColor, 0.30)
            }
        }
    }

    // ── BOTTOM SCREEN CORNERS (end-4 ScreenCorners.qml + luminous corner arc) ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bottomCornerWindow
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "quickshell:screenCorners"

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
                fillColor: Qt.alpha(theme.barBg, theme.barOpacity)
                strokeColor: Qt.alpha(theme.borderColor, 0.30)
            }

            RoundCorner {
                anchors {
                    bottom: parent.bottom
                    right: parent.right
                }
                corner: "bottom-right"
                cornerSize: bottomCornerWindow.cornerSize
                fillColor: Qt.alpha(theme.barBg, theme.barOpacity)
                strokeColor: Qt.alpha(theme.borderColor, 0.30)
            }
        }
    }
}
