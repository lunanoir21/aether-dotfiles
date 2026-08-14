source /usr/share/cachyos-fish-config/cachyos-config.fish

alias ls lsd

fish_add_path /home/lunanoir/flutter/bin

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end


# Added by Antigravity CLI installer
set -gx PATH "/home/lunanoir/.local/bin" $PATH

# opencode
fish_add_path /home/lunanoir/.opencode/bin

# Qwen Code PATH block begin
set -gx PATH '/home/lunanoir/.local/bin' $PATH
# Qwen Code PATH block end
