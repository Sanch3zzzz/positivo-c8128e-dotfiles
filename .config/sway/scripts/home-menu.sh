#!/usr/bin/env bash
# Menu inicial (MOD + m): as acoes do dia a dia num lugar so.
# Estilo igual aos outros menus (power-actions, external-display).
set -euo pipefail

colors=(-N'#122442' -n'#8aa2c9' -M'#2f66a8' -m'#ffffff' -S'#0a1628' -s'#dfe6f0')
font='JetBrainsMono Nerd Font Mono 12'

labels=('Terminal'
        'Navegador (Floorp)'
        'Arquivos (Thunar)'
        'Print de tela'
        'Tela externa (HDMI)'
        'Sistema (energia)'
        'Rotacao automatica'
        'Teclado virtual'
        'Ajuda')
cmds=(foot
      floorp
      thunar
      "$HOME/.config/sway/scripts/screenshot-full.sh"
      "$HOME/.config/sway/scripts/external-display.sh"
      "$HOME/.config/sway/scripts/power-actions.sh"
      "$HOME/.config/sway/scripts/autorotate.sh"
      "$HOME/.config/sway/scripts/toggle-osk.sh"
      "foot --app-id=help $HOME/.config/sway/scripts/help-screen.sh")

sel="$(printf '%s\n' "${labels[@]}" | wmenu "${colors[@]}" -f "$font" -p 'Menu inicial:' 2>/dev/null || true)"
[ -z "$sel" ] && exit 0

idx=-1
for i in "${!labels[@]}"; do
    [ "${labels[$i]}" = "$sel" ] && { idx=$i; break; }
done
[ "$idx" -lt 0 ] && exit 0

cmd="${cmds[$idx]}"
# `exec` substitui o shell do script pela aplicacao (nao deixa processo orfao).
eval "exec $cmd"