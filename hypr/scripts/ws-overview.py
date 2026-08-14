#!/usr/bin/env python3
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib
import subprocess, json

def hypr(cmd):
    r = subprocess.run(['hyprctl'] + cmd.split() + ['-j'], capture_output=True, text=True)
    try: return json.loads(r.stdout)
    except: return {}

def switch(ws_id):
    subprocess.Popen(['hyprctl', 'dispatch', 'workspace', str(ws_id)])

CSS = b"""
window {
    background-color: rgba(0,0,0,0.92);
}
.ws-card {
    background-color: #0f0f0f;
    border-radius: 10px;
    border: 1px solid #1c1c1c;
    padding: 10px;
    min-width: 120px;
    min-height: 80px;
}
.ws-card:hover {
    background-color: #1a1a1a;
    border-color: #333333;
}
.ws-card.active {
    border-color: #444444;
    background-color: #141414;
}
.ws-num {
    color: #404040;
    font-family: 'JetBrains Mono';
    font-size: 11px;
}
.ws-num.active {
    color: #888888;
}
.ws-wins {
    color: #2a2a2a;
    font-family: 'JetBrains Mono';
    font-size: 10px;
    margin-top: 4px;
}
.ws-wins.has-wins {
    color: #555555;
}
.title-label {
    color: #2a2a2a;
    font-family: 'JetBrains Mono';
    font-size: 10px;
    letter-spacing: 4px;
}
"""

class Overview(Gtk.Window):
    def __init__(self):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.set_title("ws-overview")
        self.set_decorated(False)
        self.fullscreen()
        self.set_app_paintable(True)

        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(
            screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        self.connect("key-press-event", self.on_key)
        self.connect("button-press-event", self.on_bg_click)

        workspaces = {ws['id']: ws for ws in hypr('workspaces')}
        active_id = hypr('activeworkspace').get('id', 1)

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        outer.set_valign(Gtk.Align.CENTER)
        outer.set_halign(Gtk.Align.CENTER)

        title = Gtk.Label(label="WORKSPACES")
        title.get_style_context().add_class("title-label")
        outer.pack_start(title, False, False, 24)

        grid = Gtk.Grid()
        grid.set_column_spacing(10)
        grid.set_row_spacing(10)
        grid.set_halign(Gtk.Align.CENTER)

        for i in range(1, 11):
            col = (i - 1) % 5
            row = (i - 1) // 5
            ws = workspaces.get(i, {})
            wins = ws.get('windows', 0)
            is_active = (i == active_id)

            btn = Gtk.Button()
            btn.set_relief(Gtk.ReliefStyle.NONE)

            ctx = btn.get_style_context()
            ctx.add_class("ws-card")
            if is_active:
                ctx.add_class("active")

            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
            box.set_margin_top(6)
            box.set_margin_bottom(6)
            box.set_margin_start(8)
            box.set_margin_end(8)

            num = Gtk.Label(label=str(i))
            num.set_halign(Gtk.Align.START)
            num_ctx = num.get_style_context()
            num_ctx.add_class("ws-num")
            if is_active:
                num_ctx.add_class("active")

            win_label = Gtk.Label(label=f"{wins} pencere" if wins > 0 else "—")
            win_label.set_halign(Gtk.Align.START)
            win_ctx = win_label.get_style_context()
            win_ctx.add_class("ws-wins")
            if wins > 0:
                win_ctx.add_class("has-wins")

            box.pack_start(num, False, False, 0)
            box.pack_start(win_label, False, False, 0)
            btn.add(box)

            ws_id = i
            btn.connect("clicked", lambda b, wid=ws_id: self.go(wid))
            grid.attach(btn, col, row, 1, 1)

        outer.pack_start(grid, False, False, 0)
        self.add(outer)
        self.show_all()

    def go(self, ws_id):
        self.destroy()
        GLib.timeout_add(50, lambda: switch(ws_id))

    def on_key(self, w, e):
        if e.keyval in (Gdk.KEY_Escape, Gdk.KEY_super_L, Gdk.KEY_Super_L):
            self.destroy()

    def on_bg_click(self, w, e):
        pass

Overview()
Gtk.main()
