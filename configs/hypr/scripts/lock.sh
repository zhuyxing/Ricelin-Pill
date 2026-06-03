#!/bin/sh
hyprctl monitors -j | jq -r '.[].name' | while read -r out; do
    [ -n "$out" ] && grim -o "$out" "/tmp/ricelin-lock-$out.png" 2>/dev/null
done
qs -c lock ipc call lock lock
