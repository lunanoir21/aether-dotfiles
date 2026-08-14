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
# quickshell-git itself builds inside a memory-capped Docker container
# instead of directly on the host: its Qt6 compile is heavy enough to eat
# all available RAM+swap and lock up the whole desktop while it does, not
# just fail cleanly. Capped inside a container, a build that runs out of
# room just fails inside that container — the host, and whatever else is
# running on it (including Boxes/VMs), never even notices.
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
    git base-devel docker \
    hyprland hypridle xdg-desktop-portal-hyprland \
    kitty fish \
    cava playerctl wireplumber pipewire pipewire-pulse \
    wl-clipboard grim slurp jq brightnessctl \
    ttf-iosevka-nerd qt6-declarative qt6-svg qt6-imageformats \
    polkit-gnome

log "Starting the Docker daemon"
sudo systemctl enable --now docker.service

# ------------------------------------------------------------- AUR helper
# Nothing else in this script needs an AUR helper (quickshell-git builds in
# Docker below), but the user will want one eventually on a fresh Arch box,
# so bootstrap yay-bin now while it's cheap — it ships prebuilt, so this is
# a git clone and a package install, not a compile.
if ! command -v yay >/dev/null 2>&1 && ! command -v paru >/dev/null 2>&1; then
    log "No AUR helper found — installing yay-bin"
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi

# ------------------------------------------------------------------ quickshell
# Built inside Docker with a hard memory cap (--memory-swap equal to
# --memory means no swap headroom either, so a build that outgrows the
# cap gets OOM-killed *inside the container* right away instead of
# dragging the host into swap and taking the desktop down with it — which
# is exactly what happened building this directly on the host: even an
# 8G/16-core VM would lock up and crash GNOME Boxes along with everything
# else on the machine). Builds a real .pkg.tar.zst, then installs that on
# the host with pacman -U — the AUR helper above is never involved here.
build_quickshell_in_docker() {
    local mem_limit jobs out_dir script
    mem_limit="${DOCKER_BUILD_MEM:-6g}"
    jobs=$(( ${mem_limit%g} / 2 ))
    [[ "$jobs" -ge 1 ]] || jobs=1

    log "Building quickshell-git in a ${mem_limit}-capped Docker container (MAKEFLAGS=-j${jobs})"

    out_dir="$(mktemp -d)"
    script="$(mktemp)"
    cat > "$script" <<BUILD
#!/usr/bin/env bash
set -euo pipefail
pacman -Sy --noconfirm --needed git base-devel qt6-declarative qt6-svg qt6-imageformats cmake ninja pipewire jemalloc
sed -i -E 's/^MAKEFLAGS=.*/MAKEFLAGS="-j${jobs}"/' /etc/makepkg.conf
grep -q '^MAKEFLAGS=' /etc/makepkg.conf || echo 'MAKEFLAGS="-j${jobs}"' >> /etc/makepkg.conf
useradd -m builder
echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builder
su - builder -c '
    set -e
    git clone --depth 1 https://aur.archlinux.org/quickshell-git.git ~/pkg
    cd ~/pkg
    makepkg -s --noconfirm
    cp -- *.pkg.tar.* /out/
'
BUILD
    chmod +x "$script"

    # sudo rather than the docker group: group membership only takes effect
    # on a new login session, which a one-shot script never gets.
    sudo docker run --rm \
        --memory="$mem_limit" --memory-swap="$mem_limit" \
        -v "$out_dir:/out" \
        -v "$script:/build.sh:ro" \
        archlinux:base-devel \
        bash /build.sh
    rm -f "$script"

    [[ -n "$(ls -A "$out_dir" 2>/dev/null)" ]] || die "Docker build produced no package — check the container output above (DOCKER_BUILD_MEM=8g bash bootstrap.sh to raise the memory cap)."
    log "Installing the built quickshell-git package on the host"
    sudo pacman -U --noconfirm "$out_dir"/*.pkg.tar.*
    rm -rf "$out_dir"
}

if pacman -Qi quickshell-git >/dev/null 2>&1; then
    log "quickshell-git already installed — skipping the Docker build"
else
    build_quickshell_in_docker
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
