#!/usr/bin/env bash
# Shift+wheel: instant, persistent cursor-zoom for readability (KDE Super+wheel equivalent).
# No animation/smoothing — each notch snaps straight to the new zoom level.
# Usage: zoom_wheel.sh in|out|reset

RATIO=1.2
MIN=1.0
MAX=6.0

STATE_DIR="/tmp/hypr-zoom"
mkdir -p "$STATE_DIR"
TARGET_FILE="$STATE_DIR/target"

direction="$1"
current=$(cat "$TARGET_FILE" 2>/dev/null || hyprctl getoption cursor:zoom_factor -j | jq -r '.float')

case "$direction" in
    in)
        new=$(awk -v c="$current" -v r="$RATIO" -v max="$MAX" 'BEGIN { v = c * r; if (v > max) v = max; printf "%.4f", v }')
        ;;
    out)
        new=$(awk -v c="$current" -v r="$RATIO" -v min="$MIN" 'BEGIN { v = c / r; if (v < min) v = min; printf "%.4f", v }')
        ;;
    reset)
        new="1.0000"
        ;;
esac

echo "$new" > "$TARGET_FILE"
hyprctl keyword cursor:zoom_factor "$new" >/dev/null
