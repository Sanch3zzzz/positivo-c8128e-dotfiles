#!/usr/bin/env python3
# Tela de gerenciamento (MOD + Esc): energia, sessao e sistema num painel GTK.
# Roda como janela flutuante centralizada (regra [app_id="manager"] no sway).
# Fecha com Esc, com o X do canto ou depois de executar uma acao.
#
# Dependencias: gtk3 + python-gobject (ver docs/00-pacotes.md).
import getpass
import os
import socket
import subprocess
import sys
import time

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gdk, GLib, Gtk

# No Wayland/GTK3 o app_id e o "program name"; precisa ser "manager" para
# casar com o for_window do sway (~/.config/sway/config).
GLib.set_prgname("manager")
GLib.set_application_name("Gerenciamento")

HOME = os.path.expanduser("~")
SCRIPTS = os.path.join(HOME, ".config", "sway", "scripts")
POWER_MENU = os.path.join(HOME, ".config", "waybar", "scripts", "power-menu.sh")

DIAS = ("seg", "ter", "qua", "qui", "sex", "sáb", "dom")
MESES = ("jan", "fev", "mar", "abr", "mai", "jun",
         "jul", "ago", "set", "out", "nov", "dez")
BATTERY_STATUS = {
    "Charging": "carregando",
    "Discharging": "descarregando",
    "Full": "cheia",
    "Not charging": "na tomada",
    "Unknown": "",
}

# Mesmo tema Dark Azul Vibrante dos outros paineis (sway/waybar/mako).
CSS = """
* {
    font-family: "JetBrainsMono Nerd Font Mono", monospace;
    font-size: 12px;
}
window, .root {
    background-color: #0a1628;
}
.title {
    font-size: 22px;
    font-weight: bold;
    color: #ffffff;
}
.subtitle {
    font-size: 11px;
    color: #8aa2c9;
}
.clock {
    font-size: 22px;
    font-weight: bold;
    color: #00d4ff;
}
.date {
    font-size: 10px;
    color: #8aa2c9;
}
button.action {
    background-image: none;
    background-color: #122442;
    border: 1px solid #2f66a8;
    border-radius: 12px;
    padding: 8px 10px;
}
button.action:hover {
    background-color: #1c3055;
    border-color: #00d4ff;
}
button.action:active {
    background-color: #2f66a8;
}
.action-icon {
    font-size: 26px;
    color: #00d4ff;
}
.action-name {
    font-size: 12px;
    font-weight: bold;
    color: #dfe6f0;
}
button.action.danger {
    border-color: #7a2a33;
}
button.action.danger:hover {
    background-color: #2a1018;
    border-color: #ff5555;
}
button.action.danger .action-icon {
    color: #ff6b6b;
}
button.action.danger .action-name {
    color: #ffb3b3;
}
button.close {
    background-image: none;
    background-color: #122442;
    border: 1px solid #2f66a8;
    border-radius: 8px;
    color: #8aa2c9;
    font-size: 14px;
}
button.close:hover {
    background-color: #1c3055;
    border-color: #ff5555;
    color: #ffffff;
}
.hint {
    font-size: 10px;
    color: #8aa2c9;
}
dialog {
    background-color: #0a1628;
}
dialog label {
    color: #dfe6f0;
}
dialog button {
    background-image: none;
    background-color: #122442;
    border: 1px solid #2f66a8;
    border-radius: 8px;
    color: #dfe6f0;
    padding: 6px 14px;
}
dialog button:hover {
    background-color: #1c3055;
}
"""


def read(path, default=""):
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read().strip()
    except OSError:
        return default


def notify_error(message):
    try:
        subprocess.run(
            ["notify-send", "-a", "Gerenciamento", "Gerenciamento", message],
            check=False,
        )
    except OSError:
        pass


def run(cmd):
    try:
        subprocess.run(cmd, check=False)
    except OSError as exc:
        notify_error(f"Falha ao executar {cmd[0]}: {exc}")


def energy_mode():
    """Nome do modo de energia atual (Performance/Balanceado/Economia)."""
    try:
        out = subprocess.check_output(
            [POWER_MENU, "status"],
            text=True,
            timeout=3,
            stderr=subprocess.DEVNULL,
        )
    except (OSError, subprocess.SubprocessError):
        return "?"
    lines = [line.strip() for line in out.splitlines() if line.strip()]
    return lines[-1] if lines else "?"


