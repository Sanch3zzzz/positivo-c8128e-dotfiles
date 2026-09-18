#!/usr/bin/env bash
# Menu de acoes do sistema (Ctrl+Alt+Delete): travar / suspender / reiniciar /
# desligar / sair. Acoes destrutivas pedem confirmacao via swaynag.
set -euo pipefail

colors=(-N'#122442' -n'#8aa2c9' -M'#2f66a8' -m'#ffffff' -S'#0a1628' -s'#dfe6f0')
font='JetBrainsMono Nerd Font Mono 12'

actions=(lock suspend reboot poweroff logout)
labels=('Travar' 'Suspender' 'Reiniciar' 'Desligar' 'Sair')

sel="$(printf '%s\n' "${labels[@]}" | wmenu "${colors[@]}" -f "$font" -p 'Acoes:' 2>/dev/null || true)"
[ -z "$sel" ] && exit 0

idx=-1
for i in "${!labels[@]}"; do
    [ "${labels[$i]}" = "$sel" ] && { idx=$i; break; }
done
[ "$idx" -lt 0 ] && exit 0

case "${actions[$idx]}" in
    lock)
        swaylock -f
        ;;
    suspend)
        swaylock -f &
        sleep 0.5
        systemctl suspend
        ;;
    reboot)
        swaynag -t warning -m "Reiniciar o sistema?" -B 'Sim' 'systemctl reboot' -B 'Cancelar' 'true'
        ;;
    poweroff)
        swaynag -t warning -m "Desligar o sistema?" -B 'Sim' 'systemctl poweroff' -B 'Cancelar' 'true'
        ;;
    logout)
        swaynag -t warning -m "Sair do sway?" -B 'Sim' 'swaymsg exit' -B 'Cancelar' 'true'
        ;;
esac