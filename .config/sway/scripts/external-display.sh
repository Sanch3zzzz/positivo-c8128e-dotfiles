#!/usr/bin/env bash
# Tela externa (HDMI/micro-HDMI) - Positivo C8128E + sway.
#
# Uso:
#   external-display.sh [menu]   # escolhe onde a externa fica (keybind MOD+p)
#   external-display.sh apply D  # aplica posicao: direita|esquerda|acima|abaixo|desconectar
#   external-display.sh daemon   # assiste hotplug: avisa e abre o menu (nunca mexe sozinho)
#
# Sem dependencia nova: swaymsg + wmenu + python3 (ja presentes no setup).
set -euo pipefail

INT="eDP-1"
LOG="/tmp/sway-external-display.log"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >>"$LOG"; }

find_sock() {
    local s
    for s in /run/user/*/sway-ipc.*.sock; do
        [[ -S "$s" ]] && { export SWAYSOCK="$s"; return 0; }
    done
    return 1
}
find_sock || true

# TSV nome largura altura ativo(0/1) - TODOS os outputs (ativos e desligados).
outputs_csv() {
    swaymsg -t get_outputs -r 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for o in d:
    m = o.get("current_mode") or o.get("rect") or {}
    print("%s\t%d\t%d\t%d" % (o["name"], m.get("width", 0), m.get("height", 0),
                              1 if o.get("active") else 0))
'
}

# Preenche EXT_NAMES/EXT_W/EXT_H/EXT_ACTIVE (externas) e INT_W/INT_H (interna).
read_outputs() {
    EXT_NAMES=()
    EXT_W=()
    EXT_H=()
    EXT_ACTIVE=()
    INT_W=0
    INT_H=0
    local n w2 h2 a
    while IFS=$'\t' read -r n w2 h2 a; do
        [ -n "$n" ] || continue
        if [ "$n" = "$INT" ]; then
            [ "$a" = "1" ] && { INT_W="$w2"; INT_H="$h2"; }
        else
            EXT_NAMES+=("$n")
            EXT_W+=("$w2")
            EXT_H+=("$h2")
            EXT_ACTIVE+=("$a")
        fi
    done < <(outputs_csv || true)
    if [ "${INT_W}" -lt 1 ]; then INT_W=1366; fi
    if [ "${INT_H}" -lt 1 ]; then INT_H=768; fi
}

notify() {
    notify-send -t 2500 "Tela externa" "$*" 2>/dev/null || true
}

apply_all() { # posicao ou "desconectar"
    local pos="$1" i name x y act=0
    read_outputs
    if [ "${#EXT_NAMES[@]}" -eq 0 ]; then
        notify "Nenhuma tela externa conectada."
        return 0
    fi
    if [ "$pos" = "desconectar" ]; then
        for i in "${!EXT_NAMES[@]}"; do
            [ "${EXT_ACTIVE[$i]}" = "1" ] || continue
            swaymsg output "${EXT_NAMES[$i]}" disable >/dev/null 2>&1 || true
            log "desconectada: ${EXT_NAMES[$i]}"
        done
        notify "Tela(s) externa(s) desconectada(s)."
        return 0
    fi

    for i in "${!EXT_NAMES[@]}"; do
        if [ "${EXT_ACTIVE[$i]}" != "1" ]; then
            swaymsg "output ${EXT_NAMES[$i]} enable" >/dev/null 2>&1 || true
        fi
    done
    sleep 0.3
    read_outputs
    for i in "${EXT_ACTIVE[@]}"; do [ "$i" = "1" ] && act=$((act+1)); done

    # Comando como UMA string: coord negativa (esquerda/acima) começando com
    # '-' vira opcao do swaymsg se passar como argumento separado.
    swaymsg "output $INT position 0 0" >/dev/null 2>&1 || true
    for i in "${!EXT_NAMES[@]}"; do
        name="${EXT_NAMES[$i]}"
        case "$pos" in
            direita)  x="${INT_W}";  y=0 ;;
            esquerda) x="-$((EXT_W[i]))"; y=0 ;;
            acima)    x=0; y="-$((EXT_H[i]))" ;;
            abaixo)   x=0; y="${INT_H}" ;;
            *)        x="${INT_W}"; y=0 ;;
        esac
        scale=1.00
        if   [ "${EXT_H[$i]}" -ge 2160 ]; then scale=1.50
        elif [ "${EXT_H[$i]}" -ge 1440 ]; then scale=1.25
        fi
        swaymsg "output $name position $x $y scale $scale" >/dev/null 2>&1 || true
        log "aplicado: $name ${x},${y} scale ${scale} (${pos})"
    done
    notify "Externa ${pos} (escala ${scale}; ${act} ativa(s))."
}

menu() {
    local sel pos
    read_outputs
    if [ "${#EXT_NAMES[@]}" -eq 0 ]; then
        notify "Nenhuma tela externa conectada."
        return 0
    fi
    sel="$(printf '%s\n' 'Direita' 'Esquerda' 'Acima' 'Abaixo' 'Desconectar' | wmenu \
        -N'#122442' -n'#8aa2c9' -M'#2f66a8' -m'#ffffff' -S'#0a1628' -s'#dfe6f0' \
        -f 'JetBrainsMono Nerd Font Mono 12' -p 'Tela externa:' 2>/dev/null || true)"
    [ -z "$sel" ] && return 0
    case "$sel" in
        Direita)     pos=direita ;;
        Esquerda)    pos=esquerda ;;
        Acima)       pos=acima ;;
        Abaixo)      pos=abaixo ;;
        Desconectar) pos=desconectar ;;
        *)           return 0 ;;
    esac
    apply_all "$pos"
}

on_bind() {
    read_outputs
    local i act=0
    for i in "${EXT_ACTIVE[@]}"; do [ "$i" = "1" ] && act=1; done
    [ "$act" = "1" ] || return 0
    log "hotplug: detectada(s) ${EXT_NAMES[*]}"
    notify "Detectada: ${EXT_NAMES[*]}"
    menu
}

on_unbind() {
    read_outputs
    local i act=0
    for i in "${EXT_ACTIVE[@]}"; do [ "$i" = "1" ] && act=1; done
    if [ "$act" = "0" ]; then
        log "externa(s) desconectada(s)"
        notify "Desconectada."
    fi
}

daemon() {
    log "daemon iniciado"
    read_outputs
    local i act=0
    for i in "${EXT_ACTIVE[@]}"; do [ "$i" = "1" ] && act=1; done
    if [ "$act" = "1" ]; then
        log "externa(s) presente(s) no start: ${EXT_NAMES[*]}"
        notify "Externa ativa: ${EXT_NAMES[*]} (MOD+p pra posicionar)"
    fi
    swaymsg -t subscribe -m '["output"]' 2>>"$LOG" | while IFS= read -r ev; do
        case "$ev" in
            *'"change":"bind"'*)   on_bind ;;
            *'"change":"unbind"'*) on_unbind ;;
        esac
    done
}

case "${1:-menu}" in
    menu)        menu ;;
    "" )         menu ;;
    apply)       apply_all "${2:-direita}" ;;
    daemon)      daemon ;;
    *) echo "uso: external-display.sh [menu|apply POS|daemon]" >&2; exit 2 ;;
esac