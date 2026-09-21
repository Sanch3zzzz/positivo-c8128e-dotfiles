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

backup_copy() { # origem destino [sudo]
    local src="$1" dst="$2" su="${3:-}" pfx=()
    [ -n "$su" ] && pfx=(sudo)
    if [ -e "$dst" ] && ! "${pfx[@]}" diff -q "$src" "$dst" >/dev/null 2>&1; then
        "${pfx[@]}" mv "$dst" "${dst}.bak.${STAMP}"
        echo "  backup: ${dst}.bak.${STAMP}"
    fi
    "${pfx[@]}" install -Dm644 "$src" "$dst"
}

ESSENTIAL_BINS=(sway waybar foot wmenu mako grim slurp swaylock swaybg
                swayidle cliphist wl-copy brightnessctl playerctl ydotool
                notify-send pactl seatd python3)

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
    echo "$HOME/.config/foot/foot.ini"
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
    newest="$(find "${dst}"*.bak.* -type f 2>/dev/null | sort | tail -1 || true)"
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
    systemctl --user disable --now service-watchdog.timer 2>/dev/null || true
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

    if id -nG | grep -qw seat; then yes "grupo 'seat'"; else no "grupo 'seat' (sudo usermod -aG seat \$USER)"; fi
    if id -nG | grep -qw wheel; then yes "grupo 'wheel'"; else no "grupo 'wheel'"; fi

    if systemctl --user is-enabled battery-alert.timer >/dev/null 2>&1; then
        yes "timer alerta de bateria"
    else
        no "timer alerta de bateria (systemctl --user enable --now battery-alert.timer)"
    fi
    if systemctl --user is-enabled dotfiles-backup.timer >/dev/null 2>&1; then
        yes "timer backup de dotfiles"
    else
        no "timer backup de dotfiles (systemctl --user enable --now dotfiles-backup.timer)"
    fi
    if systemctl --user is-enabled service-watchdog.timer >/dev/null 2>&1; then
        yes "watchdog de servicos (10min)"
    else
        no "watchdog de servicos (systemctl --user enable --now service-watchdog.timer)"
    fi
    if systemctl --user is-enabled ydotool.service >/dev/null 2>&1; then
        yes "ydotool.service"
    else
        no "ydotool.service (systemctl --user enable --now ydotool.service)"
    fi

    if systemctl is-active greetd.service >/dev/null 2>&1; then
        yes "greetd ativo"
    else
        no "greetd ativo (systemctl enable --now greetd)"
    fi
    if systemctl is-active systemd-oomd.service >/dev/null 2>&1; then
        yes "systemd-oomd ativo"
    else
        no "systemd-oomd ativo (systemctl enable --now systemd-oomd)"
    fi

    if ls /dev/zram0 >/dev/null 2>&1; then yes "zram ativo"; else no "zram ativo (instale zram-generator e reinicie)"; fi
    if [ -f /etc/systemd/zram-generator.conf ]; then yes "zram-generator.conf"; else no "zram-generator.conf (./install.sh --root)"; fi

    if [ -d "$HOME/Images/Wallpapers" ]; then yes "pasta ~/Images/Wallpapers"; else no "pasta ~/Images/Wallpapers"; fi
    if [ -d "$HOME/Images/Prints" ]; then yes "pasta ~/Images/Prints"; else no "pasta ~/Images/Prints"; fi

    if python3 -c 'import json,re,sys; s=open(sys.argv[1]).read(); json.loads(re.sub(r"//.*","",s))' \
        "$HOME/.config/waybar/config.jsonc" >/dev/null 2>&1; then
        yes "JSON do waybar"
    else
        no "JSON do waybar invalido"
    fi

    if [ -f /etc/systemd/logind.conf.d/lid.conf ]; then
        yes "logind: tampa (lid)"
    else
        no "logind: tampa (lid.conf - ./install.sh --root)"
    fi
    if [ -f /etc/systemd/logind.conf.d/power-button.conf ]; then
        yes "logind: botao energia"
    else
        no "logind: botao energia (power-button.conf - ./install.sh --root)"
    fi

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
backup_copy "$HERE/.config/sway/config" "$HOME/.config/sway/config"
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

# foot (terminal)
backup_copy "$HERE/.config/foot/foot.ini" "$HOME/.config/foot/foot.ini"

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
if systemctl --user enable --now ydotool.service battery-alert.timer \
    dotfiles-backup.timer service-watchdog.timer 2>/dev/null; then
    echo "  OK: servicos e timers do usuario habilitados."
else
    echo "  AVISO: nao foi possivel ativar os servicos do usuario (systemctl --user falhou)."
    echo "  Causa comum: instalando de uma sessao sem user bus (SSH / TTY antes do login)."
    echo "  Rode de um terminal de sessao normal ou habilite o linger, entao reexecute:"
    echo "    loginctl enable-linger \$USER"
    echo "    systemctl --user enable --now ydotool.service battery-alert.timer \\"
    echo "        dotfiles-backup.timer service-watchdog.timer"
fi

if [ "$WANT_ROOT" -eq 1 ]; then
    echo "== Arquivos de sistema (sudo interno) =="
    backup_copy "$HERE/root/usr/local/bin/start-sway" /usr/local/bin/start-sway sudo
    sudo chmod +x /usr/local/bin/start-sway
    backup_copy "$HERE/root/etc/greetd/config.toml" /etc/greetd/config.toml sudo
    backup_copy "$HERE/root/etc/systemd/logind.conf.d/power-button.conf" \
        /etc/systemd/logind.conf.d/power-button.conf sudo
    backup_copy "$HERE/root/etc/systemd/logind.conf.d/lid.conf" \
        /etc/systemd/logind.conf.d/lid.conf sudo
    backup_copy "$HERE/root/etc/systemd/zram-generator.conf" \
        /etc/systemd/zram-generator.conf sudo
    backup_copy "$HERE/root/etc/systemd/system/user.slice.d/oomd.conf" \
        /etc/systemd/system/user.slice.d/oomd.conf sudo
    backup_copy "$HERE/root/etc/sudoers.d/10-celeron-nopasswd" \
        /etc/sudoers.d/10-celeron-nopasswd sudo
    sudo chmod 440 /etc/sudoers.d/10-celeron-nopasswd
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