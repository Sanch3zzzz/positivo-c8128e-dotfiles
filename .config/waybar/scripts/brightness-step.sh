#!/usr/bin/env bash
# Brilho suave + leve: 5% por evento, com OSD via mako.
# flock = debounce: se o evento anterior ainda esta rodando, dropa este.
exec 9>"/tmp/sway-brightness.lock"
flock -n 9 || exit 0

step="${BRIGHTNESS_STEP:-5}"
case "${1:-up}" in
    up)   sudo -n brightnessctl s +${step}% >/dev/null 2>&1 || true ;;
    down) sudo -n brightnessctl s ${step}-% >/dev/null 2>&1 || true ;;
    *)    exit 1 ;;
esac

pct="$(brightnessctl -m get 2>/dev/null | cut -d',' -f5)"
makoctl dismiss -a 2>/dev/null || true
notify-send -t 800 -a waybar "Brilho" "${pct}" 2>/dev/null || true