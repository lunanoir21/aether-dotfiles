#!/usr/bin/env python3
# Same app discovery as ../applauncher/app_fetcher.py, plus a "wmclass" guess
# (StartupWMClass, falling back to the Exec basename) so the dock can match
# running windows (hyprctl clients -> class) back to a pinned launcher entry.
import os
import glob
import json

def fetch_apps():
    apps = {}
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
        if not os.path.exists(d):
            continue

        for f in glob.glob(os.path.join(d, '**/*.desktop'), recursive=True):
            try:
                with open(f, 'r', encoding='utf-8') as file:
                    app = {'name': '', 'exec': '', 'icon': '', 'wmclass': ''}
                    is_desktop = False
                    no_display = False

                    for line in file:
                        line = line.strip()
                        if line == '[Desktop Entry]':
                            is_desktop = True
                        elif line.startswith('['):
                            is_desktop = False

                        if is_desktop:
                            if line.startswith('Name=') and not app['name']:
                                app['name'] = line[5:]
                            elif line.startswith('Exec=') and not app['exec']:
                                app['exec'] = line[5:].split(' %')[0].split(' @@')[0]
                            elif line.startswith('Icon=') and not app['icon']:
                                app['icon'] = line[5:]
                            elif line.startswith('StartupWMClass=') and not app['wmclass']:
                                app['wmclass'] = line[len('StartupWMClass='):]
                            elif line.startswith('NoDisplay=true') or line.startswith('NoDisplay=1'):
                                no_display = True

                    if app['name'] and app['exec'] and not no_display:
                        if not app['wmclass']:
                            binpart = app['exec'].split(' ')[0].split('/')[-1]
                            app['wmclass'] = binpart.lower()
                        apps[app['name']] = app
            except Exception:
                pass

    res = list(apps.values())
    res.sort(key=lambda x: x['name'].lower())
    print(json.dumps(res))

if __name__ == "__main__":
    fetch_apps()
