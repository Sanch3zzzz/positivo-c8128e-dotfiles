#!/usr/bin/env python3
"""Barra visual de brilho/volume para Sway/Wayland (GtkLayerShell).

Overlay com slider que aparece ao clicar no icon no waybar.
Modos: brightness (default) ou volume.
Uso: control-bar.py [brightness|volume]
"""
import sys
import subprocess
import gi
gi.require_version('Gtk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
from gi.repository import Gtk, Gdk, Pango, GLib, GtkLayerShell

def rgba(hex_color):
    r = Gdk.RGBA()
    r.parse(hex_color)
    return r

BAR_W = 320
BAR_H = 36
MARGIN = 20
BG_COLOR = "#1a1a2ecc"
FG_COLOR = "#00d2ff"

class ControlBar(Gtk.Window):
    def __init__(self, mode="brightness"):
        super().__init__(Gtk.WindowType.TOPLEVEL)
        self.mode = mode
        self.timeout_id = None

        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(BAR_W, BAR_H)

        # Layer shell overlay
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.LEFT, False)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, False)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.BOTTOM, MARGIN)
        monitor = GtkLayerShell.get_monitor(self)
        if monitor:
            geom = monitor.get_geometry()
            self.move(geom.x + (geom.width - BAR_W) // 2, 0)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)
        GtkLayerShell.set_exclusive_zone(self, 0)

        # Container
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        box.set_valign(Gtk.Align.CENTER)
        box.set_margin_start(MARGIN)
        box.set_margin_end(MARGIN)
        box.set_margin_top(4)
        box.set_margin_bottom(4)

        # Label
        icon = "brightness" if mode == "brightness" else "audio-volume-high"
        label = Gtk.Label(label=f"{icon}  ")
        label.override_color(Gtk.StateFlags.NORMAL, rgba("#e0e0e0"))
        label.modify_font(Pango.FontDescription("Sans 11"))

        # Scale
        adj = Gtk.Adjustment(value=self.get_value(), lower=0, upper=100, step_increment=1)
        self.scale = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL, adjustment=adj)
        self.scale.set_size_request(BAR_W - 200, -1)
        self.scale.set_draw_value(False)
        self.scale.set_round_digits(0)
        self.scale.connect("value-changed", self.on_scale_changed)
        self.scale.override_color(Gtk.StateFlags.NORMAL, rgba(FG_COLOR))
        self.scale.override_color(Gtk.StateFlags.ACTIVE, rgba(FG_COLOR))
        self.scale.set_hexpand(True)

        # Value label
        self.val_label = Gtk.Label()
        self.val_label.override_color(Gtk.StateFlags.NORMAL, rgba("#e0e0e0"))
        self.val_label.modify_font(Pango.FontDescription("Sans 11"))
        self.update_val_label()

        box.pack_start(label, False, False, 0)
        box.pack_start(self.scale, True, True, 0)
        box.pack_end(self.val_label, False, False, 0)

        self.add(box)
        self.show_all()

        # Auto-hide on Escape
        self.connect("key-press-event", self.on_key_press)
        self.connect("destroy", lambda w: self.on_destroy())

        # Set style via CSS
        css = b"""
        window { background-color: #1a1a2e; border-radius: 8; }
        scale slider { background-color: #00d2ff; border-radius: 6; min-width: 12px; min-height: 12px; }
        scale fill { background-color: #00d2ff; border-radius: 6; }
        scale trough { background-color: #2a2a3e; border-radius: 6; border: none; }
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        self.present()
        self.grab_focus()

        # Auto-hide after 5s of inactivity
        self.reset_idle()

    def reset_idle(self):
        if self.timeout_id:
            GLib.source_remove(self.timeout_id)
        self.timeout_id = GLib.timeout_add_seconds(5, self.hide_and_quit)

    def update_val_label(self):
        v = self.get_value()
        self.val_label.set_text(f"{v:.0f}%")

    def on_scale_changed(self, scale):
        self.reset_idle()
        self.update_val_label()

    def on_key_press(self, widget, event):
        if event.keyval in (Gdk.KEY_Escape, Gdk.KEY.Return, Gdk.KEY.KP_Enter):
            self.hide_and_quit()
        elif event.keyval == Gdk.KEY.Left:
            a = self.scale.get_adjustment()
            a.set_value(max(0, a.get_value() - 5))
            self.reset_idle()
        elif event.keyval == Gdk.KEY.Right:
            a = self.scale.get_adjustment()
            a.set_value(min(100, a.get_value() + 5))
            self.reset_idle()

    def hide_and_quit(self):
        self.hide()
        GLib.idle_add(Gtk.main_quit)
        return False

    def on_destroy(self):
        if self.timeout_id:
            GLib.source_remove(self.timeout_id)

    def get_brightness(self):
        try:
            out = subprocess.check_output(["brightnessctl", "-m", "get"], timeout=2)
            parts = out.decode().strip().split(',')
            return float(parts[4]) if len(parts) >= 5 else 50.0
        except Exception:
            return 50.0

    def set_brightness(self, val):
        try:
            subprocess.run(["brightnessctl", "s", f"{int(val)}%"], timeout=3,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

    def get_volume(self):
        try:
            out = subprocess.check_output(["pactl", "get-sink-volume", "@DEFAULT_SINK@"], timeout=2)
            v = out.decode().strip()
            v = v.split("Volume: ")[1].split("%")[0].split("/")[0]
            return float(v)
        except Exception:
            return 50.0

    def set_volume(self, val):
        try:
            subprocess.run(["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{int(val)}%"],
                           timeout=3, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

    def get_value(self):
        if self.mode == "brightness":
            return self.get_brightness()
        return self.get_volume()

    def set_value(self, val):
        if self.mode == "brightness":
            self.set_brightness(val)
        else:
            self.set_volume(val)

def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "brightness"
    if mode not in ("brightness", "volume"):
        mode = "brightness"
    win = ControlBar(mode)
    Gtk.main()

if __name__ == "__main__":
    main()
