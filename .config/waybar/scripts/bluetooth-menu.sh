#!/usr/bin/env bash
set -euo pipefail

colors=(-N'#122442' -n'#8aa2c9' -M'#2f66a8' -m'#ffffff' -S'#0a1628' -s'#dfe6f0')
font='JetBrainsMono Nerd Font Mono 12'

if bluetoothctl show 2>/dev/null | grep -q 'Powered: no'; then
    bluetoothctl power on >/dev/null 2>&1 || true
fi

names=(); aliases=(); labels=()
while IFS= read -r line; do
    [ -n "$line" ] || continue
    mac="${line%% *}"
    alias="${line#* }"
    names+=("$mac")
    aliases+=("$alias")
    if bluetoothctl info "$mac" 2>/dev/null | grep -q 'Connected: yes'; then
        labels+=("●  ${alias}  [conectado]")
    else
        labels+=("    ${alias}")
    fi
done < <(bluetoothctl devices 2>/dev/null | cut -d' ' -f2-)

if [ "${#names[@]}" -eq 0 ]; then
    notify-send -a waybar 'Bluetooth' 'Nenhum dispositivo pareado' 2>/dev/null || true
    exit 0
fi

sel="$(printf '%s\n' "${labels[@]}" | wmenu "${colors[@]}" -f "$font" -p 'Bluetooth:' 2>/dev/null || true)"
[ -z "$sel" ] && exit 0

idx=-1
for i in "${!labels[@]}"; do
    [ "${labels[$i]}" = "$sel" ] && { idx=$i; break; }
done
[ "$idx" -lt 0 ] && exit 0

mac="${names[$idx]}"
alias="${aliases[$idx]}"

if bluetoothctl info "$mac" 2>/dev/null | grep -q 'Connected: yes'; then
    bluetoothctl disconnect "$mac" >/dev/null 2>&1 || true
    notify-send -a waybar 'Bluetooth' "Desconectado: $alias" 2>/dev/null || true
else
    if bluetoothctl connect "$mac" >/dev/null 2>&1; then
        notify-send -a waybar 'Bluetooth' "Conectado: $alias" 2>/dev/null || true
    else
        notify-send -a waybar 'Bluetooth' "Falha ao conectar: $alias" 2>/dev/null || true
    fi
fi
