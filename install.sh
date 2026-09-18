#!/usr/bin/env bash
# Instalador dos dotfiles do Positivo C8128E + Arch + Sway.
#
# Uso:
#   ./install.sh              # so configs do usuario (padrao, seguro)
#   ./install.sh --root       # tambem instala arquivos de sistema (usa sudo)
#
# Nunca apaga nada: tudo o que ja existir e salvo como <path>.bak.<timestamp>.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
STAMP="$(date +%Y%m%d_%H%M%S)"
WANT_ROOT=0
[ "${1:-}" = "--root" ] && WANT_ROOT=1

backup_copy() { # origem destino
    local src="$1" dst="$2"
    if [ -e "$dst" ] && ! diff -q "$src" "$dst" >/dev/null 2>&1; then
        mv "$dst" "${dst}.bak.${STAMP}"
        echo "  backup: ${dst}.bak.${STAMP}"
    fi
    install -Dm644 "$src" "$dst"
}

echo "== Configs do usuario =="
# sway
for f in config; do
    backup_copy "$HERE/.config/sway/$f" "$HOME/.config/sway/$f"
done
for f in "$HERE"/.config/sway/scripts/*; do
    b="$(basename "$f")"
    backup_copy "$f" "$HOME/.config/sway/scripts/$b"
    chmod +x "$HOME/.config/sway/scripts/$b"
done

# waybar
for f in config.jsonc style.css; do
    backup_copy "$HERE/.config/waybar/$f" "$HOME/.config/waybar/$f"
done
for f in "$HERE"/.config/waybar/scripts/*; do
    b="$(basename "$f")"
    backup_copy "$f" "$HOME/.config/waybar/scripts/$b"
    chmod +x "$HOME/.config/waybar/scripts/$b"
done

# MIME
backup_copy "$HERE/.config/mimeapps.list" "$HOME/.config/mimeapps.list"

# qt6ct (tema escuro p/ apps Qt/KDE)
backup_copy "$HERE/.config/qt6ct/qt6ct.conf" "$HOME/.config/qt6ct/qt6ct.conf"

# swaylock (tela travada) + swayidle (idle/trava/suspende)
backup_copy "$HERE/.config/swaylock/config" "$HOME/.config/swaylock/config"
backup_copy "$HERE/.config/swayidle/config" "$HOME/.config/swayidle/config"

# mako (notificacoes; OSD de volume/brilho e alerta de bateria usam ele)
backup_copy "$HERE/.config/mako/config" "$HOME/.config/mako/config"

# unidades de usuario (timer do alerta de bateria)
for f in "$HERE"/.config/systemd/user/*; do
    b="$(basename "$f")"
    backup_copy "$f" "$HOME/.config/systemd/user/$b"
done

# scripts do usuario
for f in "$HERE"/home/.local/bin/*; do
    b="$(basename "$f")"
    backup_copy "$f" "$HOME/.local/bin/$b"
    chmod +x "$HOME/.local/bin/$b"
done

echo "== Servicos do usuario =="
systemctl --user enable --now ydotool.service 2>/dev/null || true
systemctl --user enable --now battery-alert.timer 2>/dev/null || true

if [ "$WANT_ROOT" -eq 1 ]; then
    echo "== Arquivos de sistema (sudo) =="
    backup_copy "$HERE/root/usr/local/bin/start-sway" /usr/local/bin/start-sway
    chmod +x /usr/local/bin/start-sway
    backup_copy "$HERE/root/etc/greetd/config.toml" /etc/greetd/config.toml
    backup_copy "$HERE/root/etc/systemd/logind.conf.d/power-button.conf" \
        /etc/systemd/logind.conf.d/power-button.conf
    backup_copy "$HERE/root/etc/systemd/logind.conf.d/lid.conf" \
        /etc/systemd/logind.conf.d/lid.conf
    backup_copy "$HERE/root/etc/systemd/zram-generator.conf" \
        /etc/systemd/zram-generator.conf
    backup_copy "$HERE/root/etc/systemd/system/user.slice.d/oomd.conf" \
        /etc/systemd/system/user.slice.d/oomd.conf
    backup_copy "$HERE/root/etc/sudoers.d/10-celeron-nopasswd" \
        /etc/sudoers.d/10-celeron-nopasswd
    chmod 440 /etc/sudoers.d/10-celeron-nopasswd
    echo "  (sudoers NOPASSWD: confira com 'sudo visudo -c')"
    echo "  (zram/lid/oomd: rode 'sudo systemctl daemon-reload' apos instalar)"
else
    echo "== Arquivos de sistema: pulado (use ./install.sh --root) =="
fi

echo
echo "Concluido! Proximos passos:"
echo "  1. manter o usuario no grupo 'seat':  sudo usermod -aG seat \$USER"
echo "  2. logout/relogin (ou restart) para TERMINAL e o tema qt6ct valerem"
echo "  3. com o greetd ativo, reinicie: cai direto na tela de login (tuigreet)"
echo "  4. alternativa manual (TTY):  alias sway='exec newgrp seat -c /usr/bin/sway'"