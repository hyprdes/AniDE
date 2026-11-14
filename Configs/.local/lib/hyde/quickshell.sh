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
QS_LOG_FILE="${XDG_RUNTIME_DIR:-/tmp}/quickshell.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_QS_DIR="${SCRIPT_DIR}/../../../.config/quickshell"

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
    if pgrep -u "${USER:-$(id -un)}" -x waybar >/dev/null 2>&1; then
        if command -v systemctl >/dev/null 2>&1; then
            systemctl --user stop "waybar.service" >/dev/null 2>&1 || true
            systemctl --user reset-failed "waybar.service" >/dev/null 2>&1 || true
        fi
        pkill -u "${USER:-$(id -un)}" -x waybar >/dev/null 2>&1 || true
    fi
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
    local tmp_json="${QS_CONFIG_DIR}/.theme.json.tmp.$$"

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
            p1="${dcol_pry1:-${wallbash_pry1:-#0e1115}}"
            x12="${dcol_1xa2:-${wallbash_1xa2:-#262c34}}"
            x13="${dcol_1xa3:-${wallbash_1xa3:-#323943}}"
            x14="${dcol_1xa4:-${wallbash_1xa4:-#38414d}}"
            x16="${dcol_1xa6:-${wallbash_1xa6:-#8b95a1}}"
            x19="${dcol_1xa9:-${wallbash_1xa9:-#e6ebf0}}"
            x23="${dcol_2xa3:-${wallbash_2xa3:-#333b45}}"
            x24="${dcol_2xa4:-${wallbash_2xa4:-#3d4652}}"
            x28="${dcol_2xa8:-${wallbash_2xa8:-#e2e8f0}}"
            x29="${dcol_2xa9:-${wallbash_2xa9:-#dde4ed}}"

            [[ "${p1}" == \#* ]] || p1="#${p1}"
            [[ "${x12}" == \#* ]] || x12="#${x12}"
            [[ "${x13}" == \#* ]] || x13="#${x13}"
            [[ "${x14}" == \#* ]] || x14="#${x14}"
            [[ "${x16}" == \#* ]] || x16="#${x16}"
            [[ "${x19}" == \#* ]] || x19="#${x19}"
            [[ "${x23}" == \#* ]] || x23="#${x23}"
            [[ "${x24}" == \#* ]] || x24="#${x24}"
            [[ "${x28}" == \#* ]] || x28="#${x28}"
            [[ "${x29}" == \#* ]] || x29="#${x29}"

            cat >"${tmp_json}" <<EOF
{
  "preset": "end4-tonal-spot",
  "barBg": "${p1}",
  "mainBg": "${p1}",
  "surfaceBg": "${x12}",
  "layer2Bg": "${x13}",
  "mainFg": "${x19}",
  "subFg": "${x16}",
  "actBg": "${x28}",
  "glowColor": "${x28}",
  "glowSecondary": "${x29}",
  "accentSecondary": "${x23}",
  "onSecondaryContainer": "${x29}",
  "actFg": "${p1}",
  "hvrBg": "${x24}",
  "hvrFg": "${x19}",
  "borderColor": "${x14}",
  "barOpacity": 1.0,
  "pillOpacity": 1.0,
  "cornerRadius": 23,
  "wallBlurPath": "${blur_path}"
}
EOF
            mv -f "${tmp_json}" "${QS_CONFIG_DIR}/theme.json"
        )
        return 0
    fi

    if [[ ! -f "${QS_CONFIG_DIR}/theme.json" ]]; then
        cat >"${tmp_json}" <<EOF
{
  "preset": "end4-tonal-spot",
  "barBg": "#0f1c22",
  "mainBg": "#14252d",
  "surfaceBg": "#1c343f",
  "layer2Bg": "#274755",
  "mainFg": "#f4f9fc",
  "subFg": "#7e9aa6",
  "actBg": "#374c56",
  "glowColor": "#cbeaf5",
  "glowSecondary": "#94c5d6",
  "accentSecondary": "#2c434d",
  "onSecondaryContainer": "#a9c1ca",
  "actFg": "#f5f9fc",
  "hvrBg": "#415a66",
  "hvrFg": "#ffffff",
  "borderColor": "#b8dce8",
  "barOpacity": 1.0,
  "pillOpacity": 1.0,
  "cornerRadius": 23,
  "wallBlurPath": "${blur_path}"
}
EOF
        mv -f "${tmp_json}" "${QS_CONFIG_DIR}/theme.json"
    fi
}

ensure_config() {
    mkdir -p "${QS_CONFIG_DIR}"
    local src_dir=""
    if [[ -d "${QS_SHARE_DIR}" && -f "${QS_SHARE_DIR}/shell.qml" ]]; then
        src_dir="${QS_SHARE_DIR}"
    elif [[ -d "${REPO_QS_DIR}" && -f "${REPO_QS_DIR}/shell.qml" ]]; then
        src_dir="${REPO_QS_DIR}"
    fi

    if [[ -n "${src_dir}" ]]; then
        for qml_file in shell.qml Colors.qml RoundCorner.qml LisaGlassIcon.qml CircleUtilButton.qml ClippedProgressBar.qml; do
            if [[ -f "${src_dir}/${qml_file}" ]] && ! cmp -s "${src_dir}/${qml_file}" "${QS_CONFIG_DIR}/${qml_file}" 2>/dev/null; then
                cp -f "${src_dir}/${qml_file}" "${QS_CONFIG_DIR}/${qml_file}" 2>/dev/null || true
            fi
        done
        if [[ -f "${src_dir}/clock_widget.json" && ! -f "${QS_CONFIG_DIR}/clock_widget.json" ]]; then
            cp -f "${src_dir}/clock_widget.json" "${QS_CONFIG_DIR}/clock_widget.json" 2>/dev/null || true
        fi
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
    nohup "${qs_bin}" -p "${QS_CONFIG_DIR}" >>"${QS_LOG_FILE}" 2>&1 &
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
    if ! is_qs_running && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
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
    -w | --watch | --start | start)
        start_qs
        ;;
    -r | --reload | reload | restart)
        reload_qs
        ;;
    -u | --update | update)
        update_qs
        ;;
    -H | --hide | --toggle | hide | toggle)
        toggle_qs
        ;;
    -k | --kill | --stop | kill | stop)
        kill_qs
        ;;
    -h | --help | help)
        show_help
        ;;
    *)
        start_qs
        ;;
esac
