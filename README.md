# aether-dotfiles

My Hyprland desktop, being rebuilt from scratch — kitty for the terminal,
fish for the shell, and [Dynamic Island](hypr/scripts/quickshell/dynamic-island)
as the one Quickshell widget carried over from the previous setup. Every
other widget/panel is intentionally not here yet: it's being redesigned,
not migrated. Structured to mirror `~/.config` directly, so nothing here
needs translating to figure out where it actually lives.

SUPER+TAB opens an all-workspaces overview (the [hyprexpo](https://github.com/sandwichfarm/hyprexpo)
plugin — retired from the official hyprwm/hyprland-plugins repo, this is
the community fork that kept it going — bootstrapped automatically); bare
SUPER still opens/closes Dynamic Island.

## What's in it

```
aether-dotfiles/
├── hypr/
│   ├── hyprland.conf       Main compositor config — keybindings and the
│   │                        Turkish keyboard layout (kb_layout = tr) live here
│   ├── hypridle.conf       Idle/lock timers
│   ├── settings.json       Settings for the hypr-side tooling
│   ├── config/             autostart, env, keybindings, monitors, rules, variables
│   ├── templates/          Source templates the config/ files are generated from
│   ├── scripts/            Helper scripts (workspaces, screenshots, locking…) —
│   │                        matugen is gone from all of them; the wallpaper
│   │                        picker (init.sh) still sets the wallpaper itself,
│   │                        just without generating a colour scheme from it
│   └── scripts/quickshell/ Deliberately just the one thing:
│       └── dynamic-island/ A macOS-style Dynamic Island for Hyprland — its own
│                            project, own README, own git history. Included here
│                            as a submodule, not a copy. Every other widget
│                            (TopBar, Dock, Lock, battery, network, wallpaper…)
│                            was removed on purpose — they're being rebuilt,
│                            not brought along.
├── kitty/                  Terminal config — cursor trail, background blur,
│                            and a hand-picked greyscale palette that reuses
│                            Dynamic Island's status green/red/amber as the
│                            only saturated colour (no matugen)
└── fish/                   Shell config (not fish_variables — that's per-machine state,
                              regenerates itself, see .gitignore)
```

## Requirements

Hyprland itself, plus whatever each piece needs:

- **Quickshell** (`quickshell` / `qs`) — runs the Dynamic Island submodule.
  In Arch's own `extra` repo (`pacman -S quickshell`), no AUR needed.
- **cava**, **playerctl**, **wpctl** (PipeWire), **brightnessctl** — media/volume/
  brightness, used by Dynamic Island.
- **grim**, **slurp**, **wl-copy** (wl-clipboard) — screenshots and clipboard.
- **jq** — JSON plumbing.
- **kitty**, **fish** — the terminal and shell these configs are actually for.

Dynamic Island lists its own requirements separately — see
[`hypr/scripts/quickshell/dynamic-island/README.md`](hypr/scripts/quickshell/dynamic-island/README.md)
once the submodule is checked out.

## Install

### Fresh Arch Linux box (VM, new install, whatever)

One line, run as your normal user (not root):

```bash
curl -fsSL https://raw.githubusercontent.com/lunanoir21/aether-dotfiles/main/bootstrap.sh | bash
```

or with wget:

```bash
wget -qO- https://raw.githubusercontent.com/lunanoir21/aether-dotfiles/main/bootstrap.sh | bash
```

`bootstrap.sh` checks `/etc/os-release` and refuses to run on anything that
isn't Arch (or Arch-based) rather than half-installing and leaving a mess.
On Arch it installs Hyprland, Quickshell, and every other package this
rice needs via pacman (all from the official repos — no compiling), builds
`yay` from the AUR for later use, clones this repo to `~/aether-dotfiles`,
and runs `install.sh`. Safe to re-run — every step is `--needed`/idempotent.

If a bleeding-edge build is ever actually needed instead of the stable
`extra` package, that's a manual `yay -S quickshell-git` — its Qt6 compile
is heavy enough to lock up an 8G/16-core box outright when built
unattended, so not something this script does for you.

### Already have the packages, just want the configs

```bash
git clone --recurse-submodules https://github.com/lunanoir21/aether-dotfiles.git ~/aether-dotfiles
cd ~/aether-dotfiles
./install.sh
```

`install.sh` symlinks each tracked path into `~/.config` individually (not
whole directories), and backs up anything already there with a
`.bak-<timestamp>` suffix rather than overwriting it. Safe to re-run.

If you cloned without `--recurse-submodules`, or the `dynamic-island/`
folder is empty:

```bash
git submodule update --init --recursive
```

To pull in whatever's newest on the Dynamic Island side later:

```bash
git submodule update --remote hypr/scripts/quickshell/dynamic-island
```

## Why a submodule for Dynamic Island

It's developed and versioned on its own
([lunanoir21/quickshell-dynamic-island](https://github.com/lunanoir21/quickshell-dynamic-island)),
with its own commit history, issues and README. Copying its files in here
directly would mean every fix has to be applied twice and the two copies
drift apart the first time either one is forgotten. A submodule keeps one
source of truth and this repo just points at whichever commit of it is
currently in use.
