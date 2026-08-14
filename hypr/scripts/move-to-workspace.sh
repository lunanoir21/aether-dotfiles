#!/bin/bash

chosen=$(seq 1 10 | rofi -dmenu -p "Pencereyi taşı →" -theme-str '
window { width: 300px; }
listview { lines: 10; }
')

[ -n "$chosen" ] && hyprctl dispatch movetoworkspace "$chosen"
