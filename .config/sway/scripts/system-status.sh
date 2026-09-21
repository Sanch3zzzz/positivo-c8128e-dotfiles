#!/usr/bin/env bash
# Painel de status do sistema (MOD + i).
# Abre num foot flutuante (app-id "status", centralizado): servicos do
# sway, unidades do usuario e saude do sistema. Fecha com qualquer tecla.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./status-lib.sh
source "$HERE/status-lib.sh"

c_ok=$'\033[1;32m'; c_bad=$'\033[1;31m'; c_neu=$'\033[2;37m'
c_hdr=$'\033[1;36m'; c_sec=$'\033[1;34m'; c_dim=$'\033[2;90m'
rst=$'\033[0m'

# Helpers de linha: 3 argumentos (%dot%, texto, valor-opcional-cinza).
ok()  { printf "   %s●%s %-28s%s%s\n"    "$c_ok" "$rst" "$1" "${2:-}" "$rst"; }
bad() { printf "   %s●%s %-28s %s%s%s\n" "$c_bad" "$rst" "$1" "$c_bad" "$2" "$rst"; }
neu() { printf "   %s●%s %-28s %s%s%s\n" "$c_neu" "$rst" "$1" "$c_dim" "$2" "$rst"; }
sec() { printf "\n %s%s%s\n" "$c_sec" "$*" "$rst"; }

check() { # <rotulo> <modo> <arg>  (vermelho [PARADO] quando falha)
    if svc "$2" "$3"; then ok "$1"; else bad "$1" "[PARADO]"; fi
}

printf "\n %sSTATUS DO SISTEMA  -  %s%s%s\n" "$c_hdr" "$c_dim" "$(date +'%a %d/%m/%Y %H:%M')" "$rst"

sec "Sessao sway"
check "Waybar"                 proc     waybar
check "Mako (notificacoes)"    proc     mako
check "Auto-trava (swayidle)"  proc     swayidle
check "Wallpaper (swaybg)"     proc     swaybg
check "Clipboard (cliphist)"   f        "wl-paste --watch cliphist"
check "Tela externa (daemon)"  f        "external-display.sh daemon"
if touch_ok; then ok "Gestos de toque"; else bad "Gestos de toque" "[PARADO]"; fi
if autorotate_ok; then ok "Rotacao (giroscopio)"; else neu "Rotacao (giroscopio)" "manual"; fi

sec "Unidades do usuario"
for t in dotfiles-backup battery-alert service-watchdog; do
    nxt=$(tnext "$t" 2>/dev/null || true)
    if svc usuario "$t.timer"; then
        ok "Timer ${t}" "  proxima: ${nxt:-?}"
    elif svc ligado "$t.timer"; then
        neu "Timer ${t}" "habilitado, inativo"
    else
        bad "Timer ${t}" "DESABILITADO"
    fi
done
check "ydotool.service"        usuario ydotool.service

sec "Sistema"
check "greetd"                 sys     greetd.service
check "systemd-oomd"           sys     systemd-oomd.service
check "Rede (NetworkManager)"  sys     NetworkManager.service
check "Bluetooth"              sys     bluetooth.service
if svc existe /dev/zram0; then ok "zram (swap em RAM)"; else neu "zram (swap em RAM)" "sem /dev/zram0"; fi

# Bateria
bp="$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo '?')"
bs="$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo '?')"
ok "Bateria" "  ${bp}% · ${bs}"

# Disco / (eMMC) e RAM
disk="$(df -h / 2>/dev/null | awk 'NR==2 {print $5" usado ("$2")"}')"
ram="$(free -h 2>/dev/null | awk 'NR==2 {print $3" de "$2}')"
ok "Disco /" "  ${disk:-?}"
ok "RAM" "  ${ram:-?}"

# Temperatura da CPU (evita acpitz/INT3400 que costumam dar 0; usa a
# primeira zona com leitura valida).
temp="?"
for z in /sys/class/thermal/thermal_zone*; do
    t="$(awk '{printf "%.0f", $1/1000}' "$z/temp" 2>/dev/null || true)"
    [ -n "$t" ] && [ "$t" -gt 0 ] 2>/dev/null && { temp="$t"; break; }
done
ok "Temperatura da CPU" "  ${temp} C"

printf "\n %s(qualquer tecla fecha  |  [PARADO] = veja logs e reinicie)%s\n" "$c_dim" "$rst"
read -rn1 -s || true
printf "\033[0m\n"