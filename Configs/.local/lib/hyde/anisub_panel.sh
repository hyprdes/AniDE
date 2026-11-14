#!/usr/bin/env bash
# @name: anisub_panel
# @usage: hyde-shell anisub_panel [toggle|open|close]
# @cmd: Show or hide the AniSub panel that drops from the top bar (Win+Shift+M)
# Sends the request to the running Quickshell over IPC. It never opens rofi.
set -u

action="${1:-toggle}"
case "$action" in
    toggle | open | close) ;;
    -h | --help | help)
        grep -E '^# @(usage|cmd)' "$0" | sed 's/^# @/  /'
        exit 0
        ;;
    *)
        printf 'Usage: hyde-shell anisub_panel [toggle|open|close]\n' >&2
        exit 1
        ;;
esac

qs_bin="$(command -v qs 2>/dev/null || command -v quickshell 2>/dev/null)" || {
    printf 'Quickshell (qs) not found on PATH.\n' >&2
    exit 1
}
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
exec "$qs_bin" -p "$config_dir" ipc call anisub "$action"
