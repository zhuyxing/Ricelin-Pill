#!/usr/bin/env bash
# ShareX-style: drag region with slurp -> open satty editor (arrow tool) -> copy + save.
set -euo pipefail

region=$(slurp) || exit 0

grim -g "$region" -t ppm - | satty \
    --filename - \
    --initial-tool arrow \
    --copy-command wl-copy \
    --output-filename "$HOME/Pictures/Screenshots/satty-$(date +%Y%m%d-%H%M%S).png" \
    --early-exit
