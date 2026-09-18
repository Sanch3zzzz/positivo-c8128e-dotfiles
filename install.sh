#!/usr/bin/env bash
# Instalador dos dotfiles do Positivo C8128E + Arch + Sway.
#
# Uso:
#   ./install.sh                   # preflight + so configs do usuario (padrao, seguro)
#   ./install.sh --root            # tambem instala arquivos de sistema (usa sudo)
#   ./install.sh --check           # verifica a instalacao (nao muda nada)
#   ./install.sh --uninstall       # restaura o ultimo backup de cada config do usuario
#   ./install.sh --uninstall --root  # ... e os arquivos de sistema (usa sudo)
#
# Nunca apaga nada: tudo o que ja existir e salvo como <path>.bak.<timestamp>.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
STAMP="$(date +%Y%m%d_%H%M%S)"

WANT_ROOT=0
WANT_CHECK=0
WANT_UNINSTALL=0
for arg in "$@"; do
    case "$arg" in
        --root)      WANT_ROOT=1 ;;
        --check)     WANT_CHECK=1 ;;
        --uninstall) WANT_UNINSTALL=1 ;;
        *) echo "opcao desconhecida: $arg" >&2; exit 2 ;;
    esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

backup_copy() { # origem destino
    local src="$1" dst="$2"
    if [ -e "$dst" ] && ! diff -q "$src" "$dst" >/dev/null 2>&1; then
        mv "$dst" "${dst}.bak.${STAMP}"
        echo "  backup: ${dst}.bak.${STAMP}"
    fi
    install -Dm644 "$src" "$dst"
}

ESSENTIAL_BINS=(sway waybar foot wmenu mako grim slurp swaylock swaybg cliphist
                brightnessctl playerctl ydotool notify-send pactl seatd python3)

# imprime os pacotes faltantes; sai 0 se nao faltar nada.
missing_bins() {
    local m=() b
    for b in "${ESSENTIAL_BINS[@]}"; do
        command -v "$b" >/dev/null 2>&1 || m+=("$b")
    done
    python3 -c 'import evdev' >/dev/null 2>&1 || m+=("python-evdev")
    if [ "${#m[@]}" -eq 0 ]; then
        return 0
    fi
    printf '%s\n' "${m[@]}"
    return 1
}

do_preflight() {
    echo "== Preflight: dependencias =="
    local missing=() b
    mapfile -t missing < <(missing_bins || true)
    if [ "${#missing[@]}" -eq 0 ]; then
        echo "  OK: todas as dependencias presentes."
    else
        echo "  FALTAM (instale antes - veja docs/00-pacotes.md):"
        for b in "${missing[@]}"; do printf '    %s\n' "$b"; done
    fi
    echo
}

# ---------------------------------------------------------------------------
# Uninstall (restaura o ultimo .bak.*)
# ---------------------------------------------------------------------------

