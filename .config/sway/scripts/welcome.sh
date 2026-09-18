#!/usr/bin/env bash
# Boas-vindas na primeira vez que o sway sobe (1x por usuario).
# Roda no start do sway (exec): se ja mostrou antes, sai sem fazer nada.
# Para rever depois:  welcome.sh --again
set -euo pipefail

MARKER="$HOME/.config/sway/.welcome-done"

case "${1:-}" in
    --again) rm -f "$MARKER" ;;
esac
[ -f "$MARKER" ] && exit 0

sleep 1  # deixa o mako (servidor de notificacao) subir primeiro

notify-send -t 20000 "Bem-vindo ao Positivo C8128E!" $'Dicas rapidas:\n\n\
  - MOD + Space  abre apps\n\
  - MOD + ?      ve essa ajuda na tela\n\
  - MOD + m      menu inicial (acoes do dia a dia)\n\
  - Toque a tela: tap = clique, segurar = clique direito, 2 dedos = workspace\n\n\
Guia completo em docs/06-troubleshooting.md (e docs/02, docs/03).' || true

mkdir -p "$(dirname "$MARKER")"
touch "$MARKER"