class Manager:
    def __init__(self):
        self.pending = None
        self.energy_label = None

        self.win = Gtk.Window(title="Gerenciamento")
        self.win.set_wmclass("manager", "manager")
        self.win.set_default_size(720, 580)
        self.win.set_resizable(False)
        self.win.connect("destroy", self.on_destroy)
        self.win.connect("key-press-event", self.on_key)

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS.encode("utf-8"))
        Gtk.StyleContext.add_provider_for_screen(
            self.win.get_screen(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        root.set_border_width(18)
        root.get_style_context().add_class("root")
        self.win.add(root)

        root.pack_start(self.build_header(), False, False, 0)

        grid = Gtk.Grid()
        grid.set_row_spacing(12)
        grid.set_column_spacing(12)
        grid.set_column_homogeneous(True)
        grid.set_row_homogeneous(True)
        root.pack_start(grid, True, True, 0)

        entries = (
            ("\uf023", "Travar", "lock", False),
            ("\uf186", "Suspender", "suspend", False),
            ("\uf2f5", "Trocar conta", "switch", False),
            ("\uf0e7", "Modo de energia", "energy", False),
            ("\uf201", "Status do sistema", "status", False),
            ("\uf059", "Ajuda", "help", False),
            ("\uf021", "Reiniciar", "reboot", True),
            ("\uf011", "Desligar", "poweroff", True),
        )
        for i, (icon, text, action, danger) in enumerate(entries):
            btn, name = self.make_button(icon, text, danger)
            btn.connect("clicked", self.on_clicked, action)
            grid.attach(btn, i % 2, i // 2, 1, 1)
            if action == "energy":
                self.energy_label = name

        hint = Gtk.Label(label="Toque numa ação  ·  Esc fecha")
        hint.get_style_context().add_class("hint")
        root.pack_start(hint, False, False, 0)

        self.refresh_energy()
        self.win.show_all()

    def build_header(self):
        hdr = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)

        left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        title = Gtk.Label(label="Gerenciamento", xalign=0)
        title.get_style_context().add_class("title")
        self.subtitle = Gtk.Label(label="", xalign=0)
        self.subtitle.get_style_context().add_class("subtitle")
        left.pack_start(title, False, False, 0)
        left.pack_start(self.subtitle, False, False, 0)
        hdr.pack_start(left, True, True, 0)

        right = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        clock_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.clock = Gtk.Label(label="", xalign=1)
        self.clock.get_style_context().add_class("clock")
        self.day = Gtk.Label(label="", xalign=1)
        self.day.get_style_context().add_class("date")
        clock_box.pack_start(self.clock, False, False, 0)
        clock_box.pack_start(self.day, False, False, 0)
        right.pack_start(clock_box, False, False, 0)

        close = Gtk.Button(label="\uf00d")
        close.set_relief(Gtk.ReliefStyle.NONE)
        close.set_size_request(34, 34)
        close.set_tooltip_text("Fechar (Esc)")
        close.get_style_context().add_class("close")
        close.connect("clicked", lambda *_: Gtk.main_quit())
        right.pack_start(close, False, False, 0)
        hdr.pack_start(right, False, False, 0)

        self.update_header()
        GLib.timeout_add_seconds(20, self.update_header)
        return hdr

    def make_button(self, icon, text, danger):
        btn = Gtk.Button()
        btn.set_relief(Gtk.ReliefStyle.NONE)
        btn.set_size_request(-1, 88)
        ctx = btn.get_style_context()
        ctx.add_class("action")
        if danger:
            ctx.add_class("danger")

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        box.set_valign(Gtk.Align.CENTER)
        icon_label = Gtk.Label(label=icon)
        icon_label.get_style_context().add_class("action-icon")
        name_label = Gtk.Label(label=text)
        name_label.get_style_context().add_class("action-name")
        box.pack_start(icon_label, False, False, 0)
        box.pack_start(name_label, False, False, 0)
        btn.add(box)
        return btn, name_label

    def update_header(self):
        now = time.localtime()
        self.clock.set_text(time.strftime("%H:%M", now))
        self.day.set_text(
            f"{DIAS[now.tm_wday]}, {now.tm_mday:02d} {MESES[now.tm_mon - 1]}"
        )

        user = getpass.getuser()
        host = socket.gethostname()
        cap = read("/sys/class/power_supply/BAT0/capacity")
        status = read("/sys/class/power_supply/BAT0/status")
        parts = [f"{user}@{host}"]
        if cap:
            battery = f"bateria {cap}%"
            label = BATTERY_STATUS.get(status, status.lower())
            if label:
                battery += f" ({label})"
            parts.append(battery)
        self.subtitle.set_text("  ·  ".join(parts))
        return True

    def refresh_energy(self):
        if self.energy_label is not None:
            self.energy_label.set_text(f"Energia: {energy_mode()}")
        return False

    def confirm(self, action):
        if action == "reboot":
            title, yes = "Reiniciar o sistema?", "Reiniciar"
        else:
            title, yes = "Desligar o sistema?", "Desligar"

        dialog = Gtk.MessageDialog(
            transient_for=self.win,
            modal=True,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.NONE,
            text=title,
        )
        dialog.format_secondary_text("Salve seu trabalho antes de continuar.")
        dialog.add_button("Cancelar", Gtk.ResponseType.CANCEL)
        dialog.add_button(yes, Gtk.ResponseType.OK)
        dialog.set_default_response(Gtk.ResponseType.CANCEL)
        response = dialog.run()
        dialog.destroy()
        return response == Gtk.ResponseType.OK

    def on_clicked(self, _button, action):
        if action == "energy":
            run([POWER_MENU, "cycle"])
            GLib.timeout_add(150, self.refresh_energy)
            return

        if action in ("reboot", "poweroff") and not self.confirm(action):
            return

        if action in ("status", "help"):
            script = "system-status.sh" if action == "status" else "help-screen.sh"
            try:
                subprocess.Popen(
                    ["foot", f"--app-id={action}", os.path.join(SCRIPTS, script)]
                )
            except OSError as exc:
                notify_error(f"Falha ao abrir {script}: {exc}")
            Gtk.main_quit()
            return

        self.pending = action
        Gtk.main_quit()

    def on_key(self, _widget, event):
        if event.keyval == Gdk.KEY_Escape:
            Gtk.main_quit()
            return True
        return False

    def on_destroy(self, _widget):
        Gtk.main_quit()


def execute(action):
    if action == "lock":
        run(["swaylock", "-f"])
    elif action == "suspend":
        run(["swaylock", "-f"])
        time.sleep(0.6)
        run(["systemctl", "suspend"])
    elif action == "switch":
        # Com greetd/tuigreet, sair do sway volta para a tela de login,
        # onde da para escolher outro usuario.
        run(["swaymsg", "exit"])
    elif action == "reboot":
        run(["systemctl", "reboot"])
    elif action == "poweroff":
        run(["systemctl", "poweroff"])


def main():
    manager = Manager()
    Gtk.main()
    if manager.pending:
        execute(manager.pending)


if __name__ == "__main__":
    sys.exit(main())