user_files() {
    echo "$HOME/.config/sway/config"
    local f b
    for f in "$HERE"/.config/sway/scripts/*; do echo "$HOME/.config/sway/scripts/$(basename "$f")"; done
    echo "$HOME/.config/waybar/config.jsonc"
    echo "$HOME/.config/waybar/style.css"
    for f in "$HERE"/.config/waybar/scripts/*; do echo "$HOME/.config/waybar/scripts/$(basename "$f")"; done
    echo "$HOME/.config/mimeapps.list"
    echo "$HOME/.config/qt6ct/qt6ct.conf"
    echo "$HOME/.config/swaylock/config"
    echo "$HOME/.config/swayidle/config"
    echo "$HOME/.config/mako/config"
    for f in "$HERE"/.config/systemd/user/*; do echo "$HOME/.config/systemd/user/$(basename "$f")"; done
    for f in "$HERE"/home/.local/bin/*; do echo "$HOME/.local/bin/$(basename "$f")"; done
}

root_files() {
    echo /usr/local/bin/start-sway
    echo /etc/greetd/config.toml
    echo /etc/systemd/logind.conf.d/power-button.conf
    echo /etc/systemd/logind.conf.d/lid.conf
    echo /etc/systemd/zram-generator.conf
    echo /etc/systemd/system/user.slice.d/oomd.conf
    echo /etc/sudoers.d/10-celeron-nopasswd
}

restore_file() { # destino [sudo]
    local dst="$1" su="${2:-}" newest="" cmd=()
    [ -n "$su" ] && cmd=(sudo)
    newest="$(ls -1d "${dst}".bak.* 2>/dev/null | sort | tail -1 || true)"
    if [ -z "$newest" ]; then
        if [ -e "$dst" ]; then
            "${cmd[@]}" rm -f "$dst"
            echo "  removido ($dst) - nao havia backup"
        else
            echo "  ausente ($dst)"
        fi
        return
    fi
    "${cmd[@]}" mv "$newest" "$dst"
    echo "  restaurado: $dst  <=  $newest"
}

do_uninstall() {
    echo "== Uninstall (restaura ultimo backup) =="
    echo "(configs do usuario)"
    local d
    while IFS= read -r d; do restore_file "$d"; done < <(user_files)
    systemctl --user disable --now battery-alert.timer 2>/dev/null || true
    systemctl --user disable --now dotfiles-backup.timer 2>/dev/null || true
    systemctl --user disable --now ydotool.service 2>/dev/null || true
    if [ "$WANT_ROOT" -eq 1 ]; then
        echo "(arquivos de sistema)"
        while IFS= read -r d; do restore_file "$d" sudo; done < <(root_files)
    fi
    echo "  (backups antigos restantes ficam como *.bak.*)"
}

# ---------------------------------------------------------------------------
# Check pos-instalacao
# ---------------------------------------------------------------------------

do_check() {
    echo "== Verificacao pos-instalacao =="
    local fail=0 ok=0 b
    yes() { ok=$((ok+1)); echo "  [ok] $*"; }
    no()  { fail=$((fail+1)); echo "  [FA] $*"; }

    local missing=()
    mapfile -t missing < <(missing_bins || true)
    if [ "${#missing[@]}" -eq 0 ]; then
        yes "dependencias"
    else
        for b in "${missing[@]}"; do no "pacote: $b"; done
    fi

    id -nG | grep -qw seat && yes "grupo 'seat'" || no "grupo 'seat' (sudo usermod -aG seat \$USER)"
    id -nG | grep -qw wheel && yes "grupo 'wheel'" || no "grupo 'wheel'"

    systemctl --user is-enabled battery-alert.timer >/dev/null 2>&1 \
        && yes "timer alerta de bateria" || no "timer alerta de bateria (systemctl --user enable --now battery-alert.timer)"
    systemctl --user is-enabled dotfiles-backup.timer >/dev/null 2>&1 \
        && yes "timer backup de dotfiles" || no "timer backup de dotfiles (systemctl --user enable --now dotfiles-backup.timer)"
    systemctl --user is-enabled ydotool.service >/dev/null 2>&1 \
        && yes "ydotool.service" || no "ydotool.service (systemctl --user enable --now ydotool.service)"

    systemctl is-active greetd.service >/dev/null 2>&1 \
        && yes "greetd ativo" || no "greetd ativo (systemctl enable --now greetd)"
    systemctl is-active systemd-oomd.service >/dev/null 2>&1 \
        && yes "systemd-oomd ativo" || no "systemd-oomd ativo (systemctl enable --now systemd-oomd)"

    ls /dev/zram0 >/dev/null 2>&1 && yes "zram ativo" || no "zram ativo (instale zram-generator e reinicie)"
    [ -f /etc/systemd/zram-generator.conf ] && yes "zram-generator.conf" || no "zram-generator.conf (./install.sh --root)"

    [ -d "$HOME/Images/Wallpapers" ] && yes "pasta ~/Images/Wallpapers" || no "pasta ~/Images/Wallpapers"
    [ -d "$HOME/Images/Prints" ] && yes "pasta ~/Images/Prints" || no "pasta ~/Images/Prints"

    if python3 -c 'import json,re,sys; s=open(sys.argv[1]).read(); json.loads(re.sub(r"//.*","",s))' \
        "$HOME/.config/waybar/config.jsonc" >/dev/null 2>&1; then
        yes "JSON do waybar"
    else
        no "JSON do waybar invalido"
    fi

    [ -f /etc/systemd/logind.conf.d/lid.conf ] && yes "logind: tampa (lid)" || no "logind: tampa (lid.conf - ./install.sh --root)"
    [ -f /etc/systemd/logind.conf.d/power-button.conf ] && yes "logind: botao energia" || no "logind: botao energia (power-button.conf - ./install.sh --root)"

    echo
    echo "  Resultado: $ok ok, $fail falha(s)."
    if [ "$fail" -eq 0 ]; then
        echo "  Tudo pronto!"
    else
        echo "  Corrija as linhas [FA] acima."
    fi
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

if [ "$WANT_UNINSTALL" -eq 1 ]; then
    do_uninstall
    exit 0
fi

if [ "$WANT_CHECK" -eq 1 ]; then
    do_check
    exit 0
fi

do_preflight
mkdir -p "$HOME/Images/Wallpapers" "$HOME/Images/Prints" "$HOME/Backup/dots"

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
systemctl --user enable --now dotfiles-backup.timer 2>/dev/null || true

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
echo "  5. conferir tudo:  ./install.sh --check"
echo "  6. wallpapers: coloque imagens em ~/Images/Wallpapers (sem imagem usa cor solida)"