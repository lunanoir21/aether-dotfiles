#!/usr/bin/env bash
# One-liner installer for a fresh Arch Linux box:
#
#   curl -fsSL https://raw.githubusercontent.com/lunanoir21/aether-dotfiles/main/bootstrap.sh | bash
#
# Installs Hyprland and everything this rice needs, builds an AUR helper if
# there isn't one (for the user's own later use — nothing here strictly
# needs it), clones this repo, and runs install.sh to symlink the configs
# into place. Idempotent — safe to run again on a box that already has some
# of this.
#
# quickshell-git comes from Chaotic-AUR (a prebuilt-binary mirror of the
# AUR) instead of compiling it — its Qt6 build is heavy enough to eat all
# available RAM+swap and lock up the whole machine while it does, which is
# a much worse failure mode than "the install takes a few extra minutes."
# Falls back to building it locally via the AUR helper only if
# Chaotic-AUR is unreachable.
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
    git base-devel \
    hyprland hypridle xdg-desktop-portal-hyprland \
    kitty fish \
    cava playerctl wireplumber pipewire pipewire-pulse \
    wl-clipboard grim slurp jq brightnessctl \
    ttf-iosevka-nerd qt6-declarative qt6-svg qt6-imageformats \
    polkit-gnome

# ------------------------------------------------------------- AUR helper
# Nothing else in this script strictly needs an AUR helper (quickshell-git
# comes from Chaotic-AUR below, and only falls back to this if that's
# unreachable), but the user will want one eventually on a fresh Arch box,
# so bootstrap yay-bin now while it's cheap — it ships prebuilt, so this is
# a git clone and a package install, not a compile.
if ! command -v yay >/dev/null 2>&1 && ! command -v paru >/dev/null 2>&1; then
    log "No AUR helper found — installing yay-bin"
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi
AUR_HELPER="$(command -v yay || command -v paru || true)"

# ------------------------------------------------------------------ quickshell
# Chaotic-AUR mirrors popular AUR packages as prebuilt binaries, so this
# installs quickshell-git through pacman with no local compile at all —
# nothing to OOM-kill, nothing that can lock up the machine. Skipped
# entirely if it's already set up (from a previous run, or already present
# on the system for other reasons).
setup_chaotic_aur() {
    grep -q '^\[chaotic-aur\]' /etc/pacman.conf 2>/dev/null && return
    log "Adding the Chaotic-AUR repo (prebuilt binaries — quickshell-git needs no local compile this way)"
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -U --needed --noconfirm \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' | sudo tee -a /etc/pacman.conf >/dev/null
    sudo pacman -Sy
}

if pacman -Qi quickshell-git >/dev/null 2>&1; then
    log "quickshell-git already installed — skipping"
elif setup_chaotic_aur && sudo pacman -S --needed --noconfirm quickshell-git; then
    :
else
    [[ -n "$AUR_HELPER" ]] || die "Chaotic-AUR failed and no AUR helper is available to fall back to."
    log "Chaotic-AUR unavailable — falling back to building quickshell-git locally via $AUR_HELPER (this can be memory-heavy; see the project README if it stalls)"
    "$AUR_HELPER" -S --needed --noconfirm quickshell-git
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
