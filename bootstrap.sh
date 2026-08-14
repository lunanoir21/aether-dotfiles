#!/usr/bin/env bash
# One-liner installer for a fresh Arch Linux box:
#
#   curl -fsSL https://raw.githubusercontent.com/lunanoir21/aether-dotfiles/main/bootstrap.sh | bash
#
# Installs Hyprland, Quickshell, and everything else this rice needs, builds
# an AUR helper for later use (yay-bin — nothing here strictly needs it
# itself), clones this repo, and runs install.sh to symlink the configs
# into place. Idempotent — safe to run again on a box that already has some
# of this.
#
# Quickshell comes from Arch's own `extra` repo as a plain `pacman -S
# quickshell` — no AUR, no compiling. (The `-git` AUR package is a
# different, unattended-unfriendly story: its Qt6 build is heavy enough to
# have locked up an 8G/16-core box outright the one time this script tried
# building it automatically. If a bleeding-edge build is ever actually
# needed, that's a manual `yay -S quickshell-git`, not something this
# script does for you.)
set -euo pipefail

log() { printf '\n\033[1;32m==>\033[0m %s\n' "$1"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

# ---------------------------------------------------------------- OS check
# This script only knows how to drive pacman/AUR, so it has to refuse
# cleanly on anything else rather than half-run and leave a mess.
[[ -f /etc/os-release ]] || die "no /etc/os-release — can't identify the OS, this script only supports Arch Linux."
. /etc/os-release
case " ${ID} ${ID_LIKE:-} " in
    *" arch "*) ;;
    *) die "detected '${PRETTY_NAME:-$ID}', not Arch (or an Arch-based) distro — this script only supports Arch Linux." ;;
esac

# makepkg (needed to build the AUR helper) refuses to run as root, and for
# good reason — building packages as root is how you get a system-wide
# malicious PKGBUILD instead of a contained one.
[[ "$EUID" -ne 0 ]] || die "don't run this as root — it builds AUR packages, which makepkg refuses to do as root. Run it as your normal user; it'll ask for sudo when it actually needs it."

command -v sudo >/dev/null 2>&1 || die "sudo not found — install it first (as root: pacman -S sudo, then add your user to it)."

# ------------------------------------------------------------- pacman deps
log "Installing packages from the official repos"
sudo pacman -Syu --needed --noconfirm \
    git base-devel cmake \
    hyprland hypridle xdg-desktop-portal-hyprland quickshell \
    kitty fish \
    cava playerctl wireplumber pipewire pipewire-pulse \
    wl-clipboard grim slurp jq brightnessctl \
    ttf-iosevka-nerd qt6-declarative qt6-svg qt6-imageformats \
    polkit-gnome

# cmake above is for hyprpm, not quickshell — it needs it to build the
# hyprexpo plugin (SUPER+TAB workspace overview). That step itself isn't
# run here: hyprpm needs a live HYPRLAND_INSTANCE_SIGNATURE to detect the
# running Hyprland's version before it can add/build anything against it,
# which a box that's never started Hyprland yet doesn't have. See
# hyprland.conf's own exec-once in its AUTOSTART section instead — it adds
# and enables hyprexpo the first time a real session actually starts.

# ------------------------------------------------------------- AUR helper
# Nothing in this script needs an AUR helper itself (Quickshell comes from
# the official repos now), but the user will want one eventually on a
# fresh Arch box, so bootstrap yay-bin now while it's cheap: it ships
# prebuilt, so this is a git clone and a package install, not a compile.
if ! command -v yay >/dev/null 2>&1 && ! command -v paru >/dev/null 2>&1; then
    log "No AUR helper found — installing yay-bin"
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi

# ------------------------------------------------------------------- clone
DOTFILES_DIR="${AETHER_DOTFILES_DIR:-$HOME/aether-dotfiles}"
if [[ -d "$DOTFILES_DIR/.git" ]]; then
    log "aether-dotfiles already cloned at $DOTFILES_DIR — pulling latest"
    git -C "$DOTFILES_DIR" pull --recurse-submodules
else
    log "Cloning aether-dotfiles to $DOTFILES_DIR"
    git clone --recurse-submodules https://github.com/lunanoir21/aether-dotfiles.git "$DOTFILES_DIR"
fi

# ------------------------------------------------------------------- install
log "Symlinking configs into ~/.config"
"$DOTFILES_DIR/install.sh"

log "Done"
echo "Log out and pick Hyprland at your display manager, or start it from a"
echo "TTY with: Hyprland"
