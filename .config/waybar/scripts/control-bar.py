#!/usr/bin/env python3
"""Barra visual de brilho/volume para Sway/Wayland.

Overlay com slider que aparece ao clicar no icon no waybar.
Modos: brightness (default) ou volume.
Uso: control-bar.py [brightness|volume]
"""
import sys
import subprocess
import os
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib, Pango

BAR_W = 320
BAR_H = 40

def rgba(hex_color):
    r = Gdk.RGBA()
    r.parse(hex_color)
    return r

class ControlBar(Gtk.Window):
    def __init__(self, mode="brightness"):
        super().__init__(Gtk.WindowType.TOPLEVEL)
        self.mode = mode
        self.timeout_id = None

        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(BAR_W, BAR_H)
        self.set_title("control-bar.py")
        self.set_type_hint(Gdk.WindowTypeHint.UTILITY)

        # Position at bottom center
        screen = Gdk.Screen.get_default()
        if screen:
            geom = screen.get_monitor_geometry(0)
            self.move(geom.x + (geom.width - BAR_W) // 2, geom.y + geom.height - BAR_H - 40)

        # Container
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        box.set_valign(Gtk.Align.CENTER)
        box.set_margin_start(10)
        box.set_margin_end(10)
        box.set_margin_top(4)
        box.set_margin_bottom(4)

        # Label
        label = Gtk.Label()
        if mode == "brightness":
            label.set_text("Brilho  ")
            self.get_value = self.get_brightness
            self.set_value = self.set_brightness
        else:
            label.set_text("Volume  ")
            self.get_value = self.get_volume
            self.set_value = self.set_volume
        label.override_color(Gtk.StateFlags.NORMAL, rgba("#e0e0e0"))
        label.modify_font(Pango.FontDescription("Sans 11"))

        # Scale
        adj = Gtk.Adjustment(value=self.get_value(), lower=0, upper=100, step_increment=1)
        self.scale = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL, adjustment=adj)
        self.scale.set_size_request(BAR_W - 160, -1)
        self.scale.set_draw_value(False)
        self.scale.set_round_digits(0)
        self.scale.connect("value-changed", self.on_scale_changed)
        self.scale.override_color(Gtk.StateFlags.NORMAL, rgba("#00d2ff"))
        self.scale.override_color(Gtk.StateFlags.ACTIVE, rgba("#00d2ff"))
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

def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "brightness"
    if mode not in ("brightness", "volume"):
        mode = "brightness"
    win = ControlBar(mode)
    Gtk.main()

if __name__ == "__main__":
    main()
