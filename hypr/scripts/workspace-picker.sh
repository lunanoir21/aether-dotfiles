#!/bin/bash

active=$(hyprctl activeworkspace -j | jq -r '.id')

items=""
for i in $(seq 1 10); do
    wins=$(hyprctl workspaces -j | jq -r ".[] | select(.id==$i) | .windows" 2>/dev/null)
    wins=${wins:-0}

    if [ "$wins" -gt 0 ]; then
        items+="$i   ·  $wins pencere\n"
    else
        items+="$i   —\n"
    fi
done

chosen=$(echo -e "$items" | rofi -dmenu \
    -theme ~/.config/rofi/workspace-grid.rasi \
    -no-custom \
    -selected-row $((active - 1)) \
    -p "")

ws=$(echo "$chosen" | awk '{print $1}')
[ -n "$ws" ] && hyprctl dispatch workspace "$ws"
