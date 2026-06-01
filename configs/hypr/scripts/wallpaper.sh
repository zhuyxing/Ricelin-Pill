#!/usr/bin/env bash
# Wallpaper via awww (formerly swww) with a wave transition.
# Usage: wallpaper.sh init   -> autostart: restore the last wallpaper (random on first run); no-op on reload
#        wallpaper.sh         -> cycle to a new random wallpaper now (SUPER+B)
set -euo pipefail

WPDIR="$HOME/Ricelin/wallpapers"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/ricelin-wallpaper"

ensure_daemon() {
    awww query >/dev/null 2>&1 && return 0
    local attempt i
    for attempt in 1 2 3 4 5; do
        awww-daemon >/dev/null 2>&1 &
        for i in $(seq 1 15); do
            awww query >/dev/null 2>&1 && return 0
            sleep 0.2
        done
    done
    return 1
}

random_pic() {
    find "$WPDIR" -type f \( -iname '*.jpg' -o -iname '*.png' \) | shuf -n1
}

daemon_was_running=true
awww query >/dev/null 2>&1 || daemon_was_running=false
ensure_daemon || exit 0

if [ "${1:-}" = "init" ]; then
    # Config reload: daemon already up -> keep the current wallpaper.
    [ "$daemon_was_running" = true ] && exit 0
    # Fresh boot: restore the last-set wallpaper, fall back to random on first run.
    if [ -r "$STATE" ] && pic=$(cat "$STATE") && [ -f "$pic" ]; then
        :
    else
        pic=$(random_pic)
    fi
else
    pic=$(random_pic)
fi

[ -n "$pic" ] || exit 0

awww img "$pic" \
    --transition-type wave \
    --transition-angle 30 \
    --transition-wave "60,30" \
    --transition-fps 60 \
    --transition-step 90

mkdir -p "$(dirname "$STATE")"
printf '%s\n' "$pic" > "$STATE"

wallust run "$pic" >/dev/null 2>&1 || true
hyprctl reload >/dev/null 2>&1 || true
