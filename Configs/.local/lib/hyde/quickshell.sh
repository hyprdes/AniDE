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
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
QS_CONFIG_DIR="${XDG_CONFIG_HOME}/quickshell"
QS_SHARE_DIR="${XDG_DATA_HOME}/quickshell"
HYDE_CACHE_DIR="${XDG_CACHE_HOME}/hyde"

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

apply_hypr_blur() {
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
        hyprctl --batch "keyword decoration:blur:enabled true ; keyword decoration:blur:size 10 ; keyword decoration:blur:passes 4 ; keyword decoration:blur:ignore_opacity true ; keyword decoration:blur:xray true ; keyword decoration:blur:vibrancy 0.28 ; keyword decoration:blur:noise 0.03" >/dev/null 2>&1 || true
    fi
}

sync_wallpaper_theme() {
    mkdir -p "${QS_CONFIG_DIR}"
    local dcol_file=""
    local blur_path=""

    if [[ -e "${HYDE_CACHE_DIR}/wall.blur" ]]; then
        blur_path=$(readlink -f "${HYDE_CACHE_DIR}/wall.blur" 2>/dev/null || printf '%s' "${HYDE_CACHE_DIR}/wall.blur")
    elif [[ -e "${HYDE_CACHE_DIR}/wall.set" ]]; then
        blur_path=$(readlink -f "${HYDE_CACHE_DIR}/wall.set" 2>/dev/null || printf '%s' "${HYDE_CACHE_DIR}/wall.set")
    fi

    if [[ -f "${HYDE_CACHE_DIR}/wall.dcol" ]]; then
        dcol_file=$(readlink -f "${HYDE_CACHE_DIR}/wall.dcol" 2>/dev/null || printf '%s' "${HYDE_CACHE_DIR}/wall.dcol")
    elif [[ -f "${HYDE_CACHE_DIR}/wallbash/shell-colors" ]]; then
        dcol_file="${HYDE_CACHE_DIR}/wallbash/shell-colors"
    fi

    if [[ -n "${dcol_file}" && -r "${dcol_file}" ]]; then
        (
            # shellcheck disable=SC1090
            source "${dcol_file}" 2>/dev/null || true
            local p1="${dcol_pry1:-${wallbash_pry1:-#05070b}}"
            local p2="${dcol_pry2:-${wallbash_pry2:-#070b10}}"
            local p3="${dcol_pry3:-${wallbash_pry3:-#0f2533}}"
            local p4="${dcol_pry4:-${wallbash_pry4:-#00e5ff}}"
            local t1="${dcol_txt1:-${wallbash_txt1:-#f5fbff}}"
            local x17="${dcol_1xa7:-${wallbash_1xa7:-#9ab4c7}}"
            local x19="${dcol_1xa9:-${wallbash_1xa9:-${t1}}}"
            local x22="${dcol_2xa2:-${wallbash_2xa2:-#0c141d}}"
            local x23="${dcol_2xa3:-${wallbash_2xa3:-#122838}}"
            local x37="${dcol_3xa7:-${wallbash_3xa7:-${p4}}}"
            local x38="${dcol_3xa8:-${wallbash_3xa8:-${x37}}}"
            local x39="${dcol_3xa9:-${wallbash_3xa9:-#e3faff}}"
            local x48="${dcol_4xa8:-${wallbash_4xa8:-#9ef8ff}}"

            [[ "${p1}" == \#* ]] || p1="#${p1}"
            [[ "${p2}" == \#* ]] || p2="#${p2}"
            [[ "${p3}" == \#* ]] || p3="#${p3}"
            [[ "${x17}" == \#* ]] || x17="#${x17}"
            [[ "${x19}" == \#* ]] || x19="#${x19}"
            [[ "${x22}" == \#* ]] || x22="#${x22}"
            [[ "${x23}" == \#* ]] || x23="#${x23}"
            [[ "${x37}" == \#* ]] || x37="#${x37}"
            [[ "${x38}" == \#* ]] || x38="#${x38}"
            [[ "${x39}" == \#* ]] || x39="#${x39}"
            [[ "${x48}" == \#* ]] || x48="#${x48}"

            cat >"${QS_CONFIG_DIR}/theme.json" <<EOF
{
  "preset": "wallbash-glass",
  "barBg": "${p1}",
  "mainBg": "${p1}",
  "surfaceBg": "${p2}",
  "layer2Bg": "${x22}",
  "mainFg": "${x19}",
  "subFg": "${x17}",
  "actBg": "${x37}",
  "glowColor": "${x38}",
  "glowSecondary": "${x48}",
  "accentSecondary": "${p3}",
  "onSecondaryContainer": "${x39}",
  "actFg": "${p1}",
  "hvrBg": "${x23}",
  "hvrFg": "${x39}",
  "borderColor": "${x37}",
  "barOpacity": 0.28,
  "pillOpacity": 0.48,
  "cornerRadius": 24,
  "wallBlurPath": "${blur_path}"
}
EOF
        )
        return 0
    fi

    if [[ ! -f "${QS_CONFIG_DIR}/theme.json" ]]; then
        cat >"${QS_CONFIG_DIR}/theme.json" <<EOF
{
  "preset": "wallbash-glass",
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
  "pillOpacity": 0.48,
  "cornerRadius": 24,
  "wallBlurPath": "${blur_path}"
}
EOF
    fi
}

ensure_config() {
    mkdir -p "${QS_CONFIG_DIR}"
    if [[ -d "${QS_SHARE_DIR}" ]]; then
        for qml_file in shell.qml Colors.qml RoundCorner.qml; do
            if [[ -f "${QS_SHARE_DIR}/${qml_file}" ]] && ! cmp -s "${QS_SHARE_DIR}/${qml_file}" "${QS_CONFIG_DIR}/${qml_file}" 2>/dev/null; then
                cp -f "${QS_SHARE_DIR}/${qml_file}" "${QS_CONFIG_DIR}/${qml_file}" 2>/dev/null || true
            fi
        done
    fi
    sync_wallpaper_theme
}

start_qs() {
    stop_waybar
    ensure_config
    apply_hypr_blur
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
    apply_hypr_blur
    kill_qs
    sleep 0.15
    start_qs
}

update_qs() {
    stop_waybar
    ensure_config
    apply_hypr_blur
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
