#!/usr/bin/env bash

# Tema artık her zaman sabit "smooth siyah" (bkz. matugen_cmd.sh) olduğu için
# bu script sadece temayı yeniden uygular. SUPER+SHIFT+G ile çalışır.

source "$(dirname "${BASH_SOURCE[0]}")/matugen_cmd.sh"
run_matugen
bash "$HOME/.config/hypr/scripts/quickshell/wallpaper/matugen_reload.sh"

notify-send "⚫ Siyah Tema" "Tema yeniden uygulandı" -t 2000
