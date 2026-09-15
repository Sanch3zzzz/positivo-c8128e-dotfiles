#!/usr/bin/env bash
set -euo pipefail

colors=(-N'#122442' -n'#8aa2c9' -M'#2f66a8' -m'#ffffff' -S'#0a1628' -s'#dfe6f0')
font='JetBrainsMono Nerd Font Mono 12'

names=(); labels=()
while IFS=$'\t' read -r name desc; do
    names+=("$name")
    labels+=("$desc")
done < <(pactl list sinks | awk '
    /^Sink #/        { sink="" }
    /^[[:space:]]+Name:/ { name=$2 }
    /^[[:space:]]+Description:/ { sub(/^[[:space:]]*Description: /, ""); print name "\t" $0 }
')

[ "${#names[@]}" -eq 0 ] && exit 0

current="$(pactl get-default-sink 2>/dev/null || true)"
for i in "${!names[@]}"; do
    [ "${names[$i]}" = "$current" ] && labels[$i]="●  ${labels[$i]}"
done

sel="$(printf '%s\n' "${labels[@]}" | wmenu "${colors[@]}" -f "$font" -p 'Saida de audio:' 2>/dev/null || true)"
[ -z "$sel" ] && exit 0

idx=-1
for i in "${!labels[@]}"; do
    [ "${labels[$i]}" = "$sel" ] && { idx=$i; break; }
done
[ "$idx" -lt 0 ] && exit 0

name="${names[$idx]}"
pactl set-default-sink "$name"
while read -r sid; do
    pactl move-sink-input "$sid" "$name" 2>/dev/null || true
done < <(pactl list short sink-inputs | cut -f1)
notify-send -a waybar 'Audio' "Saida: ${labels[$idx]#●  }" 2>/dev/null || true