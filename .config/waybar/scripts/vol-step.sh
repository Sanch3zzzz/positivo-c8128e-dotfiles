#!/usr/bin/env bash
# Volume suave + leve: 1% por evento, travado em [0,150].
# flock = debounce: se o evento anterior ainda esta rodando, dropa este
# (touchpad manda rajadas; evita pipocar pactl/procs no Celeron).
exec 9>"/tmp/sway-vol.lock"
flock -n 9 || exit 0

step="${VOL_STEP:-1}"
case "${1:-up}" in
    up)   sig="+" ;;
    down) sig="-" ;;
    mute) pactl set-sink-mute @DEFAULT_SINK@ toggle; exit 0 ;;
    *)    exit 1 ;;
esac

pactl set-sink-volume @DEFAULT_SINK@ "${sig}${step}%"

v=$(pactl get-sink-volume @DEFAULT_SINK@)
v=${v#*Volume: }
v=${v%%%*}
v=${v##*/ }
[ -n "$v" ] || exit 0
[ "$v" -gt 150 ] && pactl set-sink-volume @DEFAULT_SINK@ 150%
[ "$v" -lt 0 ]   && pactl set-sink-volume @DEFAULT_SINK@ 0%
notify-send -t 800 -a waybar "Volume" "${v}%" 2>/dev/null || true