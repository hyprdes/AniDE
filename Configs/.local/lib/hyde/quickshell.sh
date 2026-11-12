#!/usr/bin/env bash
# @name: quickshell
# @ver: 1.0.0
# @short: Manage the AniDE Quickshell status bar
# @usage: hyde-shell quickshell [--watch|--reload|--update|--hide|--kill]
# @global.flag: -w,--watch | Start Quickshell if not already running
# @global.flag: -r,--reload | Restart Quickshell and refresh theme colors
# @global.flag: -u,--update | Refresh Quickshell theme colors
# @global.flag: -H,--hide | Toggle Quickshell bar visibility
# @global.flag: -k,--kill | Stop Quickshell and any legacy Waybar process
# @global.flag: -h,--help | Show this help message

set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
QS_CONFIG_DIR="${XDG_CONFIG_HOME}/quickshell"
QS_SHARE_DIR="${XDG_DATA_HOME}/quickshell"

find_qs_bin() {
    if command -v quickshell >/dev/null 2>&1; then
        printf 'quickshell\n'
    elif command -v qs >/dev/null 2>&1; then
        printf 'qs\n'
    else
        return 1
    fi
}

is_qs_running() {
    pgrep -u "${USER:-$(id -un)}" -x quickshell >/dev/null 2>&1 ||
        pgrep -u "${USER:-$(id -un)}" -x qs >/dev/null 2>&1
}

stop_waybar() {
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user stop "hyde-${XDG_SESSION_DESKTOP:-Hyprland}-bar.service" "hyde-Hyprland-bar.service" "waybar.service" >/dev/null 2>&1 || true
        systemctl --user reset-failed "hyde-${XDG_SESSION_DESKTOP:-Hyprland}-bar.service" "hyde-Hyprland-bar.service" "waybar.service" >/dev/null 2>&1 || true
    fi
    pkill -u "${USER:-$(id -un)}" -x waybar >/dev/null 2>&1 || true
}

write_default_theme() {
    cat >"${QS_CONFIG_DIR}/theme.json" <<'EOF'
{
  "preset": "soul-cyan-mist",
  "barBg": "#05070b",
  "mainBg": "#05070b",
  "surfaceBg": "#070b10",
  "layer2Bg": "#0c141d",
  "mainFg": "#f5fbff",
  "subFg": "#9ab4c7",
  "actBg": "#00e5ff",
  "glowColor": "#00e5ff",
  "glowSecondary": "#9ef8ff",
  "accentSecondary": "#0f2533",
  "onSecondaryContainer": "#e3faff",
  "actFg": "#030b10",
  "hvrBg": "#122838",
  "hvrFg": "#ffffff",
  "borderColor": "#b8f2ff",
  "barOpacity": 0.28,
  "pillOpacity": 0.50,
  "cornerRadius": 24
}
EOF
}

ensure_config() {
    mkdir -p "${QS_CONFIG_DIR}"
    if [[ ! -f "${QS_CONFIG_DIR}/shell.qml" && -d "${QS_SHARE_DIR}" ]]; then
        cp -rn "${QS_SHARE_DIR}/." "${QS_CONFIG_DIR}/" 2>/dev/null || true
    fi
    if [[ ! -f "${QS_CONFIG_DIR}/theme.json" ]] || ! grep -q '"soul-cyan-mist"' "${QS_CONFIG_DIR}/theme.json" 2>/dev/null; then
        write_default_theme
    fi
}

start_qs() {
    stop_waybar
    ensure_config
    local qs_bin
    if ! qs_bin=$(find_qs_bin); then
        printf 'Quickshell binary (quickshell / qs) not found on PATH.\n' >&2
        return 0
    fi
    if is_qs_running; then
        return 0
    fi
    nohup "${qs_bin}" -p "${QS_CONFIG_DIR}" >/dev/null 2>&1 &
    disown || true
}

kill_qs() {
    stop_waybar
    pkill -u "${USER:-$(id -un)}" -x quickshell >/dev/null 2>&1 || true
    pkill -u "${USER:-$(id -un)}" -x qs >/dev/null 2>&1 || true
}

reload_qs() {
    ensure_config
    kill_qs
    sleep 0.15
    start_qs
}

update_qs() {
    stop_waybar
    ensure_config
    if ! is_qs_running; then
        start_qs
    fi
}

toggle_qs() {
    if is_qs_running; then
        kill_qs
    else
        start_qs
    fi
}

show_help() {
    cat <<'EOF'
AniDE Quickshell Bar Manager
Usage: hyde-shell quickshell [OPTION]

Options:
  -w, --watch     Start Quickshell if not running
  -r, --reload    Restart Quickshell and reload configuration
  -u, --update    Refresh Quickshell theme colors (hot-reload)
  -H, --hide      Toggle Quickshell visibility
  -k, --kill      Stop Quickshell
  -h, --help      Display this help text
EOF
}

case "${1:---watch}" in
    -w | --watch | start)
        start_qs
        ;;
    -r | --reload | reload | restart)
        reload_qs
        ;;
    -u | --update | update)
        update_qs
        ;;
    -H | --hide | hide | toggle)
        toggle_qs
        ;;
    -k | --kill | kill | stop)
        kill_qs
        ;;
    -h | --help | help)
        show_help
        ;;
    *)
        start_qs
        ;;
esac
