#!/bin/bash

chosen=$(seq 1 10 | \
    xargs -I{} echo "→  workspace {}" | \
    rofi -dmenu \
    -theme ~/.config/rofi/workspace.rasi \
    -p "taşı")

ws=$(echo "$chosen" | grep -oP 'workspace \K\d+')
[ -n "$ws" ] && hyprctl dispatch movetoworkspace "$ws"
