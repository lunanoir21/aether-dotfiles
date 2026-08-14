#!/usr/bin/env bash

THUMB_DIR="$HOME/.cache/quickshell/wallpaper_picker/thumbs"
WALLPAPER_DIR="${1:-$HOME/.wallpaper-engine}"

if [ ! -d "$THUMB_DIR" ]; then
    echo "Thumb klasörü yok: $THUMB_DIR"
    exit 0
fi

deleted=0
kept=0

for thumb in "$THUMB_DIR"/*; do
    [ -f "$thumb" ] || continue
    filename=$(basename "$thumb")
    if [ ! -f "$WALLPAPER_DIR/$filename" ]; then
        rm "$thumb"
        echo "✗ Silindi: $filename"
        deleted=$((deleted + 1))
    else
        kept=$((kept + 1))
    fi
done

echo ""
echo "Silinen: $deleted | Kalan: $kept"
