#!/usr/bin/env bash
# Brilho suave + leve: 5% por evento, com OSD via mako.
# flock = debounce: se o evento anterior ainda esta rodando, dropa este.
exec 9>"/tmp/sway-brightness.lock"
flock -n 9 || exit 0

step="${BRIGHTNESS_STEP:-5}"
case "${1:-up}" in
    up)   sig="+" ;;
    down) sig="-" ;;
    *)    exit 1 ;;
esac

brightnessctl set "${sig}${step}%" >/dev/null 2>&1 || true

pct="$(brightnessctl -m get 2>/dev/null | cut -d',' -f5)"
notify-send -t 800 -a waybar "Brilho" "${pct}" 2>/dev/null || true