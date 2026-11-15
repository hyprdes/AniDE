#!/usr/bin/env bash
# @name: app_launcher
# @usage: hyde-shell app_launcher [toggle|open|close]
# @cmd: Show or hide the app launcher that rises out of the bottom frame edge (Win+A)
# Sends the request to the running Quickshell over IPC. If Quickshell does not
# answer (not running, or an older shell.qml without the launcher), toggle and
# open fall back to the Rofi application finder, so Win+A never does nothing.
set -u

action="${1:-toggle}"
case "$action" in
    toggle | open | close) ;;
    -h | --help | help)
        grep -E '^# @(usage|cmd)' "$0" | sed 's/^# @/  /'
        exit 0
        ;;
    *)
        printf 'Usage: hyde-shell app_launcher [toggle|open|close]\n' >&2
        exit 1
        ;;
esac

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
qs_bin="$(command -v qs 2>/dev/null || command -v quickshell 2>/dev/null)" || qs_bin=""

if [[ -n "$qs_bin" ]] && "$qs_bin" -p "$config_dir" ipc call launcher "$action" >/dev/null 2>&1; then
    exit 0
fi

# Nothing to close when Quickshell is not there
[[ "$action" == "close" ]] && exit 0
exec hyde-shell rofilaunch d
