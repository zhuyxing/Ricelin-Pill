#!/bin/sh
while :; do
    snapshot=$(cliphist list)
    [ -n "$snapshot" ] || exit 0

    idx=$(printf '%s\n' "$snapshot" | ~/.config/rofi/cliphist-rofi.sh | rofi -dmenu -no-custom -format i -kb-custom-1 "Control+x" -p "●" -theme ~/.config/rofi/clipboard.rasi)
    rc=$?
    [ -n "$idx" ] || exit 0

    line=$(printf '%s\n' "$snapshot" | sed -n "$((idx + 1))p")
    id=$(printf '%s' "$line" | cut -f1)
    case "$id" in
        ''|*[!0-9]*) exit 0 ;;
    esac

    if [ "$rc" -eq 10 ]; then
        printf '%s\n' "$line" | cliphist delete
        continue
    fi

    tmp=$(mktemp)
    printf '%s' "$id" | cliphist decode > "$tmp" 2>/dev/null
    [ -s "$tmp" ] && wl-copy < "$tmp"
    rm -f "$tmp"
    exit 0
done
