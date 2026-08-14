#!/bin/bash
WS=$1

CURSOR=$(hyprctl -j cursorpos)
CX=$(echo "$CURSOR" | jq -r '.x')
CY=$(echo "$CURSOR" | jq -r '.y')

ADDR=$(hyprctl -j clients | jq -r --argjson cx "$CX" --argjson cy "$CY" '
  .[] | select(
    .mapped == true and
    .at[0] <= $cx and (.at[0] + .size[0]) >= $cx and
    .at[1] <= $cy and (.at[1] + .size[1]) >= $cy
  ) | .address
' | head -1)

echo "CX=$CX CY=$CY ADDR=$ADDR"

if [ -n "$ADDR" ]; then
    hyprctl dispatch movetoworkspacesilent "$WS,address:$ADDR"
else
    echo "Pencere bulunamadı"
fi

hyprctl dispatch submap reset
