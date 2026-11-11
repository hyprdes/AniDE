// AniDE Quickshell Top Bar — Illogical Impulse / end-4 concave top-edge style
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

    property string clockText: Qt.formatDateTime(new Date(), "HH:mm  •  ddd, dd/MM")
    property int volumeLevel: 0
    property bool volumeMuted: false
    property int batteryPercent: -1
    property string batteryStatus: ""
    property string networkName: ""

    function runCmd(args) {
        Quickshell.execDetached(args);
    }

    // Load Wallbash theme.json dynamically
    FileView {
        id: themeFile
        path: Quickshell.env("XDG_CONFIG_HOME")
            ? (Quickshell.env("XDG_CONFIG_HOME") + "/quickshell/theme.json")
            : ((Quickshell.env("HOME") || "") + "/.config/quickshell/theme.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: theme.applyJson(text())
    }

    // Clock & system status polling
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            shellRoot.clockText = Qt.formatDateTime(new Date(), "HH:mm  •  ddd, dd/MM");
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
            "bat=-1; bstat=''; " +
            "for b in /sys/class/power_supply/BAT*; do " +
            "  if [ -r \"$b/capacity\" ]; then bat=$(cat \"$b/capacity\"); bstat=$(cat \"$b/status\" 2>/dev/null); break; fi; " +
            "done; " +
            "net=$(nmcli -t -f NAME connection show --active 2>/dev/null | head -n1); " +
            "printf '%s|%s|%s|%s|%s\\n' \"$vol\" \"$mute\" \"$bat\" \"$bstat\" \"$net\""
        ]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|");
                if (parts.length >= 5) {
                    shellRoot.volumeLevel = parseInt(parts[0], 10) || 0;
                    shellRoot.volumeMuted = (parts[1] === "true");
                    shellRoot.batteryPercent = parseInt(parts[2], 10);
                    shellRoot.batteryStatus = parts[3] || "";
                    shellRoot.networkName = parts[4] || "";
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData

            readonly property int barHeight: 38
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

            // Input mask restricted to the top bar so clicks in the concave corner area pass through to windows
            mask: Region {
                item: barContainer
            }

            // Top flush bar background matching system background/border color (@main-bg)
            Rectangle {
                id: barContainer
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: barWindow.barHeight
                color: theme.barBg

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                    }
                    spacing: 8

                    // ── LEFT: App Launcher + Workspaces + Active Window ──
                    RowLayout {
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        spacing: 6

                        // Launcher pill
                        Rectangle {
                            implicitWidth: 32
                            implicitHeight: 28
                            radius: 14
                            color: launcherMouse.containsMouse ? theme.hvrBg : theme.surfaceBg
                            border.width: 1
                            border.color: theme.borderColor

                            Text {
                                anchors.centerIn: parent
                                text: ""
                                color: theme.actBg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 15
                            }

                            MouseArea {
                                id: launcherMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: shellRoot.runCmd(["hyde-shell", "rofilaunch", "d"])
                            }
                        }

                        // Hyprland Workspaces pill
                        Rectangle {
                            implicitHeight: 28
                            implicitWidth: wsRow.implicitWidth + 14
                            radius: 14
                            color: theme.surfaceBg
                            border.width: 1
                            border.color: theme.borderColor

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

                                        implicitWidth: isFocused ? 28 : 18
                                        implicitHeight: 18
                                        radius: 9
                                        color: isFocused
                                            ? theme.actBg
                                            : (wsMouse.containsMouse ? theme.hvrBg : (isOccupied ? Qt.rgba(1, 1, 1, 0.12) : "transparent"))

                                        Behavior on implicitWidth {
                                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: parent.wsId.toString()
                                            color: parent.isFocused ? theme.actFg : (parent.isOccupied ? theme.mainFg : theme.subFg)
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            font.bold: parent.isFocused
                                        }

                                        MouseArea {
                                            id: wsMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Hyprland.dispatch("workspace " + parent.wsId)
                                        }
                                    }
                                }
                            }
                        }

                        // Active Window Title
                        Text {
                            Layout.maximumWidth: 280
                            elide: Text.ElideRight
                            text: (Hyprland.activeToplevel && Hyprland.activeToplevel.title)
                                ? Hyprland.activeToplevel.title
                                : "AniDE"
                            color: theme.subFg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // ── CENTER: Media (MPRIS) + Clock ──
                    RowLayout {
                        Layout.alignment: Qt.AlignCenter
                        spacing: 6

                        // MPRIS Media Pill
                        Rectangle {
                            readonly property var activePlayer: (Mpris.players && Mpris.players.values && Mpris.players.values.length > 0)
                                ? Mpris.players.values[0]
                                : null
                            visible: activePlayer !== null && activePlayer.trackTitle !== ""
                            implicitHeight: 28
                            implicitWidth: Math.min(mprisLabel.implicitWidth + 24, 240)
                            radius: 14
                            color: mprisMouse.containsMouse ? theme.hvrBg : theme.surfaceBg
                            border.width: 1
                            border.color: theme.borderColor

                            Text {
                                id: mprisLabel
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 12
                                    rightMargin: 12
                                }
                                elide: Text.ElideRight
                                text: parent.activePlayer
                                    ? ((parent.activePlayer.isPlaying ? "  " : "  ") + parent.activePlayer.trackTitle)
                                    : ""
                                color: theme.mainFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: mprisMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        shellRoot.runCmd(["hyde-shell", "rofi.movie"]);
                                    } else if (parent.activePlayer) {
                                        parent.activePlayer.togglePlaying();
                                    }
                                }
                            }
                        }

                        // Clock Pill
                        Rectangle {
                            implicitHeight: 28
                            implicitWidth: clockLabel.implicitWidth + 24
                            radius: 14
                            color: theme.surfaceBg
                            border.width: 1
                            border.color: theme.borderColor

                            Text {
                                id: clockLabel
                                anchors.centerIn: parent
                                text: "  " + shellRoot.clockText
                                color: theme.mainFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // ── RIGHT: AniDE Quick Actions + System Status ──
                    RowLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        spacing: 6

                        // AniDE Quick Action Pill (Theme, Wallpaper, Movie/AniSub, Keybinds, Settings)
                        Rectangle {
                            implicitHeight: 28
                            implicitWidth: quickRow.implicitWidth + 16
                            radius: 14
                            color: theme.surfaceBg
                            border.width: 1
                            border.color: theme.borderColor

                            RowLayout {
                                id: quickRow
                                anchors.centerIn: parent
                                spacing: 4

                                Repeater {
                                    model: [
                                        { icon: "", cmd: ["hyde-shell", "app", "-t", "scope", "--", "theme.select.sh"] },
                                        { icon: "", cmd: ["hyde-shell", "wallpaper", "--select", "--global"] },
                                        { icon: "󰿎", cmd: ["hyde-shell", "rofi.movie"] },
                                        { icon: "", cmd: ["hyde-shell", "keybinds_hint"] },
                                        { icon: "", cmd: ["hyde-shell", "anide-settings"] }
                                    ]

                                    Rectangle {
                                        required property var modelData
                                        implicitWidth: 24
                                        implicitHeight: 22
                                        radius: 11
                                        color: actionMouse.containsMouse ? theme.hvrBg : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: parent.modelData.icon
                                            color: actionMouse.containsMouse ? theme.actBg : theme.mainFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 13
                                        }

                                        MouseArea {
                                            id: actionMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: shellRoot.runCmd(parent.modelData.cmd)
                                        }
                                    }
                                }
                            }
                        }

                        // System Tray Pill
                        Rectangle {
                            visible: SystemTray.items && SystemTray.items.values && SystemTray.items.values.length > 0
                            implicitHeight: 28
                            implicitWidth: trayRow.implicitWidth + 14
                            radius: 14
                            color: theme.surfaceBg
                            border.width: 1
                            border.color: theme.borderColor

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
                                            width: 16
                                            height: 16
                                            source: parent.modelData.icon || ""
                                            sourceSize.width: 16
                                            sourceSize.height: 16
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

                        // System Status Pill (Network, Audio, Battery, Power)
                        Rectangle {
                            implicitHeight: 28
                            implicitWidth: sysRow.implicitWidth + 20
                            radius: 14
                            color: theme.surfaceBg
                            border.width: 1
                            border.color: theme.borderColor

                            RowLayout {
                                id: sysRow
                                anchors.centerIn: parent
                                spacing: 10

                                // Network
                                Text {
                                    text: shellRoot.networkName !== "" ? ("󰤨 " + shellRoot.networkName) : "󰤭"
                                    color: theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: shellRoot.runCmd(["nm-connection-editor"])
                                    }
                                }

                                // Audio Volume
                                Text {
                                    text: (shellRoot.volumeMuted ? "󰝟 " : "󰕾 ") + shellRoot.volumeLevel + "%"
                                    color: shellRoot.volumeMuted ? theme.subFg : theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12

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

                                // Battery (if present)
                                Text {
                                    visible: shellRoot.batteryPercent >= 0
                                    text: (shellRoot.batteryStatus === "Charging" ? "󰂄 " : "󰁹 ") + shellRoot.batteryPercent + "%"
                                    color: theme.mainFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                }

                                // Power / Logout button
                                Text {
                                    text: ""
                                    color: theme.actBg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: shellRoot.runCmd(["hyde-shell", "logoutlaunch", "1"])
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Concave Inverted Corners ("bo góc lõm sát mép trên" / end-4 style) ──
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
}
