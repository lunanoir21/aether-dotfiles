# CachyOS ships its own fish integration (prompt tweaks, its own fastfetch
# greeting) — guarded rather than a bare `source`, since this same file has
# to work unmodified on plain Arch too, where that path just doesn't exist.
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

alias ls lsd

fish_add_path $HOME/flutter/bin
fish_add_path $HOME/.local/bin
fish_add_path $HOME/.opencode/bin

# ------------------------------------------------------------------ greeting
# Renders "AETHER" with the exact 5×7 glyph bitmaps Dynamic Island's own
# pixel clock uses (see pixelfont.js) — the terminal banner and the desktop
# clock are, character for character, the same font. Skipped for anything
# that isn't a real interactive login shell, so it doesn't fire on every
# tmux/nvim-terminal split.
function fish_greeting
    test -n "$TMUX"; and return
    status is-interactive; or return

    set -l bold (set_color --bold f2f2f2)
    set -l muted (set_color 7d7d7d)
    set -l live (set_color 3aa863)
    set -l reset (set_color normal)

    set -l rows \
        "  ██████    ██████████  ██████████  ██      ██  ██████████  ████████    " \
        "██      ██  ██              ██      ██      ██  ██          ██      ██  " \
        "██      ██  ██              ██      ██      ██  ██          ██      ██  " \
        "██████████  ████████        ██      ██████████  ████████    ████████    " \
        "██      ██  ██              ██      ██      ██  ██          ██  ██      " \
        "██      ██  ██              ██      ██      ██  ██          ██    ██    " \
        "██      ██  ██████████      ██      ██      ██  ██████████  ██      ██  "

    echo
    for row in $rows
        echo "  $bold$row$reset"
    end
    echo
    echo "  $live●$reset $muted"(date "+%A, %d %B — %H:%M")"  ·  "(uname -sr)"$reset"
    echo
end

# Added by Antigravity CLI installer
set -gx PATH "$HOME/.local/bin" $PATH

# Qwen Code PATH block begin
set -gx PATH "$HOME/.local/bin" $PATH
# Qwen Code PATH block end
