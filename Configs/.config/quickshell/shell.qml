// AniDE Quickshell Frame Bar & Draggable Desktop LED Dot-Matrix Clock Widget (image-1.png flat light frame + image-9.png clock widget)
// Frame: top edge + taskbar notch | side edges | bottom edge: launcher, workspace pill, resources+media | input pill under the title tab | clock+utils+battery, tray, status pill, bell, user
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

    // ── Draggable Desktop LED Dot-Matrix Clock Widget State (image-9.png, no background) ──
    property bool clockWidgetVisible: true
    property int clockWidgetX: 72
    property int clockWidgetY: 96
    property color clockLedColor: "#ffffff"
    property color clockBgColor: "transparent"
    property real clockBgOpacity: 0.0
    property real clockGlowIntensity: 0.88
    property bool clockUse12Hour: true
    property real clockScale: 1.0
    property bool clockSyncWallpaper: false
    property bool clockCustomizerOpen: false
    property int clockPaintTick: 0

    readonly property string clockConfigPath: Quickshell.env("XDG_CONFIG_HOME")
        ? (Quickshell.env("XDG_CONFIG_HOME") + "/quickshell/clock_widget.json")
        : ((Quickshell.env("HOME") || "") + "/.config/quickshell/clock_widget.json")

    // ── Frame layout state (image-1.png): taskbar in the notch, title tab, avatar ──
    readonly property string frameConfigPath: Quickshell.env("XDG_CONFIG_HOME")
        ? (Quickshell.env("XDG_CONFIG_HOME") + "/quickshell/frame.json")
        : ((Quickshell.env("HOME") || "") + "/.config/quickshell/frame.json")
    property string avatarUrl: ""
    readonly property string userInitial: String(Quickshell.env("USER") || "?").charAt(0).toUpperCase()

    // The focused window comes from the compositor's toplevel list (instant);
    // the polled hyprctl values stay as the fallback.
    readonly property var activeToplevel: ToplevelManager.activeToplevel
    readonly property bool hasActiveToplevel: activeToplevel ? activeToplevel.activated : false
    readonly property string focusAppId: hasActiveToplevel ? (activeToplevel.appId || "") : activeWinClass
    readonly property string focusTitle: hasActiveToplevel ? (activeToplevel.title || "") : activeWinTitle

    // App ids shown in the notch. Kept as one string so the Repeater model only
    // resets when the set of apps changes, not on every focus or title change.
    readonly property string taskAppKey: buildTaskAppKey()
    readonly property var taskAppIds: taskAppKey === "" ? [] : taskAppKey.split("\n")

    // ── AniSub panel (Win+Shift+M): KKPhim feed + search, drops from the top bar ──
    property bool anisubPanelOpen: false
    property int anisubPanelTop: 46
    property var anisubMovieItems: []
    property bool anisubMovieFeedLoading: false
    property double anisubMovieFeedAt: 0
    property var anisubMovieSearchItems: []
    property bool anisubMovieSearchLoading: false
    property var anisubMovieEpisodes: []
    property bool anisubMovieEpisodesLoading: false

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

    // name|info|slug|poster|type row -> item (null when the row is unusable)
    function anisubMovieItemFromLine(line) {
        if (!line) return null;
        var p = line.trim().split("|");
        if (p.length < 3 || !p[2]) return null;
        var poster = p[3] || "";
        if (poster !== "" && poster.indexOf("http") !== 0) {
            poster = "https://phimimg.com/" + poster.replace(/^\//, "");
        }
        return {
            name: p[0] || "Phim",
            info: p[1] || "",
            slug: p[2],
            poster: poster,
            thumb: poster
        };
    }

    function parseAnisubMovieLine(line) {
        var it = shellRoot.anisubMovieItemFromLine(line);
        if (it) shellRoot.anisubMovieItems = shellRoot.anisubMovieItems.concat([it]).slice(0, 6);
    }

    function parseAnisubMovieSearchLine(line) {
        var it = shellRoot.anisubMovieItemFromLine(line);
        if (it) shellRoot.anisubMovieSearchItems = shellRoot.anisubMovieSearchItems.concat([it]).slice(0, 6);
    }

    // name|url|slug|cover row -> item (null when the row is unusable)
    // name|server|number row -> episode (the widget never opens rofi for episodes)
    function parseAnisubEpisodeLine(line) {
        if (!line) return;
        var p = line.trim().split("|");
        if (p.length < 3 || !p[2]) return;
        if (shellRoot.anisubMovieEpisodes.length >= 300) return;
        shellRoot.anisubMovieEpisodes = shellRoot.anisubMovieEpisodes.concat([{
            name: p[0] || "Tập",
            server: p[1] || "0",
            num: p[2]
        }]);
    }

    function anisubMovieLoadEpisodes(film) {
        if (!film || !film.slug) return;
        anisubMovieEpisodesProc.running = false;
        shellRoot.anisubMovieEpisodes = [];
        shellRoot.anisubMovieEpisodesLoading = true;
        anisubMovieEpisodesProc.command = ["hyde-shell", "rofi.movie", "episodes", film.slug];
        anisubMovieEpisodesProc.running = true;
    }

    function anisubMoviePlayEpisode(film, ep) {
        if (!film || !film.slug || !ep) return;
        shellRoot.runCmd(["hyde-shell", "rofi.movie", "play-episode", film.slug, ep.server, ep.num]);
    }

    // Feed refresh: runs `rofi.movie feed` (no rofi UI)
    function refreshAnisubFeed() {
        anisubMovieItems = [];
        anisubMovieFeedLoading = true;
        anisubMovieFeedAt = Date.now();
        anisubMovieProc.running = true;
    }

    // Search on the panel: runs `rofi.movie feed-search <keyword>` (no rofi UI)
    function anisubPanelSearch(query) {
        var q = String(query || "").trim();
        anisubMovieSearchProc.running = false;
        anisubMovieSearchItems = [];
        anisubMovieSearchLoading = true;
        anisubMovieSearchProc.command = ["hyde-shell", "rofi.movie", "feed-search", q];
        anisubMovieSearchProc.running = true;
    }

    function anisubPanelSearchClear() {
        anisubMovieSearchProc.running = false;
        anisubMovieSearchItems = [];
        anisubMovieSearchLoading = false;
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

    function toplevelList() {
        var m = ToplevelManager.toplevels;
        return (m && m.values) ? m.values : [];
    }

    // Pinned apps first (frame.json "pinnedApps"), then every running app once
    function buildTaskAppKey() {
        var ids = [];
        var seen = {};
        var pinned = theme.pinnedApps || [];
        for (var i = 0; i < pinned.length; i++) {
            var p = String(pinned[i] || "");
            if (p !== "" && !seen[p.toLowerCase()]) {
                seen[p.toLowerCase()] = true;
                ids.push(p);
            }
        }
        var list = shellRoot.toplevelList();
        for (var j = 0; j < list.length; j++) {
            var id = list[j] ? String(list[j].appId || "") : "";
            if (id !== "" && !seen[id.toLowerCase()]) {
                seen[id.toLowerCase()] = true;
                ids.push(id);
            }
        }
        return ids.join("\n");
    }

    function toplevelsFor(appId) {
        var out = [];
        var want = String(appId || "").toLowerCase();
        var list = shellRoot.toplevelList();
        for (var i = 0; i < list.length; i++) {
            if (list[i] && String(list[i].appId || "").toLowerCase() === want) out.push(list[i]);
        }
        return out;
    }

    function anyActivated(wins) {
        for (var i = 0; i < wins.length; i++) {
            if (wins[i].activated) return true;
        }
        return false;
    }

    function desktopEntryFor(appId) {
        if (!appId) return null;
        // Reading the model length re-runs icon bindings once the .desktop scan is done
        var apps = DesktopEntries.applications;
        var known = (apps && apps.values) ? apps.values.length : 0;
        var entry = DesktopEntries.heuristicLookup(appId);
        return (known >= 0 && entry) ? entry : null;
    }

    // Themed icon for an app id; "" when the icon theme has none (callers fall back to a glyph)
    function appIconSource(appId) {
        if (!appId) return "";
        var entry = shellRoot.desktopEntryFor(appId);
        var name = (entry && entry.icon) ? String(entry.icon) : String(appId);
        if (name.charAt(0) === "/") return "file://" + name;
        return Quickshell.iconPath(name, true);
    }

    // Click on a taskbar icon: focus the app; click again to walk through its windows.
    // A pinned app that is not running gets started.
    function taskActivate(appId, wins) {
        if (wins.length === 0) {
            var entry = shellRoot.desktopEntryFor(appId);
            if (entry) entry.execute();
            return;
        }
        var current = -1;
        for (var i = 0; i < wins.length; i++) {
            if (wins[i].activated) current = i;
        }
        wins[(current + 1) % wins.length].activate();
    }

    // Middle click on a taskbar icon: close the app's focused window (or its first one)
    function taskClose(wins) {
        if (wins.length === 0) return;
        var target = wins[0];
        for (var i = 0; i < wins.length; i++) {
            if (wins[i].activated) target = wins[i];
        }
        target.close();
    }

    // Wallpaper dominant-tone sampler (end-4 style): the bar palette derives
    // from the wallpaper image itself, so the sync works even without wallbash.
    Image {
        id: wallSamplerSource
        width: 16
        height: 16
        opacity: 0
        source: shellRoot.wallBlurUrl
        sourceSize: Qt.size(16, 16)
        asynchronous: true
        cache: false
        property bool readyForSample: false
        onStatusChanged: {
            readyForSample = (status === Image.Ready);
            if (readyForSample) wallSampler.requestPaint();
        }
    }
    Canvas {
        id: wallSampler
        width: 16
        height: 16
        opacity: 0
        onPaint: {
            if (!wallSamplerSource.readyForSample) return;
            if (theme.wallSyncSource === "dcol") return;
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, 16, 16);
            ctx.drawImage(wallSamplerSource, 0, 0, 16, 16);
            var d = ctx.getImageData(0, 0, 16, 16).data;
            var r = 0, g = 0, b = 0, count = 0;
            for (var i = 0; i < d.length; i += 4) {
                r += d[i]; g += d[i + 1]; b += d[i + 2];
                count++;
            }
            if (count > 0) {
                theme.wallSyncSource = "image";
                theme.syncWallTone(r / count / 255, g / count / 255, b / count / 255);
                shellRoot.paintGeneration += 1;
            }
        }
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

    // Live frame.json hot-reload (user-owned frame switches: colors, scale, pinned apps)
    FileView {
        id: frameConfigFile
        path: shellRoot.frameConfigPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: theme.applyFrameJson(text())
    }

    // Avatar of the workspace pill: the first readable of ~/.face.icon, ~/.face
    Process {
        id: avatarProbe
        running: true
        command: [
            "sh", "-c",
            "for f in \"$HOME/.face.icon\" \"$HOME/.face\"; do " +
            "if [ -r \"$f\" ]; then printf '%s\\n' \"$f\"; break; fi; done"
        ]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim();
                if (p !== "") shellRoot.avatarUrl = "file://" + p;
            }
        }
    }

    // AniSub panel feed (KKPhim rows via rofi.movie feed)
    Process {
        id: anisubMovieProc
        command: ["hyde-shell", "rofi.movie", "feed"]
        stdout: SplitParser {
            onRead: data => shellRoot.parseAnisubMovieLine(data)
        }
        onRunningChanged: if (!running) shellRoot.anisubMovieFeedLoading = false
    }

    Process {
        id: anisubMovieSearchProc
        stdout: SplitParser {
            onRead: data => shellRoot.parseAnisubMovieSearchLine(data)
        }
        onRunningChanged: if (!running) shellRoot.anisubMovieSearchLoading = false
    }

    Process {
        id: anisubMovieEpisodesProc
        stdout: SplitParser {
            onRead: data => shellRoot.parseAnisubEpisodeLine(data)
        }
        onRunningChanged: if (!running) shellRoot.anisubMovieEpisodesLoading = false
    }

    // AniSub panel feed: refreshed every 10 minutes while the panel is open
    Timer {
        interval: 600000
        running: shellRoot.anisubPanelOpen
        repeat: true
        onTriggered: shellRoot.refreshAnisubFeed()
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
                            // The bar takes the wallpaper tone itself (same rule as the sampler)
                            var wc = Qt.color(theme.normHex(dc[0]));
                            theme.syncWallTone(wc.r, wc.g, wc.b);
                            if (dc[6]) {
                                theme.glowColor = Qt.color(theme.normHex(dc[6]));
                                shellRoot.wallDynamicHex = theme.normHex(dc[6]);
                                if (shellRoot.clockSyncWallpaper && shellRoot.wallDynamicHex !== "") {
                                    shellRoot.clockLedColor = Qt.color(shellRoot.wallDynamicHex);
                                    shellRoot.clockPaintTick += 1;
                                }
                            }
                            theme.wallSyncSource = "dcol";
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

            // 1. Flat paper capsule fill (LOOSE print: solid ink, no glass)
            ctx.beginPath();
            ctx.moveTo(inset + ri, inset);
            ctx.lineTo(width - inset - ri, inset);
            ctx.arc(width - inset - ri, height / 2, ri, -Math.PI / 2, Math.PI / 2, false);
            ctx.lineTo(inset + ri, height - inset);
            ctx.arc(inset + ri, height / 2, ri, Math.PI / 2, -Math.PI / 2, false);
            ctx.closePath();
            ctx.fillStyle = shellRoot.cssRgba(baseColor, baseOpacity);
            ctx.fill();

            // 2. Subtle halftone print dots (image-13 linen texture)
            ctx.save();
            ctx.clip();
            ctx.fillStyle = "rgba(20, 40, 16, 0.07)";
            var step = 6;
            for (var rowY = step / 2; rowY < height; rowY += step) {
                var xoff = (Math.round(rowY / step) % 2 === 0) ? step / 2 : 0;
                for (var dotX = xoff + step / 2; dotX < width; dotX += step) {
                    ctx.beginPath();
                    ctx.arc(dotX, rowY, 1.15, 0, Math.PI * 2);
                    ctx.fill();
                }
            }
            ctx.restore();
        }
    }

    // 1. BarGroup: flat white pill grouping related modules (image-1.png). When the
    //    frame follows the wallpaper it gets its outline and print texture back.
    component BarGroup: Rectangle {
        id: grpRoot
        property real padding: 4
        // plain: no capsule of its own
        property bool plain: false
        width: implicitWidth
        height: 30
        radius: height / 2
        color: plain ? "transparent" : theme.framePill
        border.width: (plain || !theme.followWallpaper) ? 0 : 2
        border.color: theme.borderColor

        DreamyMistCanvas {
            anchors.fill: parent
            visible: !grpRoot.plain && theme.followWallpaper
            baseColor: theme.surfaceBg
            baseOpacity: theme.barOpacity
        }
    }

    // 2. CircularResourceRing: Clean Frosted Ice-Silver Circular Progress Ring (18x18) sitting directly on the glass
    component CircularResourceRing: Item {
        id: ringRoot
        property real value: 0.0 // 0.0 .. 1.0
        property string iconText: "󰍛"
        property color primaryColor: theme.frameInk
        property color trackColor: theme.frameIndicator
        property int size: 16

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
            font.pixelSize: Math.max(8, Math.round(ringRoot.size * 0.5))
        }
    }

    // 3. Frame layout pieces (image-1.png)

    // FrameExclusion: 1px invisible layer surface that only reserves room for one
    // frame edge. The frame is drawn by one full-screen window instead, so the
    // order in which the compositor arranges these four surfaces never shows.
    component FrameExclusion: PanelWindow {
        color: "transparent"
        implicitWidth: 1
        implicitHeight: 1
        mask: Region {}
    }

    // FrameLabel / FrameGlyph: small near-black sans text and Nerd Font glyphs
    component FrameLabel: Text {
        color: theme.frameInk
        font.family: theme.frameFont
        elide: Text.ElideRight
    }

    component FrameGlyph: Text {
        color: theme.frameInk
        font.family: theme.frameGlyphFont
    }

    component FrameSeparator: Rectangle {
        width: 1
        height: 12
        color: Qt.alpha(theme.frameInk, 0.14)
    }

    // FrameButton: CircleUtilButton preset for the frame. Flat thin glyph by
    // default; the glass icon again when the frame follows the wallpaper.
    component FrameButton: CircleUtilButton {
        flat: !theme.followWallpaper
        flatPlateColor: theme.framePill
        flatHoverColor: theme.frameHover
        glyphFont: theme.frameGlyphFont
        iconPlateColor: theme.framePill
        iconInkColor: theme.frameInk
        accentColor: theme.frameAccentA
    }

    // 6. DesktopClockCanvas: 5x7 Rounded-Square LED Dot-Matrix Clock Renderer (exact match to image-9.png)
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

    // ── FRAME LAYOUT (image-1.png): flat light frame on all four screen edges ──
    // top edge + notch (taskbar) | side edges | bottom edge: launcher "+", workspace pill,
    // resources + media | input pill under the title tab | clock + utils + battery, tray,
    // status pill, bell, user. Sizes derive from the screen, so the proportions of the
    // 918x522 reference hold on any resolution (see the frame* tokens in Colors.qml).
    Variants {
        model: Quickshell.screens

        Scope {
            id: frameScope
            required property var modelData

            // u: one reference-image pixel on this screen (2.1 px on 1920x1080)
            readonly property real u: (modelData.height / 515) * theme.frameScale
            readonly property int topH: Math.round(modelData.height * theme.frameTopRatio * theme.frameScale)
            readonly property int sideW: Math.round(modelData.width * theme.frameSideRatio * theme.frameScale)
            readonly property int bottomH: Math.round(modelData.height * theme.frameBottomRatio * theme.frameScale)
            readonly property int radius: frameScope.px(20)       // desktop area corner radius
            readonly property int notchDepth: frameScope.px(23)   // notch, below the top edge
            readonly property int tabRise: frameScope.px(17)      // title tab, above the bottom edge
            readonly property int pillH: frameScope.px(15)
            readonly property int circleS: frameScope.px(14)      // "+", bell and user circles
            readonly property int inputH: frameScope.px(18)
            readonly property int inputW: frameScope.px(136)      // input pill and title pill
            readonly property int btnS: pillH - 6      // glyph buttons inside a pill
            readonly property int iconPx: frameScope.px(15)       // taskbar icons
            readonly property int fontPx: Math.max(10, px(5.6))
            readonly property int gap: frameScope.px(4)

            // Space kept free for windows. The notch and the tab hang over the
            // desktop area, so their depth is reserved too (frameReserveNotch/Tab).
            readonly property int zoneTop: topH + (theme.frameReserveNotch ? notchDepth : 0)
            readonly property int zoneBottom: bottomH + (theme.frameReserveTab ? tabRise : 0)
            readonly property int zoneSide: sideW + theme.framePad

            readonly property int activeWsId: (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace)
                ? Hyprland.focusedMonitor.activeWorkspace.id
                : 1
            readonly property int activeWsIndex: Math.max(0, Math.min(9, ((activeWsId - 1) % 10)))
            readonly property int bankOffset: activeWsIndex >= 5 ? 5 : 0
            readonly property int localOrbIndex: activeWsIndex - bankOffset

            function px(n) {
                return Math.round(n * u);
            }

            function isWsOccupied(id) {
                if (shellRoot.wsClasses && shellRoot.wsClasses[id.toString()]) return true;
                var list = Hyprland.workspaces ? Hyprland.workspaces.values : [];
                for (var i = 0; i < list.length; i++) {
                    if (list[i].id === id) return true;
                }
                return false;
            }

            // Bar-style anchors (one edge + both neighbours): the layout every
            // compositor honours an exclusive zone for
            FrameExclusion {
                screen: frameScope.modelData
                anchors {
                    top: true
                    left: true
                    right: true
                }
                exclusiveZone: frameScope.zoneTop
            }

            FrameExclusion {
                screen: frameScope.modelData
                anchors {
                    bottom: true
                    left: true
                    right: true
                }
                exclusiveZone: frameScope.zoneBottom
            }

            FrameExclusion {
                screen: frameScope.modelData
                anchors {
                    left: true
                    top: true
                    bottom: true
                }
                exclusiveZone: frameScope.zoneSide
            }

            FrameExclusion {
                screen: frameScope.modelData
                anchors {
                    right: true
                    top: true
                    bottom: true
                }
                exclusiveZone: frameScope.zoneSide
            }

            PanelWindow {
                id: frameWindow
                screen: frameScope.modelData

                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }

                // Ignore: this window covers the whole output and reserves nothing
                // itself; the four FrameExclusion surfaces above do the reserving.
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"

                // Clicks land on the frame, the notch and the tab only; the
                // desktop area in the middle stays click-through.
                mask: Region {
                    regions: [
                        Region { item: frameTopEdge },
                        Region { item: frameBottomEdge },
                        Region { item: frameLeftEdge },
                        Region { item: frameRightEdge },
                        Region { item: middleSection },
                        Region { item: titleTab }
                    ]
                }

                // ── Frame body: four flat strips, no shadow, no outline ──
                Rectangle {
                    id: frameTopEdge
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                    height: frameScope.topH
                    color: Qt.alpha(theme.frameBg, theme.frameOpacity)
                }

                Rectangle {
                    id: frameBottomEdge
                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                    }
                    height: frameScope.bottomH
                    color: Qt.alpha(theme.frameBg, theme.frameOpacity)
                }

                Rectangle {
                    id: frameLeftEdge
                    anchors {
                        top: frameTopEdge.bottom
                        bottom: frameBottomEdge.top
                        left: parent.left
                    }
                    width: frameScope.sideW
                    color: Qt.alpha(theme.frameBg, theme.frameOpacity)
                }

                Rectangle {
                    id: frameRightEdge
                    anchors {
                        top: frameTopEdge.bottom
                        bottom: frameBottomEdge.top
                        right: parent.right
                    }
                    width: frameScope.sideW
                    color: Qt.alpha(theme.frameBg, theme.frameOpacity)
                }

                // ── Rounded desktop area: concave corner pieces in the frame color ──
                RoundCorner {
                    anchors {
                        top: frameTopEdge.bottom
                        left: frameLeftEdge.right
                    }
                    corner: "top-left"
                    cornerSize: frameScope.radius
                    fillColor: theme.frameBg
                    fillAlpha: theme.frameOpacity
                }

                RoundCorner {
                    anchors {
                        top: frameTopEdge.bottom
                        right: frameRightEdge.left
                    }
                    corner: "top-right"
                    cornerSize: frameScope.radius
                    fillColor: theme.frameBg
                    fillAlpha: theme.frameOpacity
                }

                RoundCorner {
                    anchors {
                        bottom: frameBottomEdge.top
                        left: frameLeftEdge.right
                    }
                    corner: "bottom-left"
                    cornerSize: frameScope.radius
                    fillColor: theme.frameBg
                    fillAlpha: theme.frameOpacity
                }

                RoundCorner {
                    anchors {
                        bottom: frameBottomEdge.top
                        right: frameRightEdge.left
                    }
                    corner: "bottom-right"
                    cornerSize: frameScope.radius
                    fillColor: theme.frameBg
                    fillAlpha: theme.frameOpacity
                }

                // ── 1. NOTCH: the top edge swells down around the taskbar ──
                FrameBump {
                    id: middleSection
                    pointsDown: true
                    anchors {
                        top: frameTopEdge.bottom
                        horizontalCenter: parent.horizontalCenter
                    }
                    height: frameScope.notchDepth
                    // long S-curve sides; the icon row sits just inside them
                    sweep: frameScope.px(40)
                    width: middleCenterGroup.width + 2 * frameScope.px(30)
                    fillColor: theme.frameBg
                    fillAlpha: theme.frameOpacity
                }

                // Taskbar: one icon per app (pinned first, then running), drawn over
                // the top edge and the notch
                Row {
                    id: middleCenterGroup
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: frameScope.topH + frameScope.notchDepth - height - frameScope.px(2.5)
                    spacing: frameScope.px(4)

                    Repeater {
                        model: shellRoot.taskAppIds

                        Item {
                            id: taskItem
                            required property string modelData
                            readonly property var wins: shellRoot.toplevelsFor(modelData)
                            readonly property bool running: wins.length > 0
                            readonly property bool focused: shellRoot.anyActivated(wins)

                            width: frameScope.iconPx
                            height: frameScope.iconPx + frameScope.px(4)

                            Item {
                                width: frameScope.iconPx
                                height: frameScope.iconPx
                                scale: taskMouse.containsMouse ? 1.12 : 1.0

                                Behavior on scale {
                                    NumberAnimation { duration: 120 }
                                }

                                Image {
                                    id: taskIcon
                                    anchors.fill: parent
                                    source: shellRoot.appIconSource(taskItem.modelData)
                                    sourceSize.width: frameScope.iconPx * 2
                                    sourceSize.height: frameScope.iconPx * 2
                                    asynchronous: true
                                    smooth: true
                                    mipmap: true
                                    visible: status === Image.Ready
                                }

                                // No themed icon for this app: soft white square with the class glyph
                                Rectangle {
                                    anchors.fill: parent
                                    visible: taskIcon.status !== Image.Ready
                                    radius: Math.round(width * 0.26)
                                    color: theme.framePill

                                    FrameGlyph {
                                        anchors.centerIn: parent
                                        text: shellRoot.iconForClass(taskItem.modelData)
                                        font.pixelSize: Math.round(parent.width * 0.56)
                                    }
                                }
                            }

                            // Running dash under the icon; wider and darker for the focused app
                            Rectangle {
                                id: activeIndicator
                                visible: taskItem.running
                                anchors {
                                    bottom: parent.bottom
                                    horizontalCenter: parent.horizontalCenter
                                }
                                width: frameScope.px(taskItem.focused ? 9 : 6)
                                height: Math.max(2, frameScope.px(1.5))
                                radius: height / 2
                                color: taskItem.focused ? theme.frameInkSoft : theme.frameIndicator

                                Behavior on width {
                                    NumberAnimation { duration: 140; easing.type: Easing.OutSine }
                                }
                            }

                            MouseArea {
                                id: taskMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.button === Qt.MiddleButton) {
                                        shellRoot.taskClose(taskItem.wins);
                                    } else {
                                        shellRoot.taskActivate(taskItem.modelData, taskItem.wins);
                                    }
                                }
                            }
                        }
                    }

                    // Nothing open and nothing pinned: the notch keeps one launcher tile
                    Item {
                        visible: shellRoot.taskAppIds.length === 0
                        width: frameScope.iconPx
                        height: frameScope.iconPx + frameScope.px(4)

                        FrameGlyph {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Math.round((frameScope.iconPx - height) / 2)
                            text: "󰀻"
                            color: emptyTaskMouse.containsMouse ? theme.frameInk : theme.frameInkSoft
                            font.pixelSize: Math.round(frameScope.iconPx * 0.7)
                        }

                        MouseArea {
                            id: emptyTaskMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: shellRoot.runCmd(["hyde-shell", "rofilaunch", "d"])
                        }
                    }
                }

                // ── 2. TITLE TAB: the bottom edge swells up around a white pill
                // holding the focused window (icon + one-line title) ──
                FrameBump {
                    id: titleTab
                    pointsDown: false
                    anchors {
                        bottom: frameBottomEdge.top
                        horizontalCenter: parent.horizontalCenter
                    }
                    height: frameScope.tabRise
                    shoulder: frameScope.px(5)
                    bodyRadius: frameScope.px(8.5)
                    width: titlePill.width + 2 * (shoulder + frameScope.px(1.5))
                    fillColor: theme.frameBg
                    fillAlpha: theme.frameOpacity

                    Rectangle {
                        id: titlePill
                        anchors {
                            bottom: parent.bottom
                            horizontalCenter: parent.horizontalCenter
                        }
                        width: frameScope.inputW
                        height: frameScope.pillH
                        radius: height / 2
                        color: theme.framePill

                        // One line: app icon + title (was the two-line class/title block)
                        Row {
                            id: activeWinColumn
                            anchors {
                                left: parent.left
                                leftMargin: frameScope.px(3)
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: frameScope.px(3.5)

                            Item {
                                width: frameScope.px(10)
                                height: width
                                anchors.verticalCenter: parent.verticalCenter

                                Image {
                                    id: activeWinIcon
                                    anchors.fill: parent
                                    source: shellRoot.appIconSource(shellRoot.focusAppId)
                                    sourceSize.width: width * 2
                                    sourceSize.height: height * 2
                                    asynchronous: true
                                    smooth: true
                                    mipmap: true
                                    visible: status === Image.Ready
                                }

                                FrameGlyph {
                                    anchors.centerIn: parent
                                    visible: activeWinIcon.status !== Image.Ready
                                    text: shellRoot.iconForClass(shellRoot.focusAppId)
                                    font.pixelSize: Math.round(parent.width * 0.9)
                                }
                            }

                            FrameLabel {
                                id: activeWinTitle
                                anchors.verticalCenter: parent.verticalCenter
                                text: shellRoot.focusTitle !== ""
                                    ? shellRoot.focusTitle
                                    : (shellRoot.focusAppId !== "" ? shellRoot.focusAppId : "Desktop")
                                font.pixelSize: frameScope.fontPx
                                font.weight: Font.Medium
                                // long titles are cut with "…" before the end of the pill
                                width: Math.min(implicitWidth, titlePill.width - x - frameScope.px(13))
                            }
                        }
                    }
                }

                // ── 3. BOTTOM EDGE ──
                Item {
                    id: bottomBar
                    anchors {
                        left: frameLeftEdge.right
                        right: frameRightEdge.left
                        bottom: parent.bottom
                    }
                    height: frameScope.bottomH

                    // image-1 keeps the row a touch above the middle of the edge
                    readonly property int rowShift: -frameScope.px(1.5)
                    readonly property int edgeMargin: frameScope.px(19)
                    // room for one side cluster between the screen edge and the input pill
                    readonly property real sideRoom: (width - inputPill.width) / 2 - edgeMargin - frameScope.px(8)

                    // Scroll over the left half: brightness
                    MouseArea {
                        id: leftSideArea
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.horizontalCenter
                        }
                        acceptedButtons: Qt.NoButton
                        onWheel: event => {
                            if (event.angleDelta.y > 0) {
                                shellRoot.runCmd(["brightnessctl", "set", "+5%"]);
                            } else if (event.angleDelta.y < 0) {
                                shellRoot.runCmd(["brightnessctl", "set", "5%-"]);
                            }
                            statusProc.running = true;
                        }
                    }

                    // Scroll over the right half: volume
                    MouseArea {
                        id: rightSideArea
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            left: parent.horizontalCenter
                            right: parent.right
                        }
                        acceptedButtons: Qt.NoButton
                        onWheel: event => {
                            if (event.angleDelta.y > 0) {
                                shellRoot.runCmd(["pamixer", "-i", "5"]);
                            } else if (event.angleDelta.y < 0) {
                                shellRoot.runCmd(["pamixer", "-d", "5"]);
                            }
                            statusProc.running = true;
                        }
                    }

                    // ── 3a. LEFT: "+" launcher, workspace pill, resources + media ──
                    Row {
                        id: leftDockRow
                        anchors {
                            left: parent.left
                            leftMargin: bottomBar.edgeMargin
                            verticalCenter: parent.verticalCenter
                            verticalCenterOffset: bottomBar.rowShift
                        }
                        spacing: frameScope.gap
                        // Too many modules for a narrow screen: the cluster shrinks instead of overlapping the input
                        transformOrigin: Item.Left
                        scale: Math.min(1, bottomBar.sideRoom / Math.max(1, width))

                        // "+" circle: app launcher (right click: AniSub)
                        Rectangle {
                            id: leftSidebarBtn
                            anchors.verticalCenter: parent.verticalCenter
                            width: frameScope.circleS
                            height: frameScope.circleS
                            radius: height / 2
                            color: leftBtnMouse.containsMouse ? theme.frameHover : theme.framePill

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            FrameGlyph {
                                anchors.centerIn: parent
                                visible: !theme.followWallpaper
                                text: "󰐕"
                                font.pixelSize: Math.round(parent.height * 0.54)
                            }

                            // glass launcher icon of the wallpaper-synced skin
                            LisaGlassIcon {
                                anchors.centerIn: parent
                                visible: theme.followWallpaper
                                width: 26
                                height: 26
                                glyph: "󰋜"
                                glyphScale: 0.52
                                accentColor: theme.glowColor
                                plateColor: theme.surfaceBg
                                inkColor: theme.mainFg
                                variant: 1
                                arcStart: -215
                                arcSweep: 100
                                sparkX: 0.88
                                sparkY: 0.12
                                sparkSize: 0.12
                                sparkRot: 0
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

                        // Workspace pill: avatar + "Workspace N" + five slots (the old switcher)
                        BarGroup {
                            id: workspacePill
                            height: frameScope.pillH
                            implicitWidth: wsRow.width + frameScope.px(2) + frameScope.px(5)

                            // Scroll anywhere on the pill: next / previous workspace
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: event => {
                                    if (event.angleDelta.y < 0) {
                                        Hyprland.dispatch("workspace r+1");
                                    } else if (event.angleDelta.y > 0) {
                                        Hyprland.dispatch("workspace r-1");
                                    }
                                }
                            }

                            Row {
                                id: wsRow
                                anchors {
                                    left: parent.left
                                    leftMargin: frameScope.px(2)
                                    verticalCenter: parent.verticalCenter
                                }
                                spacing: frameScope.px(4)

                                // Avatar (~/.face.icon). QtQuick `clip` only cuts rectangles, so the
                                // picture is rounded with four corner pieces in the pill color.
                                Item {
                                    id: wsAvatar
                                    width: frameScope.pillH - 2 * frameScope.px(2)
                                    height: width
                                    anchors.verticalCenter: parent.verticalCenter
                                    readonly property bool hasPicture: wsAvatarImage.status === Image.Ready
                                    readonly property int half: Math.ceil(width / 2)

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: width / 2
                                        visible: !wsAvatar.hasPicture
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: theme.frameAccentA }
                                            GradientStop { position: 1.0; color: theme.frameAccentB }
                                        }

                                        FrameLabel {
                                            anchors.centerIn: parent
                                            text: shellRoot.userInitial
                                            color: theme.frameAccentInk
                                            font.pixelSize: Math.round(parent.height * 0.52)
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    Image {
                                        id: wsAvatarImage
                                        anchors.fill: parent
                                        source: shellRoot.avatarUrl
                                        sourceSize.width: width * 2
                                        sourceSize.height: height * 2
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        smooth: true
                                        mipmap: true
                                        visible: wsAvatar.hasPicture
                                    }

                                    RoundCorner {
                                        visible: wsAvatar.hasPicture
                                        corner: "top-left"
                                        cornerSize: wsAvatar.half
                                        fillColor: theme.framePill
                                        fillAlpha: 1.0
                                    }

                                    RoundCorner {
                                        visible: wsAvatar.hasPicture
                                        anchors.right: parent.right
                                        corner: "top-right"
                                        cornerSize: wsAvatar.half
                                        fillColor: theme.framePill
                                        fillAlpha: 1.0
                                    }

                                    RoundCorner {
                                        visible: wsAvatar.hasPicture
                                        anchors.bottom: parent.bottom
                                        corner: "bottom-left"
                                        cornerSize: wsAvatar.half
                                        fillColor: theme.framePill
                                        fillAlpha: 1.0
                                    }

                                    RoundCorner {
                                        visible: wsAvatar.hasPicture
                                        anchors {
                                            right: parent.right
                                            bottom: parent.bottom
                                        }
                                        corner: "bottom-right"
                                        cornerSize: wsAvatar.half
                                        fillColor: theme.framePill
                                        fillAlpha: 1.0
                                    }
                                }

                                FrameLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Workspace " + frameScope.activeWsId
                                    font.pixelSize: frameScope.fontPx
                                }

                                // Five slots of the current bank: dark = active, grey = has windows, pale = empty
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter

                                    Repeater {
                                        model: 5

                                        Item {
                                            id: wsSlot
                                            required property int index
                                            readonly property int wsId: frameScope.bankOffset + index + 1
                                            readonly property bool isActive: (frameScope.localOrbIndex === index)
                                            readonly property bool isOcc: frameScope.isWsOccupied(wsId)

                                            width: wsDot.width + frameScope.px(3)
                                            height: frameScope.pillH

                                            Rectangle {
                                                id: wsDot
                                                anchors.centerIn: parent
                                                width: frameScope.px(wsSlot.isActive ? 7 : 3)
                                                height: frameScope.px(3)
                                                radius: height / 2
                                                color: wsSlot.isActive
                                                    ? theme.frameInk
                                                    : ((wsSlot.isOcc || wsHit.containsMouse)
                                                        ? theme.frameIndicator
                                                        : Qt.alpha(theme.frameInk, 0.14))

                                                Behavior on width {
                                                    NumberAnimation { duration: 160; easing.type: Easing.OutSine }
                                                }
                                                Behavior on color {
                                                    ColorAnimation { duration: 160 }
                                                }
                                            }

                                            MouseArea {
                                                id: wsHit
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Hyprland.dispatch("workspace " + wsSlot.wsId)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Resources + media pill (`leftCenterGroup`)
                        BarGroup {
                            id: leftCenterGroup
                            height: frameScope.pillH
                            implicitWidth: resRow.width + 2 * frameScope.px(5)

                            Row {
                                id: resRow
                                anchors.centerIn: parent
                                spacing: frameScope.px(4.5)

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: frameScope.px(2)

                                    CircularResourceRing {
                                        anchors.verticalCenter: parent.verticalCenter
                                        size: frameScope.px(8.5)
                                        value: shellRoot.memoryUsage
                                        iconText: "󰍛"
                                        primaryColor: shellRoot.memoryUsage >= 0.90 ? theme.errorColor : theme.frameInk
                                    }
                                    FrameLabel {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Math.round(shellRoot.memoryUsage * 100).toString() + "%"
                                        font.pixelSize: frameScope.fontPx - 1
                                    }
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: frameScope.px(2)

                                    CircularResourceRing {
                                        anchors.verticalCenter: parent.verticalCenter
                                        size: frameScope.px(8.5)
                                        value: shellRoot.swapUsage
                                        iconText: "󰓡"
                                        primaryColor: shellRoot.swapUsage >= 0.90 ? theme.errorColor : theme.frameInk
                                    }
                                    FrameLabel {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Math.round(shellRoot.swapUsage * 100).toString() + "%"
                                        font.pixelSize: frameScope.fontPx - 1
                                    }
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: frameScope.px(2)

                                    CircularResourceRing {
                                        anchors.verticalCenter: parent.verticalCenter
                                        size: frameScope.px(8.5)
                                        value: shellRoot.cpuUsage
                                        iconText: "󰻠"
                                        primaryColor: shellRoot.cpuUsage >= 0.90 ? theme.errorColor : theme.frameInk
                                    }
                                    FrameLabel {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Math.round(shellRoot.cpuUsage * 100).toString() + "%"
                                        font.pixelSize: frameScope.fontPx - 1
                                    }
                                }

                                FrameSeparator {
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: frameScope.px(6)
                                }

                                // Media / AniSub slot
                                Rectangle {
                                    id: mediaSlot
                                    readonly property var activePlayer: (Mpris.players && Mpris.players.values && Mpris.players.values.length > 0)
                                        ? Mpris.players.values[0]
                                        : null
                                    readonly property bool hasTrack: activePlayer !== null && activePlayer.trackTitle !== ""
                                    readonly property bool playing: hasTrack && activePlayer.isPlaying
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: mediaRow.width + 2 * frameScope.px(3)
                                    height: frameScope.btnS
                                    radius: height / 2
                                    color: mediaMouse.containsMouse ? theme.frameHover : "transparent"

                                    Row {
                                        id: mediaRow
                                        anchors.centerIn: parent
                                        spacing: frameScope.px(2.5)

                                        // Playing dot: accent while a track plays, grey otherwise
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: frameScope.px(3.5)
                                            height: width
                                            radius: width / 2
                                            color: mediaSlot.playing ? theme.frameAccentA : theme.frameIndicator

                                            Behavior on color {
                                                ColorAnimation { duration: 200 }
                                            }
                                        }

                                        FrameGlyph {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: text !== ""
                                            text: mediaSlot.playing ? "" : "󰎈"
                                            font.pixelSize: frameScope.fontPx + 1
                                        }

                                        FrameLabel {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: mediaSlot.hasTrack
                                                ? mediaSlot.activePlayer.trackTitle
                                                : "AniSub"
                                            font.pixelSize: frameScope.fontPx
                                            width: Math.min(implicitWidth, frameScope.px(50))
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

                    // ── 3b. CENTER: input pill. It only looks like a text field: a click
                    // opens the app launcher, so the bar never takes keyboard focus ──
                    Rectangle {
                        id: inputPill
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            verticalCenter: parent.verticalCenter
                            verticalCenterOffset: bottomBar.rowShift
                        }
                        width: frameScope.inputW
                        height: frameScope.inputH
                        radius: height / 2
                        color: theme.framePill

                        FrameLabel {
                            anchors {
                                left: parent.left
                                leftMargin: frameScope.px(9)
                                right: inputAction.left
                                rightMargin: frameScope.px(4)
                                verticalCenter: parent.verticalCenter
                            }
                            text: theme.inputPlaceholder
                            color: theme.frameInkSoft
                            font.pixelSize: frameScope.fontPx
                        }

                        // Action pill inside the field (pale teal, white ink)
                        Rectangle {
                            id: inputAction
                            anchors {
                                right: parent.right
                                rightMargin: frameScope.px(2)
                                verticalCenter: parent.verticalCenter
                            }
                            width: inputActionRow.width + 2 * frameScope.px(6)
                            height: parent.height - 2 * frameScope.px(2)
                            radius: height / 2
                            opacity: inputMouse.containsMouse ? 0.86 : 1.0
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: theme.frameAccentA }
                                GradientStop { position: 1.0; color: theme.frameAccentB }
                            }

                            Behavior on opacity {
                                NumberAnimation { duration: 120 }
                            }

                            Row {
                                id: inputActionRow
                                anchors.centerIn: parent
                                spacing: frameScope.px(2.5)

                                FrameGlyph {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰙴"
                                    color: theme.frameAccentInk
                                    font.pixelSize: frameScope.fontPx + 1
                                }

                                FrameLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: theme.inputButtonText
                                    color: theme.frameAccentInk
                                    font.pixelSize: frameScope.fontPx
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        MouseArea {
                            id: inputMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: shellRoot.runCmd(["hyde-shell", "rofilaunch", "d"])
                        }
                    }

                    // ── 3c. RIGHT: clock + utils + battery, tray, status pill, bell, user ──
                    Row {
                        id: rightSideRow
                        anchors {
                            right: parent.right
                            rightMargin: bottomBar.edgeMargin
                            verticalCenter: parent.verticalCenter
                            verticalCenterOffset: bottomBar.rowShift
                        }
                        spacing: frameScope.gap
                        transformOrigin: Item.Right
                        scale: Math.min(1, bottomBar.sideRoom / Math.max(1, width))

                        // Clock + utility buttons + battery pill (`rightCenterGroup`)
                        BarGroup {
                            id: rightCenterGroup
                            height: frameScope.pillH
                            implicitWidth: rightDockRow.width + 2 * frameScope.px(4)

                            Row {
                                id: rightDockRow
                                anchors.centerIn: parent
                                spacing: frameScope.px(3)

                                // Clock: HH:mm • date (+ settings glyph)
                                Rectangle {
                                    id: rightClockPill
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: clockPillRow.width + 2 * frameScope.px(4)
                                    height: frameScope.btnS
                                    radius: height / 2
                                    color: rightClockMouse.containsMouse ? theme.frameHover : "transparent"

                                    Behavior on color {
                                        ColorAnimation { duration: 150 }
                                    }

                                    Row {
                                        id: clockPillRow
                                        anchors.centerIn: parent
                                        spacing: frameScope.px(2.5)

                                        FrameLabel {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: shellRoot.timeText
                                            font.pixelSize: frameScope.fontPx
                                            font.weight: Font.DemiBold
                                        }

                                        FrameLabel {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "•"
                                            color: theme.frameInkSoft
                                            font.pixelSize: frameScope.fontPx - 2
                                        }

                                        FrameLabel {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: shellRoot.dateText
                                            color: theme.frameInkSoft
                                            font.pixelSize: frameScope.fontPx
                                        }

                                        FrameGlyph {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "󰢻"
                                            font.pixelSize: frameScope.fontPx
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

                                FrameSeparator {
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: frameScope.px(6)
                                }

                                // Coffee / Caffeine toggle (`caffeineBtn`)
                                FrameButton {
                                    id: caffeineBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: frameScope.btnS
                                    height: frameScope.btnS
                                    iconText: shellRoot.caffeineActive ? "󰅶" : "󰛊"
                                    activeState: shellRoot.caffeineActive
                                    iconVariant: 2
                                    iconArcStart: -205
                                    iconArcSweep: 95
                                    iconSparkX: 0.88
                                    iconSparkY: 0.13
                                    iconSparkRot: 45
                                    onTriggered: {
                                        shellRoot.caffeineActive = !shellRoot.caffeineActive;
                                        shellRoot.runCmd(["hyde-shell", "caffeine", "-t"]);
                                    }
                                    onRightTriggered: {
                                        shellRoot.caffeineActive = !shellRoot.caffeineActive;
                                        shellRoot.runCmd(["hyde-shell", "caffeine", "-t"]);
                                    }
                                }

                                // Screenshot utility (left-click: region `s`, right-click: full screen `p`)
                                FrameButton {
                                    id: screenshotBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: frameScope.btnS
                                    height: frameScope.btnS
                                    iconText: "󰆞"
                                    iconVariant: 0
                                    iconArcStart: -215
                                    iconArcSweep: 105
                                    iconSparkX: 0.87
                                    iconSparkY: 0.135
                                    onTriggered: shellRoot.runCmd(["hyde-shell", "screenshot", "s"])
                                    onRightTriggered: shellRoot.runCmd(["hyde-shell", "screenshot", "p"])
                                }

                                // Color Picker utility
                                FrameButton {
                                    id: colorPickBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: frameScope.btnS
                                    height: frameScope.btnS
                                    iconText: "󰈊"
                                    iconVariant: 2
                                    iconArcStart: -230
                                    iconArcSweep: 110
                                    iconSparkX: 0.86
                                    iconSparkY: 0.15
                                    iconSparkRot: 45
                                    onTriggered: shellRoot.runCmd(["hyprpicker", "-a"])
                                    onRightTriggered: shellRoot.runCmd(["hyprpicker", "-a"])
                                }

                                // AniSub utility
                                FrameButton {
                                    id: anisubBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: frameScope.btnS
                                    height: frameScope.btnS
                                    iconText: "󰐊"
                                    iconVariant: 0
                                    iconArcStart: -185
                                    iconArcSweep: 85
                                    iconSparkX: 0.88
                                    iconSparkY: 0.12
                                    onTriggered: shellRoot.runCmd(["hyde-shell", "rofi.movie"])
                                    onRightTriggered: shellRoot.runCmd(["hyde-shell", "rofi.movie"])
                                }

                                FrameSeparator {
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: frameScope.px(6)
                                }

                                // OneUI 7 ClippedProgressBar Battery pill
                                Row {
                                    id: batteryRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: frameScope.px(2.5)
                                    rightPadding: frameScope.px(3)

                                    FrameGlyph {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: shellRoot.batteryCharging ? "󰂄" : "󰁹"
                                        color: (shellRoot.batteryLevel <= 0.20 && !shellRoot.batteryCharging)
                                            ? theme.errorColor
                                            : theme.frameInk
                                        font.pixelSize: frameScope.fontPx + 1
                                    }

                                    ClippedProgressBar {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: frameScope.px(20)
                                        height: frameScope.px(6.5)
                                        value: shellRoot.batteryLevel
                                        fill: (shellRoot.batteryLevel <= 0.20 && !shellRoot.batteryCharging)
                                            ? theme.errorColor
                                            : theme.frameAccentA
                                        trackColor: Qt.alpha(theme.frameInk, 0.10)
                                        textColor: theme.frameInk
                                    }
                                }
                            }
                        }

                        // System tray pill (only while something is in the tray)
                        BarGroup {
                            id: trayPill
                            visible: SystemTray.items && SystemTray.items.values && SystemTray.items.values.length > 0
                            height: frameScope.pillH
                            implicitWidth: trayRow.width + 2 * frameScope.px(4)

                            Row {
                                id: trayRow
                                anchors.centerIn: parent
                                spacing: frameScope.px(1.5)

                                Repeater {
                                    model: SystemTray.items

                                    Rectangle {
                                        id: traySlot
                                        required property var modelData
                                        width: frameScope.btnS
                                        height: frameScope.btnS
                                        radius: height / 2
                                        color: trayMouse.containsMouse ? theme.frameHover : "transparent"

                                        Image {
                                            anchors.centerIn: parent
                                            width: Math.round(parent.width * 0.6)
                                            height: width
                                            source: traySlot.modelData.icon || ""
                                            sourceSize.width: width * 2
                                            sourceSize.height: height * 2
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
                        }

                        // Status pill: Bluetooth, Wi-Fi, Mic, Volume
                        BarGroup {
                            id: rightStatusPill
                            height: frameScope.pillH
                            implicitWidth: statusRow.width + 2 * frameScope.px(4)

                            Row {
                                id: statusRow
                                anchors.centerIn: parent
                                spacing: frameScope.px(1.5)

                                FrameButton {
                                    id: bluetoothBtn
                                    width: frameScope.btnS
                                    height: frameScope.btnS
                                    iconText: shellRoot.bluetoothConnected
                                        ? "󰂱"
                                        : (shellRoot.bluetoothOn ? "󰂯" : "󰂲")
                                    iconVariant: 0
                                    iconArcStart: -225
                                    iconArcSweep: 95
                                    iconSparkX: 0.87
                                    iconSparkY: 0.13
                                    onTriggered: shellRoot.runCmd(["blueman-manager"])
                                    onRightTriggered: shellRoot.runCmd(["blueman-manager"])
                                }

                                FrameButton {
                                    id: wifiBtn
                                    width: frameScope.btnS
                                    height: frameScope.btnS
                                    iconText: shellRoot.networkName !== "" ? "󰤨" : "󰤭"
                                    iconVariant: 1
                                    iconArcStart: -195
                                    iconArcSweep: 90
                                    iconSparkX: 0.88
                                    iconSparkY: 0.135
                                    iconSparkRot: 45
                                    onTriggered: shellRoot.runCmd(["nm-connection-editor"])
                                    onRightTriggered: shellRoot.runCmd(["nm-connection-editor"])
                                }

                                FrameButton {
                                    id: micBtn
                                    width: frameScope.btnS
                                    height: frameScope.btnS
                                    iconText: shellRoot.micMuted ? "󰍭" : "󰍬"
                                    iconVariant: 2
                                    iconArcStart: -200
                                    iconArcSweep: 100
                                    iconSparkX: 0.86
                                    iconSparkY: 0.14
                                    onTriggered: {
                                        shellRoot.runCmd(["pamixer", "--default-source", "-t"]);
                                        statusProc.running = true;
                                    }
                                    onRightTriggered: {
                                        shellRoot.runCmd(["pamixer", "--default-source", "-t"]);
                                        statusProc.running = true;
                                    }
                                }

                                FrameButton {
                                    id: volBtn
                                    width: frameScope.btnS
                                    height: frameScope.btnS
                                    iconText: shellRoot.volumeMuted
                                        ? "󰝟"
                                        : (shellRoot.volumeLevel < 35 ? "󰕿" : (shellRoot.volumeLevel < 70 ? "󰖀" : "󰕾"))
                                    iconVariant: 0
                                    iconArcStart: -240
                                    iconArcSweep: 115
                                    iconSparkX: 0.86
                                    iconSparkY: 0.145
                                    iconSparkRot: 45
                                    onTriggered: {
                                        shellRoot.runCmd(["pamixer", "-t"]);
                                        statusProc.running = true;
                                    }
                                    onRightTriggered: shellRoot.runCmd(["pavucontrol"])
                                }
                            }
                        }

                        // Bell circle: last notification back from dunst history (right click: close all)
                        FrameButton {
                            id: bellBtn
                            anchors.verticalCenter: parent.verticalCenter
                            plate: true
                            width: frameScope.circleS
                            height: frameScope.circleS
                            iconText: "󰂜"
                            iconVariant: 2
                            onTriggered: shellRoot.runCmd(["dunstctl", "history-pop"])
                            onRightTriggered: shellRoot.runCmd(["dunstctl", "close-all"])
                        }

                        // User circle: AniDE settings (right click: session menu)
                        FrameButton {
                            id: settingsBtn
                            anchors.verticalCenter: parent.verticalCenter
                            plate: true
                            width: frameScope.circleS
                            height: frameScope.circleS
                            iconText: theme.followWallpaper ? "󰒓" : "󰀓"
                            iconVariant: 1
                            iconArcStart: -230
                            iconArcSweep: 110
                            iconSparkX: 0.88
                            iconSparkY: 0.13
                            onTriggered: shellRoot.runCmd(["hyde-shell", "anide-settings"])
                            onRightTriggered: shellRoot.runCmd(["hyde-shell", "logoutlaunch", "1"])
                        }
                    }
                }
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

                // ── Main Draggable LED Dot-Matrix Clock Widget (NO background — pure floating LED dots on wallpaper) ──
                Rectangle {
                    id: clockCard
                    x: shellRoot.clockWidgetX
                    y: shellRoot.clockWidgetY
                    width: Math.round(396 * shellRoot.clockScale)
                    height: Math.round(196 * shellRoot.clockScale)
                    radius: Math.round(16 * shellRoot.clockScale)
                    color: "transparent"
                    border.width: 0
                    border.color: "transparent"

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

                        // Section 3: LED Glow Intensity Presets (Soft, Normal, Neon, Max)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "Glow:"
                                color: "#a9c1ca"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                            }

                            Repeater {
                                model: [
                                    { label: "Soft", glow: 0.45 },
                                    { label: "Normal", glow: 0.88 },
                                    { label: "Neon", glow: 1.18 },
                                    { label: "Max", glow: 1.45 }
                                ]

                                Rectangle {
                                    id: glowPresetBtn
                                    required property var modelData
                                    readonly property bool isSelected: Math.abs(shellRoot.clockGlowIntensity - modelData.glow) < 0.10
                                    Layout.fillWidth: true
                                    implicitHeight: 24
                                    radius: 12
                                    color: isSelected
                                        ? Qt.rgba(0.84, 0.93, 0.96, 0.24)
                                        : (glowPresetMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.09))
                                    border.width: 1
                                    border.color: isSelected ? "#ffffff" : Qt.rgba(1, 1, 1, 0.16)

                                    Text {
                                        anchors.centerIn: parent
                                        text: glowPresetBtn.modelData.label
                                        color: "#f4f9fc"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        font.bold: isSelected
                                    }

                                    MouseArea {
                                        id: glowPresetMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            shellRoot.clockGlowIntensity = glowPresetBtn.modelData.glow;
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

    // ── AniSub panel (Win+Shift+M): glass card dropping from the top bar, image-18 look ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: anisubPanelWindow
            required property var modelData
            screen: modelData
            // Opens on the primary screen only
            visible: shellRoot.anisubPanelOpen && modelData === Quickshell.screens[0]

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusiveZone: 0
            color: "transparent"
            // On-demand keyboard: the search box takes typing, nothing grabs the desktop
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            // Clicks land only on the card; the rest of the screen stays usable
            mask: Region {
                item: anisubPanelFace
            }

            onVisibleChanged: if (visible) Qt.callLater(anisubPanelFace.focusInput)

            AniSubPanelFace {
                id: anisubPanelFace
                x: Math.round((anisubPanelWindow.width - width) / 2)
                y: shellRoot.anisubPanelOpen ? shellRoot.anisubPanelTop : shellRoot.anisubPanelTop - 24

                Behavior on y {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                themePalette: theme
                feedItems: shellRoot.anisubMovieItems
                feedLoading: shellRoot.anisubMovieFeedLoading
                searchItems: shellRoot.anisubMovieSearchItems
                searchLoading: shellRoot.anisubMovieSearchLoading
                episodes: shellRoot.anisubMovieEpisodes
                episodesLoading: shellRoot.anisubMovieEpisodesLoading
                onSearchSubmitted: query => shellRoot.anisubPanelSearch(query)
                onSearchCleared: shellRoot.anisubPanelSearchClear()
                onCloseRequested: shellRoot.anisubPanelOpen = false
                onEpisodesRequested: film => shellRoot.anisubMovieLoadEpisodes(film)
                onPlayEpisode: (film, ep) => shellRoot.anisubMoviePlayEpisode(film, ep)
            }
        }
    }

    // `qs -p ~/.config/quickshell ipc call anisub toggle` (bound to Win+Shift+M)
    IpcHandler {
        target: "anisub"

        function toggle(): void {
            shellRoot.anisubPanelOpen = !shellRoot.anisubPanelOpen;
        }

        function open(): void {
            shellRoot.anisubPanelOpen = true;
        }

        function close(): void {
            shellRoot.anisubPanelOpen = false;
        }
    }

    onAnisubPanelOpenChanged: {
        if (!anisubPanelOpen) return;
        if (anisubMovieItems.length === 0 || Date.now() - anisubMovieFeedAt > 600000) refreshAnisubFeed();
    }
}
