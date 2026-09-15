#!/usr/bin/env bash
set -euo pipefail

colors=(-N'#122442' -n'#8aa2c9' -M'#2f66a8' -m'#ffffff' -S'#0a1628' -s'#dfe6f0')
font='JetBrainsMono Nerd Font Mono 12'

GOV='/sys/devices/system/cpu/cpu0/cpufreq'
MAX_FREQ="$(cat "$GOV/cpuinfo_max_freq" 2>/dev/null || echo 2400000)"
BASE_FREQ="$(cat "$GOV/base_frequency" 2>/dev/null || echo $((MAX_FREQ / 2)))"

modes=(performance balanced power-saver)
names=('Performance' 'Balanceado' 'Economia')
icons=('\uf0e7' '\uf24e' '\uf186')

find_index() {
    local m="$1"
    for i in "${!modes[@]}"; do
        [ "${modes[$i]}" = "$m" ] && { echo "$i"; return; }
    done
    echo "1"
}

current_mode() {
    local gov maxf
    gov="$(cat "$GOV/scaling_governor" 2>/dev/null || echo powersave)"
    maxf="$(cat "$GOV/scaling_max_freq" 2>/dev/null || echo "$MAX_FREQ")"
    if [ "$gov" = performance ]; then
        echo performance
    elif [ "$maxf" -le "$BASE_FREQ" ]; then
        echo power-saver
    else
        echo balanced
    fi
}

apply_mode() {
    local mode="$1" gov maxf
    case "$mode" in
        performance) gov=performance; maxf="$MAX_FREQ" ;;
        balanced)    gov=powersave;    maxf="$MAX_FREQ" ;;
        power-saver) gov=powersave;    maxf="$BASE_FREQ" ;;
        *) return 1 ;;
    esac
    for p in /sys/devices/system/cpu/cpufreq/policy*; do
        [ -f "$p/scaling_governor" ] || continue
        echo "$gov" | sudo tee "$p/scaling_governor" >/dev/null 2>&1 || true
        echo "$maxf" | sudo tee "$p/scaling_max_freq" >/dev/null 2>&1 || true
    done
    return 0
}

refresh() { pkill -RTMIN+3 waybar 2>/dev/null || true; }

case "${1:-status}" in
    status)
        idx="$(find_index "$(current_mode)")"
        printf '%s\n%s\n' "${icons[$idx]}" "${names[$idx]}"
        ;;
    cycle)
        idx="$(find_index "$(current_mode)")"
        nxt="$(((idx + 1) % 3))"
        apply_mode "${modes[$nxt]}"
        notify-send -a waybar 'Energia' "Modo: ${names[$nxt]}" 2>/dev/null || true
        refresh
        ;;
    apply)
        apply_mode "${2:-balanced}"
        refresh
        ;;
    menu)
        cidx="$(find_index "$(current_mode)")"
        labels=(); idxs=()
        for i in 0 1 2; do
            idxs+=("$i")
            if [ "$i" = "$cidx" ]; then labels+=("●  ${names[$i]}"); else labels+=("    ${names[$i]}"); fi
        done
        sel="$(printf '%s\n' "${labels[@]}" | wmenu "${colors[@]}" -f "$font" -p 'Modo de energia:' 2>/dev/null || true)"
        [ -z "$sel" ] && exit 0
        for i in 0 1 2; do
            if [ "${labels[$i]}" = "$sel" ]; then
                apply_mode "${modes[$i]}"
                notify-send -a waybar 'Energia' "Modo: ${names[$i]}" 2>/dev/null || true
                refresh
                break
            fi
        done
        ;;
esac