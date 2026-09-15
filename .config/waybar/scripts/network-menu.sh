#!/usr/bin/env bash
set -euo pipefail

colors=(-N'#122442' -n'#8aa2c9' -M'#2f66a8' -m'#ffffff' -S'#0a1628' -s'#dfe6f0')
font='JetBrainsMono Nerd Font Mono 12'

dev="$(nmcli -t -f TYPE,DEVICE device status | awk -F: '$1=="wifi"{print $2; exit}')"
if [ -z "$dev" ]; then
    notify-send -a waybar 'Wi-Fi' 'Interface Wi-Fi nao encontrada' 2>/dev/null || true
    exit 0
fi

if [ "${1:-}" = "disconnect" ]; then
    nmcli device disconnect "$dev" >/dev/null 2>&1 || true
    notify-send -a waybar 'Wi-Fi' "Desconectado de $dev" 2>/dev/null || true
    exit 0
fi

labels=(); names=()
while IFS=: read -r inuse ssid sec sig; do
    [ -n "$ssid" ] || continue
    names+=("$ssid")
    if [ "$inuse" = "*" ]; then
        labels+=("●  ${ssid}  ${sig}%  ${sec}")
    else
        labels+=("    ${ssid}  ${sig}%  ${sec}")
    fi
done < <(nmcli -t -f IN-USE,SSID,SECURITY,SIGNAL device wifi list ifname "$dev" --rescan yes 2>/dev/null)

if [ "${#names[@]}" -eq 0 ]; then
    notify-send -a waybar 'Wi-Fi' 'Nenhuma rede encontrada' 2>/dev/null || true
    exit 0
fi

sel="$(printf '%s\n' "${labels[@]}" | wmenu "$@" "${colors[@]}" -f "$font" -p 'Wi-Fi:' 2>/dev/null || true)"
[ -z "$sel" ] && exit 0

idx=-1
for i in "${!labels[@]}"; do
    [ "${labels[$i]}" = "$sel" ] && { idx=$i; break; }
done
[ "$idx" -lt 0 ] && exit 0

ssid="${names[$idx]}"
if nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
    notify-send -a waybar 'Wi-Fi' "Conectado a $ssid" 2>/dev/null || true
    exit 0
fi

pwd="$(printf ' ' | wmenu -P "${colors[@]}" -f "$font" -p "Senha de $ssid:" 2>/dev/null | tr -d '\n' || true)"
if [ -n "$pwd" ] && nmcli device wifi connect "$ssid" password "$pwd" >/dev/null 2>&1; then
    notify-send -a waybar 'Wi-Fi' "Conectado a $ssid" 2>/dev/null || true
else
    notify-send -a waybar 'Wi-Fi' "Falha ao conectar em $ssid" 2>/dev/null || true
fi