#!/usr/bin/env python3
import os
import glob
import json

def build_map():
    m = {}
    home = os.path.expanduser('~')
    dirs = [
        '/usr/share/applications',
        '/usr/local/share/applications',
        f'{home}/.local/share/applications',
        '/var/lib/flatpak/exports/share/applications',
        f'{home}/.local/share/flatpak/exports/share/applications',
        f'{home}/.nix-profile/share/applications',
        '/run/current-system/sw/share/applications'
    ]

    for d in dirs:
        if not os.path.isdir(d):
            continue
        for f in glob.glob(os.path.join(d, '**/*.desktop'), recursive=True):
            try:
                icon = ''
                execline = ''
                in_entry = False
                with open(f, 'r', encoding='utf-8', errors='ignore') as fh:
                    for line in fh:
                        line = line.strip()
                        if line == '[Desktop Entry]':
                            in_entry = True
                        elif line.startswith('['):
                            in_entry = False
                        if not in_entry:
                            continue
                        if line.startswith('Icon=') and not icon:
                            icon = line[5:]
                        elif line.startswith('Exec=') and not execline:
                            execline = line[5:].split(' %')[0].split(' @@')[0]
                if icon and execline:
                    bin_name = execline.split()[0].split('/')[-1]
                    key = bin_name.lower()
                    if key and key not in m:
                        m[key] = icon
            except Exception:
                pass

    # Second pass: validate against icon theme files directly. This is what
    # keeps random CLI tools/daemons (bash, Hyprland, quickshell, kernel
    # threads...) from being matched to an unrelated "unknown app" icon —
    # we only ever point at an icon name we've actually confirmed exists on
    # disk, either via a .desktop file above or a literal icon file here.
    icon_dirs = [
        '/usr/share/icons',
        '/usr/local/share/icons',
        f'{home}/.local/share/icons',
        f'{home}/.icons',
        '/usr/share/pixmaps'
    ]
    for d in icon_dirs:
        if not os.path.isdir(d):
            continue
        for f in glob.glob(os.path.join(d, '**', 'apps', '*'), recursive=True):
            stem = os.path.splitext(os.path.basename(f))[0]
            key = stem.lower()
            if key and key not in m:
                m[key] = stem
        for f in glob.glob(os.path.join(d, '*')):
            if os.path.isfile(f):
                stem = os.path.splitext(os.path.basename(f))[0]
                key = stem.lower()
                if key and key not in m:
                    m[key] = stem

    print(json.dumps(m))

if __name__ == "__main__":
    build_map()
