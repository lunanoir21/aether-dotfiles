#!/usr/bin/env bash
# One-liner installer for a fresh Arch Linux box:
#
#   curl -fsSL https://raw.githubusercontent.com/lunanoir21/aether-dotfiles/main/bootstrap.sh | bash
#
# Installs Hyprland and everything this rice needs, builds an AUR helper if
# there isn't one (Quickshell only ships as an AUR package), clones this repo,
# and runs install.sh to symlink the configs into place. Idempotent — safe to
# run again on a box that already has some of this.
#
# Before building anything from source, it also caps parallel build jobs by
# available RAM and adds a swapfile if there's none — quickshell-git's Qt6
# compile is heavy enough to OOM-kill on plenty of real machines otherwise,
# not just tight VMs.
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

# ------------------------------------------------------- build headroom
# quickshell-git compiles Qt6 with LTO, and its precompiled-header targets
# are heavy enough that the default -j$(nproc) OOM-kills cc1plus even on
# 8G boxes when a couple of PCH targets build in parallel — this isn't a
# rare misconfiguration, it's the default outcome on a lot of VMs. Two
# safety nets: cap parallel build jobs by available RAM so it doesn't get
# into that state, and make sure there's swap as a fallback in case it
# still runs tight (a lot of fresh installs/VMs simply have none).
ensure_build_swap() {
    local swap_kb mem_kb mem_gb
    swap_kb=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
    if [[ "$swap_kb" -gt 0 ]]; then
        log "Swap already active ($((swap_kb / 1024 / 1024))G) — leaving it alone"
        return
    fi
    mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    mem_gb=$((mem_kb / 1024 / 1024))
    if [[ "$mem_gb" -ge 16 ]]; then
        log "No swap, but ${mem_gb}G RAM is plenty for this build — skipping"
        return
    fi
    log "No swap and only ${mem_gb}G RAM — adding an 8G swapfile so the Qt6 build has somewhere to go instead of getting OOM-killed"
    sudo fallocate -l 8G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile >/dev/null
    sudo swapon /swapfile
    grep -q '^/swapfile ' /etc/fstab 2>/dev/null || echo '/swapfile none swap defaults 0 0' | sudo tee -a /etc/fstab >/dev/null
}

build_jobs() {
    local mem_gb jobs cores
    mem_gb=$(( $(awk '/MemTotal/ {print $2}' /proc/meminfo) / 1024 / 1024 ))
    cores="$(nproc)"
    # Roughly one job per 2G of RAM is what actually keeps quickshell's
    # Qt6 PCH compiles from OOMing in the first place — the swapfile above
    # is just the fallback if this estimate is still too optimistic.
    jobs=$(( mem_gb / 2 ))
    [[ "$jobs" -ge 1 ]] || jobs=1
    [[ "$jobs" -le "$cores" ]] || jobs="$cores"
    echo "$jobs"
}

ensure_build_swap
export MAKEFLAGS="-j$(build_jobs)"
log "Building with MAKEFLAGS=$MAKEFLAGS (capped by available RAM, not core count, to avoid OOM during Qt6 compilation)"

# ------------------------------------------------------------- AUR helper
# Quickshell has no official-repo package; everything downstream needs an
# AUR helper regardless, so this bootstraps yay-bin (prebuilt, so it doesn't
# also need to compile go from source) if one isn't already on the system.
if ! command -v yay >/dev/null 2>&1 && ! command -v paru >/dev/null 2>&1; then
    log "No AUR helper found — building yay-bin"
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi
AUR_HELPER="$(command -v yay || command -v paru)"

# ------------------------------------------------------------------ quickshell
log "Installing Quickshell (AUR)"
"$AUR_HELPER" -S --needed --noconfirm quickshell-git

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
