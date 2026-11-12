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
            p1="${dcol_pry1:-${wallbash_pry1:-#151217}}"
            x12="${dcol_1xa2:-${wallbash_1xa2:-#211c24}}"
            x13="${dcol_1xa3:-${wallbash_1xa3:-#2e2732}}"
            x14="${dcol_1xa4:-${wallbash_1xa4:-#49414e}}"
            x16="${dcol_1xa6:-${wallbash_1xa6:-#988d9e}}"
            x19="${dcol_1xa9:-${wallbash_1xa9:-#e9e0eb}}"
            x23="${dcol_2xa3:-${wallbash_2xa3:-#3b3242}}"
            x24="${dcol_2xa4:-${wallbash_2xa4:-#38303d}}"
            x28="${dcol_2xa8:-${wallbash_2xa8:-#dcbff2}}"
            x29="${dcol_2xa9:-${wallbash_2xa9:-#e8def8}}"

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
  "barOpacity": 0.85,
  "pillOpacity": 0.90,
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
  "barBg": "#151217",
  "mainBg": "#151217",
  "surfaceBg": "#211c24",
  "layer2Bg": "#2e2732",
  "mainFg": "#e9e0eb",
  "subFg": "#988d9e",
  "actBg": "#dcbff2",
  "glowColor": "#dcbff2",
  "glowSecondary": "#e8def8",
  "accentSecondary": "#3b3242",
  "onSecondaryContainer": "#e8def8",
  "actFg": "#24172e",
  "hvrBg": "#38303d",
  "hvrFg": "#f5eff7",
  "borderColor": "#49414e",
  "barOpacity": 0.85,
  "pillOpacity": 0.90,
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
        local force_sync=0
        if [[ -f "${QS_CONFIG_DIR}/shell.qml" ]] && grep -qE 'WlrLayershell\.namespace|parent\.parent\.winClass' "${QS_CONFIG_DIR}/shell.qml" 2>/dev/null; then
            force_sync=1
        fi
        if [[ -f "${QS_CONFIG_DIR}/Colors.qml" ]] && grep -qE 'Behavior on barBg|property color onErrorColor|property color onSecondaryContainer' "${QS_CONFIG_DIR}/Colors.qml" 2>/dev/null; then
            force_sync=1
        fi
        for qml_file in shell.qml Colors.qml RoundCorner.qml; do
            if [[ -f "${src_dir}/${qml_file}" ]]; then
                if [[ "${force_sync}" -eq 1 || ! -f "${QS_CONFIG_DIR}/${qml_file}" || "${src_dir}/${qml_file}" -nt "${QS_CONFIG_DIR}/${qml_file}" ]]; then
                    cp -f "${src_dir}/${qml_file}" "${QS_CONFIG_DIR}/${qml_file}" 2>/dev/null || true
                fi
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
