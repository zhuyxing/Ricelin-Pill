#!/bin/sh
mon=$(hyprctl activeworkspace -j | jq -r '.monitor')
qs -c launcher ipc call launcher toggle "$mon"
