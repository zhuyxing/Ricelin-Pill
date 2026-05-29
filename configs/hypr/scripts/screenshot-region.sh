#!/usr/bin/env bash
# Interim quick shot: drag region (slurp, multi-monitor OK) -> copy + save.
# Replaced later by the custom Quickshell annotate tool.
set -euo pipefail

region=$(slurp) || exit 0

file="$HOME/Pictures/Screenshots/shot-$(date +%Y%m%d-%H%M%S).png"
grim -g "$region" "$file"
wl-copy < "$file"
