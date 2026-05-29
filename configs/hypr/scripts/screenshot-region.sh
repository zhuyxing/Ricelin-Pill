#!/usr/bin/env bash
# Quick: drag region with slurp -> copy to clipboard + save. No editor.
set -euo pipefail

region=$(slurp) || exit 0

file="$HOME/Pictures/Screenshots/shot-$(date +%Y%m%d-%H%M%S).png"
grim -g "$region" "$file"
wl-copy < "$file"
