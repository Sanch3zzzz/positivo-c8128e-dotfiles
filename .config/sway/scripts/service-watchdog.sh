#!/usr/bin/env bash
# Watchdog dos servicos criticos do sway (timer do usuario: 10 em 10 min).
# Avisa via mako quando algo cair e quando algum servico volta.
# Estado em /tmp/sway-service-watchdog.state (evita aviso repetido).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./status-lib.sh
source "$HERE/status-lib.sh"

STATE="/tmp/sway-service-watchdog.state"

# ROTULO|MODO|ARG — processos/unidades que NAO podem ficar fora do ar.
criticos=(
    "waybar|proc|waybar"
    "mako|proc|mako"
    "swayidle|proc|swayidle"
    "wallpaper|proc|swaybg"
    "clipboard|f|wl-paste --watch cliphist"
    "ydotool|usuario|ydotool.service"
    "tela externa|f|external-display.sh daemon"
    "gestos de toque|pid|/tmp/sway-touch-gestures.pid"
)

down=""
for c in "${criticos[@]}"; do
    IFS='|' read -r rotulo modo arg <<< "$c"
    case "$modo" in
        pid)
            if ! (svc pid "$arg" || svc f "touch-gestures.py"); then
                down="${down:+$down }$rotulo"
            fi
            ;;
        *)
            if ! svc "$modo" "$arg"; then
                down="${down:+$down }$rotulo"
            fi
            ;;
    esac
done

prev=""
[ -f "$STATE" ] && prev="$(cat "$STATE" 2>/dev/null || true)"

if [ -n "$down" ]; then
    if [ "$down" != "$prev" ]; then
        notify-send -t 10000 -u critical "Servicos parados" "Parados: $down" 2>/dev/null || :
    fi
elif [ -n "$prev" ]; then
    notify-send -t 6000 "Servicos restaurados" "Voltaram: $prev" 2>/dev/null || :
fi

printf '%s' "$down" > "$STATE"