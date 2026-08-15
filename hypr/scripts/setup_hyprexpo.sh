#!/usr/bin/env bash
# Adds/enables/updates the hyprexpo plugin (SUPER+TAB workspace overview)
# once per Hyprland session. Two things this exists to survive:
#
# 1. exec-once fires early enough at boot that `hyprpm add`'s git clone can
#    race against the network actually being up yet and fail silently —
#    confirmed live: the plugin was never added at all on a fresh VM
#    despite this having run every session, and `hyprpm update` afterward
#    just reported "No repos to update" instead of any error. Waits for a
#    real connection first instead of hoping it's already there.
# 2. A Hyprland package update between sessions leaves the plugin built
#    against stale headers, which loads as "Failed to load plugins:
#    Outdated headers" and silently drops every hyprexpo config key *and*
#    the SUPER+TAB dispatcher along with it. `hyprpm update` before reload
#    rebuilds against whatever's actually running now; it's a fast no-op
#    when nothing changed, so running it every session costs nothing on
#    the common case.
#
# Logged rather than silent, since exec-once failures otherwise vanish —
# the config-parse errors they cause show up eventually, but by then
# there's no clue *why* the plugin isn't there.
set -uo pipefail

LOG="${XDG_CACHE_HOME:-$HOME/.cache}/hyprexpo-setup.log"
mkdir -p "$(dirname "$LOG")"

{
    echo "--- $(date -Is) ---"

    for _ in $(seq 1 20); do
        curl -fsS -m 2 https://github.com >/dev/null 2>&1 && break
        sleep 1
    done

    if ! hyprpm list 2>/dev/null | grep -q hyprexpo; then
        # Retired from the official hyprwm/hyprland-plugins repo — this is
        # the community fork that kept it going, same dispatcher name
        # (hyprexpo:expo) and config keys, just a different source repo.
        hyprpm add https://github.com/sandwichfarm/hyprexpo && hyprpm enable hyprexpo
    fi
    hyprpm update
    hyprpm reload -n
} >>"$LOG" 2>&1
