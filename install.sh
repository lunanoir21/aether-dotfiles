#!/usr/bin/env bash
# Symlinks this repo's files into ~/.config, one path at a time — not whole
# directories wholesale, because ~/.config/hypr, kitty and fish all contain
# machine-local files this repo deliberately doesn't track (fish_variables,
# old .bak/.save files, alternate colour scheme drafts). A blanket directory
# symlink would either shadow those or force deleting them; per-path links
# leave everything this repo doesn't own untouched.
#
# Anything already at the destination gets moved aside with a timestamp
# suffix rather than overwritten, so a first run never loses real config.
#
# ONE EXCEPTION worth knowing before running this against a live setup:
# hypr/scripts IS linked as a whole directory (not per-file, there are too
# many). Its scripts/quickshell/ subfolder currently holds only
# dynamic-island/ — every other widget (TopBar, Dock, Lock, battery,
# network, wallpaper…) was deliberately removed here because they're being
# rebuilt from scratch, not migrated. Running this on a machine that still
# has the old widgets live will replace scripts/quickshell/ with this
# trimmed-down version and take those widgets down. Fine on a fresh
# install; not something to run yet on top of an existing working setup.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
STAMP="$(date +%Y%m%d-%H%M%S)"

# repo-relative path -> destination under $CONFIG_DIR
LINKS=(
    "hypr/hyprland.conf:hypr/hyprland.conf"
    "hypr/hypridle.conf:hypr/hypridle.conf"
    "hypr/settings.json:hypr/settings.json"
    "hypr/config:hypr/config"
    "hypr/templates:hypr/templates"
    "hypr/scripts:hypr/scripts"
    "kitty/kitty.conf:kitty/kitty.conf"
    "fish/config.fish:fish/config.fish"
)

if [[ -d "$REPO_DIR/hypr/shaders" ]]; then
    LINKS+=("hypr/shaders:hypr/shaders")
fi

link_one() {
    local src="$REPO_DIR/$1" dest="$CONFIG_DIR/$2"

    if [[ -L "$dest" ]]; then
        # Already a symlink — if it points here, nothing to do; if it points
        # somewhere else (an older checkout, say), replace it without a backup.
        if [[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
            echo "ok      $2 (already linked)"
            return
        fi
        rm "$dest"
    elif [[ -e "$dest" ]]; then
        mkdir -p "$(dirname "$dest")"
        mv "$dest" "$dest.bak-$STAMP"
        echo "backed up $2 -> $(basename "$dest").bak-$STAMP"
    fi

    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
    echo "linked  $2"
}

for pair in "${LINKS[@]}"; do
    link_one "${pair%%:*}" "${pair##*:}"
done

echo
echo "Done. Dynamic Island lives in hypr/scripts/quickshell/dynamic-island as a"
echo "git submodule — if it's empty, run:"
echo "  git submodule update --init --recursive"
echo
echo "Reload Hyprland (or just the affected pieces) for everything to take effect."
