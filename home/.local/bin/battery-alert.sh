#!/usr/bin/env bash
# Avisa quando a bateria descarrega abaixo de 30/15/10% (uma vez por limiar).
# Reset das flags quando recarrega ou volta a carregar.
for bat in /sys/class/power_supply/BAT*; do
    [ -f "$bat/status" ] || continue
    status="$(cat "$bat/status" 2>/dev/null)"
    cap="$(cat "$bat/capacity" 2>/dev/null || echo 100)"

    if [ "$status" != "Discharging" ]; then
        rm -f /tmp/sway-battery-alert.*
        exit 0
    fi

    alerted=0
    for t in 30 15 10; do
        if [ "$cap" -le "$t" ]; then
            flag="/tmp/sway-battery-alert.$t"
            if [ ! -e "$flag" ]; then
                touch "$flag"
                notify-send -a waybar -u critical -t 0 \
                    "Bateria baixa" "Restam ~${cap}% — conecte o carregador" 2>/dev/null || true
            fi
            alerted=1
            break
        fi
    done
    [ "$alerted" -eq 0 ] && rm -f /tmp/sway-battery-alert.*
    exit 0
done